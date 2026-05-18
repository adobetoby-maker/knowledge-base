# Failure: TypeScript Generics and Type Errors

## Problem: Generic Type Not Inferred Correctly

**Symptom**: TypeScript can't infer the generic type, resulting in `unknown` or requiring explicit type annotations everywhere.

```ts
// Function where T is inferred from the return type — problematic
function createStore<T>(): Store<T> { ... }
const store = createStore()  // T is unknown — TypeScript can't infer from return type

// GOOD: infer T from input parameter, not return type
function createStore<T>(initial: T): Store<T> { ... }
const store = createStore({ count: 0 })  // T inferred as { count: number }
```

**Fix**: TypeScript infers generic types from function parameters, not from return types. Structure generics so the type information flows in through the arguments.

## Problem: `Type 'string' is not assignable to type 'never'`

**Symptom**: TypeScript says `never` where you expected a union member.

**Root cause**: Exhaustive switch with missing cases or incorrect conditional narrowing:

```ts
// WRONG: TypeScript correctly catches the missing case
type Status = 'draft' | 'sent' | 'paid' | 'cancelled'
function getLabel(status: Status): string {
  switch (status) {
    case 'draft': return 'Draft'
    case 'sent': return 'Sent'
    case 'paid': return 'Paid'
    // 'cancelled' is missing → TypeScript infers the function may return undefined
  }
}

// GOOD: exhaustive switch with assertion
function getLabel(status: Status): string {
  switch (status) {
    case 'draft': return 'Draft'
    case 'sent': return 'Sent'
    case 'paid': return 'Paid'
    case 'cancelled': return 'Cancelled'
    default: {
      const _exhaustive: never = status
      throw new Error(`Unhandled status: ${_exhaustive}`)
    }
  }
}
```

The `_exhaustive: never` pattern causes a compile error if a new status is added to the union without updating the switch.

## Problem: `Property 'X' does not exist on type '{}'`

**Root cause 1**: Object type inferred as `{}` instead of the expected interface — usually from a function returning a bare `{}`:

```ts
// BAD: TypeScript infers return as {}
function getOptions() {
  return {}  // Type is {}
}
const opts = getOptions()
opts.timeout  // Error: Property 'timeout' does not exist on type '{}'

// GOOD: annotate the return type explicitly
function getOptions(): { timeout: number; retries: number } {
  return { timeout: 5000, retries: 3 }
}
```

**Root cause 2**: Object spread losing type information:

```ts
const base = { name: 'Alice' }
const extended = { ...base, role: 'admin' }  // Type: { name: string; role: string }
// This is fine — TypeScript handles spreads well

// Problem occurs when spreading `unknown`:
const data: unknown = fetchData()
const extended = { ...data, extra: true }  // Error: spread requires iterable/object
```

## Problem: Overloads Resolve to Wrong Signature

**Symptom**: Function call returns `never` or the wrong overloaded type.

```ts
// BAD: TypeScript picks the wrong overload based on argument order
function process(input: string): ProcessedString
function process(input: number): ProcessedNumber
function process(input: string | number): ProcessedString | ProcessedNumber { ... }

// MORE SPECIFIC OVERLOADS FIRST:
// TypeScript tries overloads in order — most specific must come first
function process(input: string): ProcessedString
function process(input: number): ProcessedNumber
function process(input: string | number): ProcessedString | ProcessedNumber
```

## Problem: `Type instantiation is excessively deep`

**Symptom**: TypeScript errors on deeply nested generic types, recursive types, or Zod schemas.

**Root cause**: Zod's type inference or recursive TypeScript types exceed the recursion limit.

**Fix**: Explicitly annotate the type to short-circuit inference:

```ts
// Zod recursive type — TypeScript can't infer the depth
const CategorySchema: z.ZodType<Category> = z.object({
  id: z.string(),
  name: z.string(),
  children: z.lazy(() => z.array(CategorySchema)).optional(),  // Explicit annotation required
})

// Without the explicit z.ZodType<Category> annotation, TypeScript gives "excessively deep"
```

## Problem: `Cannot find module` After Build (But Works in Dev)

**Symptom**: TypeScript works in `tsc --watch` but fails after `next build`.

**Root cause 1**: `baseUrl` and `paths` in `tsconfig.json` set up for IDE but not matching what the bundler resolves.

**Root cause 2**: Case sensitivity — `import './MyComponent'` works on macOS (case-insensitive FS) but fails on Linux/Docker (case-sensitive FS).

**Fix**: Match import case exactly to filename case. Use `import './MyComponent'` when the file is `MyComponent.tsx`, not `import './mycomponent'`.

## Problem: `any` Escaping Through Return Type

```ts
// BAD: loose typing propagates any
function parseConfig(json: string) {
  return JSON.parse(json)  // Returns `any` — contaminates everything downstream
}

// GOOD: parse through a schema to get a typed result
function parseConfig(json: string): AppConfig {
  const raw = JSON.parse(json)
  return AppConfigSchema.parse(raw)  // Zod throws if invalid, returns typed value
}
```

`JSON.parse` always returns `any`. Always go through a Zod schema or explicit type assertion after parsing JSON.
