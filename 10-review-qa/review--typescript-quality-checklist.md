# Review: TypeScript Quality Checklist

## Overview
TypeScript's value is proportional to how strictly it is used. A codebase full of `any`, `as` casts,
and disabled checks provides false confidence — the type checker passes but runtime errors still occur.
This checklist identifies patterns that erode type safety and explains why each matters.

## Implementation

### Strict Mode Configuration
```json
// tsconfig.json — minimum required for meaningful type safety
{
  "compilerOptions": {
    "strict": true,             // enables all strict checks below
    // Equivalent to:
    "noImplicitAny": true,      // error on implicit any (e.g., untyped function params)
    "strictNullChecks": true,   // null/undefined must be handled explicitly
    "strictFunctionTypes": true,
    "strictPropertyInitialization": true,
    "noImplicitThis": true,

    // Additional hardening
    "noUncheckedIndexedAccess": true,  // array[n] returns T | undefined (not T)
    "exactOptionalPropertyTypes": true  // { a?: string } != { a: string | undefined }
  }
}
```

### No `any` Except at Genuine Boundaries
```ts
// ✗ Escape hatch: silences errors, provides zero safety
function process(data: any) { ... }

// ✓ Use unknown for untyped external data, then narrow
function process(data: unknown) {
  if (typeof data === 'object' && data !== null && 'id' in data) {
    // TypeScript narrows to { id: unknown }
    const id = (data as { id: string }).id;  // as cast after narrowing is acceptable
  }
}

// ✓ Legitimate any: dynamic library interop, JSON.parse result
const parsed: unknown = JSON.parse(rawJson);  // use unknown, validate with Zod
```

### Zod Validation at HTTP Boundary
```ts
// HTTP request bodies are untyped at runtime
// ✗ Trusting req.body without validation:
app.post('/users', (req, res) => {
  const { email, password } = req.body;  // could be anything at runtime
  createUser(email, password);
});

// ✓ Validate and parse at the boundary:
import { z } from 'zod';
const CreateUserInput = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

app.post('/users', (req, res) => {
  const result = CreateUserInput.safeParse(req.body);
  if (!result.success) return res.status(400).json(result.error.flatten());
  createUser(result.data.email, result.data.password);  // now typed and validated
});
```

### Discriminated Unions for State
```ts
// ✗ Loose state with optional fields — hard to reason about
interface RequestState {
  loading: boolean;
  data?: User;
  error?: string;  // can loading=true AND error be set simultaneously?
}

// ✓ Discriminated union — each state is unambiguous
type RequestState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: User }
  | { status: 'error'; error: string };

// TypeScript exhaustively checks the switch
function render(state: RequestState) {
  switch (state.status) {
    case 'idle': return <Idle />;
    case 'loading': return <Spinner />;
    case 'success': return <UserCard user={state.data} />;  // data is non-null here
    case 'error': return <Error message={state.error} />;
  }
}
```

### No `as` Casts to Silence Errors
```ts
// ✗ Type assertion to bypass an error
const user = response.data as User;  // asserts without checking

// ✓ Use type guards or Zod to earn the type
function isUser(data: unknown): data is User {
  return (
    typeof data === 'object' && data !== null &&
    'id' in data && typeof (data as any).id === 'string' &&
    'email' in data && typeof (data as any).email === 'string'
  );
}

// Or parse with Zod (runtime check + type inference)
const UserSchema = z.object({ id: z.string(), email: z.string() });
const user = UserSchema.parse(response.data);  // throws on invalid, returns User
```

### Branded Types for Domain IDs
```ts
// ✗ All IDs are just strings — easy to mix up
function assignPost(userId: string, postId: string) { ... }
assignPost(post.id, user.id);  // TypeScript can't catch this swap

// ✓ Branded types prevent wrong-ID bugs
type UserId = string & { readonly _brand: 'UserId' };
type PostId = string & { readonly _brand: 'PostId' };

function createUserId(id: string): UserId { return id as UserId; }

function assignPost(userId: UserId, postId: PostId) { ... }
assignPost(post.id, user.id);  // Error: PostId not assignable to UserId
```

## Key Rules
- Enable `strict: true` in all new projects — retrofitting strict mode into an existing codebase is much harder
- `any` at a genuine boundary (external API response, JSON.parse) is acceptable — but annotate with a comment explaining why
- Validate all external data with Zod at the entry point, never in the middle of business logic
- Discriminated unions eliminate an entire class of "impossible state" bugs that `null` checks cannot
- `as` casts that suppress genuine type errors are technical debt — document why the cast is safe or fix the underlying type
- `noUncheckedIndexedAccess` makes array access honest — `arr[0]` returns `T | undefined`, forcing null checks
- Run `tsc --noEmit` in CI to catch type errors that ESLint does not
