# Failure: Next.js Build Type Errors

**Symptom:** `npm run build` fails with TypeScript errors. `npx tsc --noEmit` shows errors. Build passes locally but fails in CI.

## Most Common Build-Time Type Errors

### 1. Async params in Next.js 15+
```
Error: Type '{ params: { slug: string } }' does not satisfy constraint...
```
Fix: `params` is now `Promise<{ slug: string }>` in App Router:
```typescript
// WRONG (Next.js 14 style)
export default function Page({ params }: { params: { slug: string } }) {
  const { slug } = params

// RIGHT (Next.js 15+)
export default async function Page({
  params
}: {
  params: Promise<{ slug: string }>
}) {
  const { slug } = await params
```

### 2. Missing return type on Server Actions
```
Error: Function lacks ending return statement and return type does not include 'undefined'
```
Fix: Add explicit return type or ensure all code paths return:
```typescript
'use server'
async function updateUser(data: FormData): Promise<{ success: boolean }> {
  // all paths must return this shape
  await db.update(...)
  return { success: true }
}
```

### 3. Supabase .single() — wrong error type
```
Error: Object is possibly 'null'
```
```typescript
// single() returns data: T | null — handle both
const { data, error } = await supabase.from('users').select('*').eq('id', id).single()
if (!data) return null  // handle null explicitly
```

### 4. Environment variable may be undefined
```
Error: Argument of type 'string | undefined' is not assignable to parameter of type 'string'
```
Fix: Assert or provide fallback:
```typescript
// Option 1: Non-null assertion (use when you know it's set)
const url = process.env.NEXT_PUBLIC_SUPABASE_URL!

// Option 2: Runtime check
const url = process.env.NEXT_PUBLIC_SUPABASE_URL
if (!url) throw new Error('Missing NEXT_PUBLIC_SUPABASE_URL')
```

### 5. Implicit any in catch blocks
```
Error: Object is of type 'unknown'. (TypeScript 4+)
```
```typescript
// WRONG
catch (e) {
  console.log(e.message)  // e is unknown

// RIGHT
catch (e) {
  const message = e instanceof Error ? e.message : String(e)
  console.log(message)
}
```

### 6. Missing keys in Record type
```
Error: Property 'new-tab' is missing in type
```
Common with the TabKey pattern in language-lens-elite. When you add a new TabKey value, you must also add it to `TAB_COMPONENTS`:
```typescript
// Both of these must be updated together:
type TabKey = '...' | 'new-tab'      // in app-state.tsx
TAB_COMPONENTS: Record<TabKey, ...>  // in tab-registry.ts
```

## Build Works Locally but Fails in CI

### Missing env vars in CI
Check: is the env var set in Vercel/GitHub Actions?
```bash
# Vercel
vercel env list

# Add if missing
vercel env add NEXT_PUBLIC_SUPABASE_URL
```

### Different Node versions
```json
// .nvmrc or package.json engines
{ "engines": { "node": ">=20.0.0" } }
```

### Dev dependency used in production code
If you import something only in devDependencies, it fails on production build.
Fix: move to `dependencies`.

## The Diagnostic Command
```bash
npx tsc --noEmit 2>&1 | head -50
# Shows first 50 lines of type errors — often enough to find the root cause
```
