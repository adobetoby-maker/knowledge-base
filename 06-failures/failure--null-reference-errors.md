# Failure: TypeScript Null/Undefined Runtime Errors

## Why TypeScript Doesn't Save You By Default

TypeScript's type system can catch null reference errors — but only if `strictNullChecks: true` is in `tsconfig.json`. Without it, `null` and `undefined` are assignable to every type. A function typed to return `User` might actually return `undefined`, TypeScript won't complain, and your code fails at runtime when you access `.email` on `undefined`.

With `strictNullChecks`, TypeScript forces you to handle nullable types. This is not optional — running without it gives you TypeScript's syntax without TypeScript's safety.

## Optional Chaining Pitfalls (Hiding Bugs)

Optional chaining (`?.`) is the right tool for accessing properties on values that might be null, but it silently swallows `undefined` and can hide problems:

```typescript
// This never throws — but silently sends "undefined" as the email
const email = user?.profile?.email;
await sendEmail(email); // email is `string | undefined`; sendEmail might accept it and break later

// Better: narrow first, then access
if (!user?.profile?.email) {
  throw new Error("User has no email address");
}
await sendEmail(user.profile.email); // TypeScript knows this is string
```

Optional chaining is appropriate when the absence of a value is a valid, expected state and your code handles it. It's wrong when absence is an error condition — use it there and you defer the failure to a confusing location.

## Non-Null Assertion Operator Misuse

The `!` postfix operator tells TypeScript "trust me, this is not null." It disables the null check. This is a lie you tell the compiler, and you pay for it at runtime when the value actually is null.

```typescript
// BAD — if supabase returns null for a missing row, this crashes
const user = await getUser(id)!;  // ← "definitely not null" — until it is
console.log(user.email);          // TypeError: Cannot read properties of null

// GOOD — handle the nullable case explicitly
const user = await getUser(id);
if (!user) {
  return notFound();
}
console.log(user.email); // TypeScript now knows user is non-null
```

Reserve `!` for situations where you have outside information the type system can't capture — for example, after a `document.getElementById` where you know the element exists in the HTML. Even then, prefer a runtime assertion.

## Proper Null Narrowing with If-Checks

The correct pattern is to narrow the type explicitly before use. TypeScript's control flow analysis tracks narrowing:

```typescript
function displayUserName(user: User | null | undefined): string {
  if (user == null) {  // catches both null and undefined
    return "Guest";
  }
  // TypeScript knows user is User here
  return user.name;
}

// Array access — TypeScript doesn't narrow array bounds
const first = items[0]; // type: Item | undefined if noUncheckedIndexedAccess is on
if (!first) {
  return;
}
// now first is Item
```

For deeply nested nullable access where you do want to proceed with a fallback:

```typescript
// Explicit fallback with nullish coalescing
const city = user?.address?.city ?? "Unknown";
```

## Enable strictNullChecks + noUncheckedIndexedAccess

`tsconfig.json` settings that catch null errors before runtime:

```json
{
  "compilerOptions": {
    "strict": true,                    // enables strictNullChecks and more
    "noUncheckedIndexedAccess": true   // array[0] becomes T | undefined
  }
}
```

`noUncheckedIndexedAccess` is not included in `strict` mode but is highly recommended. Without it, TypeScript assumes `array[0]` is `T` even if the array might be empty.

## Common Null Sources in Web Apps

- **Database queries returning `null`** for missing rows — always check before accessing fields.
- **`document.querySelector`** returns `Element | null` — always null-check before using.
- **JSON parsed from external APIs** — the shape might not match your types; use `zod` to validate.
- **Optional URL params / search params** — `searchParams.get("id")` returns `string | null`.
- **React refs** — `ref.current` is `T | null` before the component mounts.

## Key Rules

- **`strictNullChecks: true` is mandatory** — without it, TypeScript's null safety is theater.
- **`!` non-null assertion is a code smell** — almost always replaceable with proper narrowing.
- **`?.` optional chaining hides bugs when absence is an error** — use it only when null is expected and handled.
- **Narrow types explicitly before use** — `if (!x) return` is safer than `x!.prop`.
- **Use `??` for fallbacks, `?.` for optional access, never `!` for wishful thinking.**
- **Validate external data with zod** — type assertions on API responses don't survive contact with real APIs.
