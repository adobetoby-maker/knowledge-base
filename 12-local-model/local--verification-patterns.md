# Local Model Verification Patterns

## Why Verification Is Harder for Local Models

Cloud models can be asked "did your output work?" and they'll check. Local models running in batch mode need explicit verification steps built into the pipeline — they can't interactively verify their own output.

## Verification Step After Each Task

Every task in a batch manifest should have a `verifyCommand`:
```json
{
  "task": "add calculateDiscount function",
  "outputFile": "lib/invoices/calculate.ts",
  "verifyCommand": "npx tsc --noEmit && npx vitest run lib/invoices/calculate.test.ts",
  "expectedOutput": "all 4 tests pass"
}
```

The batch runner executes the verify command after each task. If it fails, the task is marked as failed.

## Verification Levels

```typescript
// Level 1: TypeScript compilation (always run)
const tsCheck = execFileSync('npx', ['tsc', '--noEmit'], { encoding: 'utf-8' })
// pass = no output; fail = error messages

// Level 2: Lint (run for style compliance)
const lintCheck = execFileSync('npx', ['eslint', '--max-warnings=0', outputFile], { encoding: 'utf-8' })

// Level 3: Tests (run if tests exist)
const testCheck = execFileSync('npx', ['vitest', 'run', testFile], { encoding: 'utf-8' })

// Level 4: Build (run before declaring complete)
const buildCheck = execFileSync('npm', ['run', 'build'], { encoding: 'utf-8' })
```

## File Content Verification

After generating a file, verify it matches expectations:
```typescript
function verifyFileContent(filePath: string, expectations: {
  mustContain: string[]
  mustNotContain: string[]
  minLength?: number
}): boolean {
  const content = fs.readFileSync(filePath, 'utf-8')
  
  for (const required of expectations.mustContain) {
    if (!content.includes(required)) {
      console.error(`Missing required content: "${required}"`)
      return false
    }
  }
  
  for (const forbidden of expectations.mustNotContain) {
    if (content.includes(forbidden)) {
      console.error(`Contains forbidden content: "${forbidden}"`)
      return false
    }
  }
  
  if (expectations.minLength && content.length < expectations.minLength) {
    console.error(`Content too short: ${content.length} < ${expectations.minLength}`)
    return false
  }
  
  return true
}

// Usage:
const ok = verifyFileContent('lib/invoices/calculate.ts', {
  mustContain: ['export function calculateDiscount', 'type Discount'],
  mustNotContain: ['TODO', 'FIXME', '// placeholder'],
  minLength: 200,
})
```

## Database State Verification

After a migration task, verify the schema:
```typescript
async function verifyTableColumn(
  supabase: SupabaseClient,
  tableName: string,
  columnName: string
): Promise<boolean> {
  const { data } = await supabase.rpc('verify_column_exists', {
    table_name: tableName,
    column_name: columnName,
  })
  return data === true
}

// SQL function in Supabase:
// CREATE FUNCTION verify_column_exists(table_name TEXT, column_name TEXT)
// RETURNS BOOLEAN AS $$
//   SELECT EXISTS (
//     SELECT FROM information_schema.columns
//     WHERE table_name = $1 AND column_name = $2
//   );
// $$ LANGUAGE sql;
```

## Output Comparison Verification

For content generation, compare generated output to expected patterns:
```typescript
function verifyArticleContent(body: string): string[] {
  const errors: string[] = []
  
  if (body.length < 500) errors.push('Article too short (< 500 chars)')
  if (body.length > 3000) errors.push('Article too long (> 3000 chars)')
  if (!body.includes('Twin Falls')) errors.push('Missing location mention')
  if (!body.includes('(208)')) errors.push('Missing phone number')
  if (body.includes('[object Object]')) errors.push('Template interpolation error')
  if ((body.match(/keyword/gi) ?? []).length > 10) errors.push('Possible keyword stuffing')
  
  return errors
}

const errors = verifyArticleContent(generatedBody)
if (errors.length > 0) {
  // Mark as needing human review, don't auto-publish
  progress.needsReview.push({ slug, errors })
}
```

## Retry Strategy After Verification Failure

```typescript
async function generateWithRetry<T>(
  fn: () => Promise<T>,
  verify: (result: T) => string[],
  maxAttempts = 3
): Promise<T | null> {
  for (let i = 0; i < maxAttempts; i++) {
    const result = await fn()
    const errors = verify(result)
    
    if (errors.length === 0) return result
    
    console.log(`Attempt ${i + 1} failed verification: ${errors.join(', ')}`)
    if (i < maxAttempts - 1) {
      await new Promise(r => setTimeout(r, 2000 * Math.pow(2, i)))  // exponential backoff
    }
  }
  
  return null  // all attempts failed
}
```

## Verification Report Format

At the end of a batch job, generate a verification report:
```json
{
  "runAt": "2026-05-18T06:00:00Z",
  "total": 50,
  "passed": 47,
  "failed": 2,
  "needsReview": 1,
  "failures": [
    { "task": "generate-article-brake-pads", "error": "Article too short (342 chars)" },
    { "task": "add-discount-function", "error": "TypeScript error: Expected ';' but found 'return'" }
  ],
  "needsReview": [
    { "task": "generate-article-oil-change", "warnings": ["Missing phone number"] }
  ]
}
```

This report is reviewed by a human before the batch output is committed.
