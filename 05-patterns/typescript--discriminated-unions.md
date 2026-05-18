# TypeScript — Discriminated Unions for State

**When:** Modeling state that has multiple mutually exclusive shapes — loading/success/error, different UI modes, different entity types.
**Rule:** Use discriminated unions instead of nullable optional fields. The union makes impossible states impossible.

## Why Optional Fields Are Dangerous
```typescript
// BAD — 8 possible combinations, most are meaningless
interface State {
  isLoading?: boolean
  data?: User
  error?: string
}
// What does { isLoading: true, data: user, error: "failed" } mean?
// TypeScript allows it. Your code has to handle it.
```

## The Discriminated Union Pattern
```typescript
// GOOD — 3 valid states, impossible states are unrepresentable
type State =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: User }
  | { status: 'error'; error: string }

// TypeScript narrows automatically
if (state.status === 'success') {
  console.log(state.data.name)  // TypeScript knows data exists
}
if (state.status === 'error') {
  console.log(state.error)  // TypeScript knows error exists
}
// state.data is not accessible on 'error' state — compile error, not runtime bug
```

## React useState with Discriminated Union
```typescript
const [state, setState] = useState<State>({ status: 'idle' })

async function loadUser(id: string) {
  setState({ status: 'loading' })
  try {
    const user = await fetchUser(id)
    setState({ status: 'success', data: user })
  } catch (e) {
    setState({ status: 'error', error: (e as Error).message })
  }
}

// Rendering — exhaustive switch
switch (state.status) {
  case 'idle':    return <IdleState />
  case 'loading': return <Spinner />
  case 'success': return <UserCard user={state.data} />
  case 'error':   return <ErrorMessage message={state.error} />
}
```

## Exhaustive Checks — Never Miss a Case
```typescript
// This makes TypeScript error if you add a new status and forget to handle it
function assertNever(x: never): never {
  throw new Error('Unhandled case: ' + x)
}

switch (state.status) {
  case 'idle':    return <Idle />
  case 'loading': return <Loading />
  case 'success': return <Success data={state.data} />
  case 'error':   return <Error err={state.error} />
  default:        return assertNever(state)  // TypeScript error if case missing
}
```

## When to Use (vs Interfaces)
- IF the object has different fields depending on a "type" or "status" → discriminated union
- IF you're modeling async operation state → discriminated union
- IF you're modeling different entity variants → discriminated union
- IF fields are always present → regular interface

## Common Application: API Responses
```typescript
type ApiResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: string; statusCode: number }

async function fetchUser(id: string): Promise<ApiResult<User>> {
  const res = await fetch(`/api/users/${id}`)
  if (!res.ok) return { ok: false, error: await res.text(), statusCode: res.status }
  return { ok: true, data: await res.json() }
}
```
