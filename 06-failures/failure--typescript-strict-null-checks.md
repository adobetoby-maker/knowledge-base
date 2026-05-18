# Failure: TypeScript Strict Null Checks Migration

## Overview
Enabling `strictNullChecks` on an existing TypeScript project produces hundreds or thousands of errors simultaneously. The naive fix — casting everything as `as Type` or adding `!` non-null assertions everywhere — silences the compiler while hiding the exact bugs that `strictNullChecks` was meant to catch. The correct approach is a two-pass migration: first make the build pass using `!` as explicit TODOs, then fix them properly one by one.

## Why It Explodes on Enable

Without `strictNullChecks`, `null` and `undefined` are assignable to every type:
```typescript
// strictNullChecks: false (default)
let name: string = null;  // allowed — no error
name.toUpperCase();       // runtime crash — TypeScript didn't warn
```

Enabling it means every place where `null`/`undefined` can flow into a non-nullable type now errors. In a mature codebase, this is everywhere.

## The Wrong Fix: Mass Casting

```typescript
// "Fixes" the error but re-introduces the runtime crash risk
const user = getUser() as User;  // if getUser() returns null, this hides it
user.name.toUpperCase();         // still crashes at runtime

// Non-null assertion: same problem
const user = getUser()!;
user.name.toUpperCase();  // '!' tells TypeScript "trust me" — if wrong, runtime crash
```

Using `as Type` or `!` to silence errors defeats the purpose and leaves bugs hidden.

## The Two-Pass Migration Strategy

### Pass 1: Make the Build Pass (TODOs)
Replace errors with `!` assertions that are explicitly labeled as technical debt:
```typescript
// Add a comment so grep/lint can find all TODOs later
const user = getUser()!;  // TODO(strict-null): handle null case
const name = user.name!;  // TODO(strict-null): handle undefined name
```

This gets the build green quickly. The codebase is no safer, but the type-check passes and new code is now protected.

### Pass 2: Fix Assertions Properly
Grep for `TODO(strict-null)` and fix each one with the appropriate pattern:

```typescript
// Pattern 1: early return / guard
const user = getUser();
if (!user) return null;
user.name.toUpperCase();  // TypeScript now knows user is non-null here

// Pattern 2: nullish coalescing / optional chaining
const name = user?.name ?? 'Anonymous';

// Pattern 3: type narrowing in conditions
if (user !== null && user !== undefined) {
  user.name.toUpperCase();  // narrowed
}

// Pattern 4: update the type to reflect reality
function getUser(): User | null { ... }  // make null explicit in return type
```

## Incremental Adoption with `@ts-strict-ignore`

For very large codebases, per-file adoption is possible:
```typescript
// @ts-strict-ignore
// This file has not been migrated to strictNullChecks yet
```

Or use `typescript-strict-plugin` (or `@shopify/typescript-configs`) to enforce strict mode per-directory.

## Common Patterns After Enabling

```typescript
// Array.find returns T | undefined
const item = items.find(i => i.id === id);
item.name;  // ERROR: Object is possibly 'undefined'
// Fix:
if (item) item.name;
// or:
items.find(i => i.id === id)?.name;

// Object property access on potentially-undefined nested value
user.address.city;  // ERROR: Object is possibly 'undefined' if address is optional
// Fix:
user.address?.city;
user.address?.city ?? 'Unknown';

// DOM queries return Element | null
const button = document.querySelector('.submit');
button.addEventListener('click', handler);  // ERROR
// Fix:
button?.addEventListener('click', handler);
```

## tsconfig Settings

```json
{
  "compilerOptions": {
    "strict": true,          // Enables strictNullChecks and more
    "strictNullChecks": true  // Enable individually if not using strict
  }
}
```

`"strict": true` enables: `strictNullChecks`, `noImplicitAny`, `strictFunctionTypes`, and more.

## Key Rules
- Never use `as Type` or `!` to silence a strictNullChecks error in production code without a TODO comment
- Two-pass migration: `!` assertions as explicit TODOs first, then systematic fixes
- `?.` (optional chaining) and `??` (nullish coalescing) handle 80% of null safety issues elegantly
- Array `.find()` always returns `T | undefined` — always guard the result
- DOM queries always return `Element | null` — always check before using
- Enabling `strictNullChecks` is a one-time investment; the ongoing cost is near zero once done
