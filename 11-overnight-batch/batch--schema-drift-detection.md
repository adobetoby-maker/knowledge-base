# Overnight Batch: Schema Drift Detection

## The Problem

Supabase database schema and TypeScript types can drift when:
- A column is added to the DB but `sync-types.ts` hasn't been run
- A column is renamed in the DB but code still uses the old name
- A new table is created but no TypeScript types exist for it
- A column's type changes (text → integer) but TypeScript still expects the old type

Schema drift causes runtime errors that TypeScript can't catch because the types don't match reality.

## Detection Script

```typescript
// scripts/detect-schema-drift.ts
import { createAdminClient } from '../lib/supabase/admin'
import { execFileSync } from 'child_process'
import fs from 'fs'

async function main() {
  const supabase = createAdminClient()
  
  // Step 1: Generate fresh types from current DB schema:
  console.log('Generating current types from Supabase...')
  const freshTypes = execFileSync(
    'npx',
    ['supabase', 'gen', 'types', 'typescript', '--project-id', process.env.SUPABASE_PROJECT_ID!],
    { encoding: 'utf-8' }
  )
  
  // Step 2: Compare to committed types:
  const committedTypes = fs.readFileSync('lib/database.types.ts', 'utf-8')
  
  // Remove timestamp comment that changes each generation:
  const normalize = (t: string) => t.replace(/\/\/ Auto-generated on .+\n/, '')
  
  if (normalize(freshTypes) === normalize(committedTypes)) {
    console.log('✓ Types are in sync with database schema')
    process.exit(0)
  }
  
  // Step 3: Identify what changed:
  fs.writeFileSync('/tmp/fresh-types.ts', freshTypes)
  
  try {
    const diff = execFileSync('diff', ['lib/database.types.ts', '/tmp/fresh-types.ts'], { encoding: 'utf-8' })
    console.log('Schema drift detected!')
    console.log(diff)
  } catch (diffOutput) {
    // diff exits with code 1 when files differ
    console.log('Schema drift detected. Differences:')
    console.log(diffOutput.stdout)
  }
  
  // Step 4: Check if TypeScript still compiles with fresh types:
  fs.writeFileSync('lib/database.types.ts', freshTypes)
  
  try {
    execFileSync('npx', ['tsc', '--noEmit'], { encoding: 'utf-8' })
    console.log('✓ TypeScript compiles with new schema — safe to update')
    // Restore original — this is detect-only, not auto-fix:
    fs.writeFileSync('lib/database.types.ts', committedTypes)
  } catch (tsError) {
    console.error('TypeScript errors with new schema:')
    console.error(tsError.stdout)
    // Restore original:
    fs.writeFileSync('lib/database.types.ts', committedTypes)
    console.error('SCHEMA DRIFT REQUIRES CODE CHANGES before types can be updated')
    process.exit(1)
  }
}

main()
```

## CI Integration

```yaml
# .github/workflows/schema-drift.yml
name: Schema Drift Check

on:
  schedule:
    - cron: '0 8 * * 1'   # Monday 8am — weekly check
  workflow_dispatch:

jobs:
  check-drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate types
        run: npx supabase gen types typescript --project-id ${{ secrets.SUPABASE_PROJECT_ID }} > /tmp/fresh-types.ts
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
      
      - name: Compare types
        run: diff lib/database.types.ts /tmp/fresh-types.ts || (echo "SCHEMA DRIFT DETECTED" && exit 1)
      
      - name: TypeScript check with fresh types
        if: failure()  # only if drift detected
        run: |
          cp /tmp/fresh-types.ts lib/database.types.ts
          npx tsc --noEmit
```

## What to Do When Drift Is Detected

1. **Types changed but code still compiles**: Run `scripts/sync-types.ts`, commit the updated `lib/database.types.ts`

2. **Types changed and code breaks**: Fix the code to use the new schema, then update types and commit together

3. **New table added but not in types**: Normal — run sync-types, add type aliases to `lib/types.ts`

4. **Column removed but code references it**: TypeScript will catch this after sync — fix all usages

## Migration Discipline

Always run schema drift detection BEFORE deploying. A deployment with drifted types will fail at runtime:

```bash
# Pre-deploy checklist:
npx supabase gen types typescript --project-id $ID > /tmp/check.ts
diff lib/database.types.ts /tmp/check.ts && echo "In sync" || echo "DRIFT DETECTED"
```

This takes 5 seconds and prevents production errors.
