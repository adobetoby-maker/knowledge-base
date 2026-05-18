# Agent Verification Patterns

## Why Agents Need to Verify Their Own Work

An agent that completes a task and reports "done" without verification is unreliable. The report reflects what the agent intended to do, not what actually happened.

Verification closes the gap between intent and execution.

## The Basic Verify Loop

After any significant action, verify it took effect:

```
1. Execute action
2. Read back the result
3. Compare to expected
4. If mismatch: retry or log failure
```

```typescript
// Example: verify a file was created correctly
async function createAndVerifyConfig(path: string, content: string) {
  // 1. Write
  await writeFile(path, content)
  
  // 2. Read back
  const written = await readFile(path, 'utf-8')
  
  // 3. Compare
  if (written !== content) {
    throw new Error(`File write failed: content mismatch at ${path}`)
  }
  
  // 4. Confirm
  console.log(`✓ ${path} created and verified`)
}
```

## Build Verification

After making code changes, run the build to verify no compile errors:

```typescript
// In agent orchestration code
import { execFile } from 'child_process'
import { promisify } from 'util'

const execFileAsync = promisify(execFile)

async function verifyBuild(projectPath: string): Promise<boolean> {
  try {
    await execFileAsync('npm', ['run', 'build'], { cwd: projectPath })
    return true
  } catch (error) {
    console.error('Build failed:', (error as Error).message)
    return false
  }
}
```

## Type Check Verification

TypeScript errors are caught before build:

```bash
# Fast type check without building
npx tsc --noEmit

# Only check changed files (faster in large projects)
npx tsc --noEmit --incremental
```

An agent that writes TypeScript should run `tsc --noEmit` before reporting the task done.

## Test Verification

After implementing a feature, verify existing tests still pass:

```bash
# jrs-auto-repair — run all tests
npm run test

# Run only tests related to what changed
npx vitest run lib/invoices/
```

An agent fixing a bug should: fix → run the specific test that was failing → run all tests to check for regressions.

## Database Verification

After applying a migration, verify the schema change:

```typescript
// Via Supabase MCP
mcp__plugin_supabase_supabase__execute_sql({
  project_id: projectId,
  query: `
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_name = 'invoices'
    ORDER BY ordinal_position
  `,
})
// Check that expected columns exist
```

## Deployment Verification

After deploying to Vercel:

```typescript
// Wait for deployment to complete
const deployment = await vercel.deployments.get(deploymentId)
// Poll until status is 'READY' or 'ERROR'

// Then verify the site is up
const response = await fetch('https://jrsautorepair.worker-bee.app')
if (!response.ok) {
  await logNeedsHuman(`Deployment verification failed: HTTP ${response.status}`)
}
```

Using Vercel MCP: `mcp__claude_ai_Vercel__get_deployment` to check status.

## Content Verification

After generating and inserting content, verify it appears correctly:

```typescript
// After inserting article into lib/articles.ts, verify it compiles
async function verifyArticle(slug: string) {
  // Check the article can be found
  const articles = await import('@/lib/articles')
  const article = articles.articles.find(a => a.slug === slug)
  if (!article) throw new Error(`Article ${slug} not found after insertion`)
  
  // Check required fields
  if (!article.title || !article.excerpt || !article.body) {
    throw new Error(`Article ${slug} has missing required fields`)
  }
}
```

## Regression Verification

After any change, check that adjacent functionality still works:

- Changed auth middleware → verify both admin and portal routes still authenticate
- Changed Supabase client → verify both browser and server usage
- Changed a shared utility → run all tests that use it

```bash
# Grep for all usages of a changed function
grep -r "formatCurrency" --include="*.ts" --include="*.tsx"
# Then verify each usage is unaffected
```

## The Verification Report

Include verification results in the completion report:

```markdown
## Task Complete: Add PDF Download

### Verification Steps Passed
- [x] TypeScript: `tsc --noEmit` — 0 errors
- [x] Build: `npm run build` — succeeded
- [x] Manual test: PDF downloads on Chrome desktop
- [x] HTTP test: GET /api/invoices/123/pdf returns 200 with Content-Type: application/pdf
- [x] Auth test: GET /api/invoices/999/pdf (different user) returns 403

### Known Limitations
- Not tested on Safari iOS (requires device testing)
```
