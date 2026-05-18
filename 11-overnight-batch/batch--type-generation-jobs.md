# Overnight Batch: Type Generation Jobs

## What Type Generation Does

Generates TypeScript types from external sources so they stay in sync:
- Supabase schema → TypeScript interfaces
- OpenAPI spec → client types

Running type generation overnight catches schema drift before it becomes a runtime error.

## Supabase Type Generation

```bash
# Generate TypeScript types from Supabase schema
npx supabase gen types typescript \
  --project-id "$SUPABASE_PROJECT_ID" \
  > lib/database.types.ts
```

Or via Supabase CLI local dev:
```bash
supabase gen types typescript --local > lib/database.types.ts
```

## Batch Script: Keep Types in Sync

```typescript
// scripts/sync-types.ts
import { execFileSync } from 'child_process'
import fs from 'fs'

// Use execFileSync with array args to prevent shell injection
const projects = [
  {
    name: 'jrs-auto-repair',
    projectId: process.env.JRS_SUPABASE_PROJECT_ID!,
    outputPath: '/Users/drive/jrs-auto-repair/lib/database.types.ts',
  },
  {
    name: 'silver-creek-logistics',
    projectId: process.env.SCL_SUPABASE_PROJECT_ID!,
    outputPath: '/Users/drive/silver-creek-logistics/lib/database.types.ts',
  },
]

async function main() {
  for (const project of projects) {
    console.log(`Generating types for ${project.name}...`)
    
    try {
      // execFileSync with array args — no shell injection risk
      const output = execFileSync(
        'npx',
        ['supabase', 'gen', 'types', 'typescript', '--project-id', project.projectId],
        { encoding: 'utf-8' }
      )
      
      const content = `// Auto-generated on ${new Date().toISOString()}\n// Run scripts/sync-types.ts to regenerate\n\n${output}`
      fs.writeFileSync(project.outputPath, content)
      console.log(`  ✓ ${project.outputPath}`)
      
    } catch (error) {
      console.error(`  ✗ ${project.name} failed:`, error)
    }
    
    await new Promise(r => setTimeout(r, 1000))
  }
}

main()
```

## Using Generated Types

```typescript
// After running sync-types.ts:
import type { Database } from '@/lib/database.types'

// Typed Supabase client
const supabase = createClient<Database>(url, key)

// All queries are now typed:
const { data: invoices } = await supabase
  .from('invoices')
  .select('*')
// invoices is typed as Database['public']['Tables']['invoices']['Row'][] | null

// Useful type aliases in lib/types.ts:
type Invoice = Database['public']['Tables']['invoices']['Row']
type InsertInvoice = Database['public']['Tables']['invoices']['Insert']
type UpdateInvoice = Database['public']['Tables']['invoices']['Update']
```

## Detecting Schema Changes

After generation, check if types changed:
```bash
git diff lib/database.types.ts
# If changed: schema was updated, check for TypeScript errors
```

In CI:
```yaml
# .github/workflows/type-check.yml
- name: Generate Supabase types
  run: npx supabase gen types typescript --project-id ${{ secrets.SUPABASE_PROJECT_ID }} > /tmp/types.ts
  
- name: Check for type drift
  run: |
    diff lib/database.types.ts /tmp/types.ts && echo "Types in sync" || \
    (echo "ERROR: Types out of sync. Run sync-types.ts and commit." && exit 1)
```

## Manual Type Definitions (When Auto-Gen Isn't Available)

When working on features before the DB column exists, define types manually:
```typescript
// lib/types.ts
// TEMPORARY: remove when Supabase schema exists and sync-types generates this
export interface NotificationInsert {
  user_id: string
  type: string
  title: string
  body?: string
}
```

Remove once the column exists in Supabase and the generated types include it.

## Why Type Generation Matters

Without it:
- DB column `discount_amount` added but `Invoice` interface not updated
- `invoice.discount_amount` is `undefined` at runtime, TypeScript shows it as valid
- Bugs appear at runtime, not at compile time

With generated types from Supabase schema:
- Adding a column immediately shows up in TypeScript types
- Removing a column causes TypeScript errors at compile time for all usages
