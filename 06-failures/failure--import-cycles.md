# Failure: Circular Imports in TypeScript

## Overview
A circular import (module A imports module B which imports module A) causes JavaScript to return `undefined` for the circularly-imported value at the point of use. This happens because module evaluation is interleaved — module A starts evaluating, encounters the import of B, which starts evaluating, encounters the import of A, which is already "in progress" and returns its current (incomplete) exports. The result: a runtime error like `TypeError: X is not a function` when the value is actually exported correctly.

## What Circular Imports Look Like

```
// Circular dependency chain
userService.ts → emailService.ts → userService.ts
                     ↑________________________|

// lib/userService.ts
import { sendWelcomeEmail } from './emailService'
export const createUser = async (email: string) => {
  const user = await db.users.create({ email })
  await sendWelcomeEmail(user)
  return user
}

// lib/emailService.ts
import { getUserPreferences } from './userService'  // ← circular!
export const sendWelcomeEmail = async (user: User) => {
  const prefs = await getUserPreferences(user.id)
  await mailer.send({ to: user.email, ...prefs })
}
```

At runtime: `sendWelcomeEmail` may be `undefined` even though it's exported correctly, because `emailService.ts` is still evaluating when `userService.ts` first imports it.

## Detecting Circular Imports

```bash
npm install --save-dev madge

# Check for circular dependencies
npx madge --circular --extensions ts,tsx src/

# Visual output (requires graphviz)
npx madge --circular --image graph.svg src/
```

Add to CI:

```yaml
- name: Check circular dependencies
  run: npx madge --circular --extensions ts,tsx src/ && echo "No circular deps"
```

## Fix Strategy 1: Extract Shared Code to a Third Module

```
# Before: A ↔ B circular
userService.ts ↔ emailService.ts

# After: both depend on shared module
userService.ts → userTypes.ts ← emailService.ts

// lib/userTypes.ts — no imports from userService or emailService
export type User = { id: string; email: string; name: string }
export type UserPreferences = { emailFormat: 'html' | 'text' }
```

## Fix Strategy 2: Restructure Dependencies

```ts
// Before: emailService needs getUserPreferences from userService
// After: pass preferences as a parameter instead of importing

// lib/emailService.ts — no longer imports userService
export const sendWelcomeEmail = async (user: User, prefs: UserPreferences) => {
  await mailer.send({ to: user.email, ...prefs })
}

// lib/userService.ts
import { sendWelcomeEmail } from './emailService'
export const createUser = async (email: string) => {
  const user = await db.users.create({ email })
  const prefs = await db.userPreferences.findDefault()
  await sendWelcomeEmail(user, prefs)  // pass prefs directly
  return user
}
```

## Barrel Files as Circular Import Source

```ts
// lib/index.ts — re-exports everything
export * from './userService'
export * from './emailService'
export * from './db'

// lib/userService.ts
import { db } from './index'  // imports from barrel → barrel imports userService → circular!

// lib/userService.ts (fixed)
import { db } from './db'  // import directly, not through barrel
```

Barrel files (`index.ts`) that re-export everything are the most common source of hidden circular imports. Import from specific files, not barrel re-exports.

## Symptoms to Recognize

| Symptom | Likely Cause |
|---|---|
| `TypeError: X is not a function` but X is clearly exported | Circular import, X is undefined at call time |
| Works in isolation but fails when imported together | Circular import between those two modules |
| Tests pass individually but fail when run together | Test helper barrel file creating circular dep |
| `Cannot access 'X' before initialization` | Circular import with `const` (not hoisted) |

## Key Rules
- Run `madge --circular` in CI — catch circular deps before they cause runtime failures
- Never import from barrel `index.ts` files within the same directory — import from specific modules
- When you encounter `X is not a function` / `X is undefined` for something clearly exported, check for circular imports first
- Circular imports are allowed in some cases (e.g., TypeScript type-only imports), but value imports in cycles cause runtime issues
- The fix is never `require()` inside a function body (that works but is a hack) — restructure the dependencies
