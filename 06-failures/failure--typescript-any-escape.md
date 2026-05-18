# Failure: TypeScript `any` Escape Hatches

**Symptom:** Code compiles but throws runtime errors. TypeScript gave no warning because `any` was used. Or: a refactor broke something in production that tsc didn't catch.

## Why `any` Is Dangerous
`any` silences TypeScript's type checker entirely. It's not "unknown type" — it's "I promise this works, don't check." Every `any` is a future runtime bug waiting to happen.

```typescript
const data: any = await fetchUser()
console.log(data.naem)  // typo — tsc says nothing, breaks at runtime
```

## Fix Pattern — Type the Boundary, Not the Usage

### API Responses — Validate at Boundary
```typescript
import { z } from 'zod'

const UserSchema = z.object({
  id: z.string(),
  name: z.string(),
  email: z.string().email()
})
type User = z.infer<typeof UserSchema>

const raw = await fetch('/api/user').then(r => r.json())
const user = UserSchema.parse(raw)  // throws if shape is wrong
console.log(user.naem)  // TypeScript error ✓
```

### JSON.parse — Always Returns any
```typescript
// WRONG
const config = JSON.parse(fs.readFileSync('config.json', 'utf8'))
config.databse.url  // silently any

// RIGHT
const raw = JSON.parse(fs.readFileSync('config.json', 'utf8'))
const config = ConfigSchema.parse(raw)  // validated
```

### Replace any with unknown
`unknown` forces you to check the type before using it:
```typescript
// WRONG — silences all errors
function processData(data: any) {
  return data.value.toString()  // could blow up at runtime
}

// RIGHT — forces handling
function processData(data: unknown) {
  if (typeof data === 'object' && data !== null && 'value' in data) {
    return String((data as { value: unknown }).value)
  }
  throw new Error('Invalid data shape')
}
```

### Type Assertions — Use Sparingly
```typescript
// WRONG — lying to TypeScript
const user = response as User  // no validation, no guarantee

// RIGHT — validate then assert
const parsed = UserSchema.safeParse(response)
if (!parsed.success) throw new Error('Invalid user')
const user = parsed.data  // User type, actually validated
```

## Legitimate Uses of any
These are the only acceptable uses:
```typescript
// 1. Interop with untyped third-party library
const legacyLib = require('old-untyped-package') as any

// 2. eslint-disable-next-line @typescript-eslint/no-explicit-any
// Documented, temporary, with a TODO to fix

// 3. Prototype code you know you'll type later
```

## Enable Strict Mode
```json
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,          // enables all strict checks
    "noImplicitAny": true,   // error on implicit any
    "strictNullChecks": true // undefined/null must be handled
  }
}
```

## Detecting any in Codebase
```bash
# Find all explicit any usages
grep -rn ": any" src/ --include="*.ts" --include="*.tsx"
grep -rn "as any" src/ --include="*.ts" --include="*.tsx"
```
