# Failure: Circular Dependencies

## Overview

Circular dependencies occur when Module A imports Module B which imports Module A. In Node.js, this causes partial module loading: one of the modules sees an empty object `{}` instead of the expected exports. The bug is silent — no error is thrown during import, but functions are `undefined` at call time.

## How It Manifests

```ts
// lib/a.ts
import { doB } from './b'
export function doA() { return doB() + '_a' }

// lib/b.ts
import { doA } from './a'  // Circular!
export function doB() { return doA() + '_b' }
```

At runtime: `doB is not a function` or `Cannot read properties of undefined`. The error appears in A's context, not at the import line in B.

## Detection

```bash
# Find circular dependencies
npx madge --circular --extensions ts,tsx src/

# Or with eslint-plugin-import
npx eslint src --rule 'import/no-cycle: error'
```

TypeScript's type checker doesn't catch circular dependencies — they're a runtime problem, not a type error.

## Fix 1: Extract Shared Logic

The most common cause: two modules that both need a third thing. Extract it.

```ts
// BAD: circular
// lib/user.ts imports from lib/auth.ts
// lib/auth.ts imports from lib/user.ts

// GOOD: extract shared type
// lib/types.ts — no imports from lib/
export interface User { id: string; role: string }

// lib/user.ts — imports from lib/types
import type { User } from './types'

// lib/auth.ts — imports from lib/types  
import type { User } from './types'
```

## Fix 2: Dependency Inversion

Instead of importing the concrete implementation, import an interface and inject at call time.

```ts
// BAD: EmailService imports UserService, UserService imports EmailService
class UserService {
  constructor(private email: EmailService) {}
}

class EmailService {
  constructor(private user: UserService) {}  // Circular!
}

// GOOD: break with a callback/function injection
class UserService {
  constructor(
    private sendEmail: (userId: string, template: string) => Promise<void>
  ) {}
}

class EmailService {
  async send(userId: string, template: string) {
    const user = await db.getUser(userId)  // Direct DB access, no UserService
    await this.mailer.send(user.email, template)
  }
}

// Wire at startup
const emailService = new EmailService(mailer)
const userService = new UserService(
  (userId, template) => emailService.send(userId, template)
)
```

## Fix 3: Lazy Import

For cases where the circular dep is unavoidable (e.g., recursive tree structures):

```ts
// lib/a.ts
export async function doA() {
  const { doB } = await import('./b')  // Dynamic import — resolved at call time, not module load
  return doB() + '_a'
}
```

Dynamic imports bypass the circular dependency issue because they run after all modules are loaded. Use sparingly — they add async complexity.

## Fix 4: Restructure Module Boundaries

Circular dependencies between modules often signal that the module boundaries are wrong.

```
BAD structure:
  services/user.ts ←→ services/auth.ts (circular)

GOOD structure:
  services/user/index.ts      — user CRUD
  services/auth/index.ts      — authentication
  services/auth/user-helpers.ts — user-related helpers used by auth
```

Put low-level utilities that many modules need in a `lib/` or `shared/` directory that has no local imports.

## Common Patterns That Cause Circles

1. **Types + logic in the same file** — extract types to `types.ts`
2. **Utility files that import from feature files** — utilities should have no feature-level imports
3. **Re-export barrels** — `index.ts` that re-exports everything creates many implicit dependencies
4. **Zod schema + model in same file** — the schema file imports the DB model file which imports the schema

## Key Rules

- Run `madge --circular` in CI to catch new circular dependencies before they merge.
- `types.ts` files at each layer should have zero local imports — they're the foundation that everything imports from.
- Barrel files (`index.ts` that re-exports everything) amplify circular dependencies — import from specific files, not barrels, in large codebases.
- If B needs A and A needs B, one of them needs to be refactored — there's no clean circular dependency.
- Dynamic `import()` is a last resort, not a first fix — it makes the dependency invisible and adds async complexity.
