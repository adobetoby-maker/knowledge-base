# principle--naming-conventions-applied.md

Consistent naming conventions reduce the cognitive load of reading code you didn't write. When names follow predictable patterns, you can infer purpose from form — a function that starts with `handle` is a UI event handler, a variable starting with `is` is a boolean, a file in `PascalCase.tsx` is a component. These signals don't require documentation; they're encoded in the name.

## File Naming: kebab-case

All files except React components use kebab-case:

```
lib/auth-utils.ts
lib/supabase/server.ts
hooks/use-debounce.ts
app/api/users/route.ts
```

React component files use PascalCase matching the component name:

```
components/UserAvatar.tsx
components/NavigationBar.tsx
app/(dashboard)/profile/page.tsx  ← exception: Next.js convention overrides
```

The reason: kebab-case is unambiguous on case-insensitive filesystems (macOS) and maps naturally to URLs. PascalCase for components makes imports self-documenting — `import UserAvatar from './UserAvatar'` is immediately clear.

## Component Naming: PascalCase, Noun or Noun Phrase

Component names are nouns — they describe a thing, not an action:

```tsx
UserProfile     // not: ShowUserProfile, RenderUserProfile
NavigationBar   // not: topBar, navbar
ProductCard     // not: displayProduct
```

If you find yourself naming a component with a verb, it's probably a function with side effects, not a display component. Extract the logic to a hook and name the component for what it renders.

## Function Naming: camelCase Verbs

Functions are verbs — they do something. Prefix with the action:

```ts
getUser()       fetchProducts()     calculateTotal()
createInvoice() updateProfile()     deleteSession()
validateEmail() parseQueryString()  formatCurrency()
```

Query functions that return data: `get`, `fetch`, `find`, `search`, `load`.
Mutation functions: `create`, `update`, `delete`, `save`, `submit`.
Transformation functions: `format`, `parse`, `convert`, `calculate`, `transform`.

Avoid generic names like `handleData()`, `processStuff()`, `doThing()` — these tell you nothing about what the function does.

## Boolean Naming: is/has/can/should Prefix

Booleans that aren't prefixed are ambiguous — `loading`, `admin`, `submitted` could be anything. Prefixes make the boolean nature unambiguous:

```ts
isLoading       isAdmin         isAuthenticated
hasPermission   hasErrors       hasPendingChanges
canEdit         canDelete       canSubmit
shouldRefetch   shouldRedirect
```

Avoid negated names like `isNotLoading` or `isDisabled` when the affirmative form is available — double negatives in conditions are hard to parse: `if (!isDisabled)` is clearer than `if (!isNotEnabled)`.

## Event Handler Naming: handle vs on

Two distinct naming roles:

**`onX`** — a prop that accepts a callback. Names the event from the parent's perspective:
```tsx
<Button onClick={...} />
<Form onSubmit={...} />
<Input onChange={...} />
```

**`handleX`** — the function that is passed as the callback. Names the action from the handler's perspective:
```tsx
function handleSubmit(e: FormEvent) { ... }
function handleUserDelete(userId: string) { ... }

<Form onSubmit={handleSubmit} />
```

This convention makes the data flow readable: the parent passes `onSubmit`, the child calls it; the parent implements `handleSubmit`, which is the concrete reaction to the event. Never name a prop `handleX` — that's an implementation detail, not an interface.

## Constant and Enum Naming: SCREAMING_SNAKE_CASE or PascalCase

Module-level constants that are truly fixed values use SCREAMING_SNAKE_CASE:
```ts
const MAX_RETRY_COUNT = 3;
const API_BASE_URL = 'https://api.example.com';
```

TypeScript enums and const objects used as enums use PascalCase:
```ts
const OrderStatus = { Pending: 'pending', Fulfilled: 'fulfilled' } as const;
```

Avoid using SCREAMING_SNAKE_CASE for values that could change per environment or are computed at runtime — that falsely implies they're universal constants.

## Key Rules

- Files: kebab-case for everything, PascalCase only for React component files.
- Components: PascalCase nouns — they describe what they render, not what they do.
- Functions: camelCase verbs — `get`, `create`, `update`, `delete`, `format`, `parse` etc.
- Booleans: prefix with `is`, `has`, `can`, `should` — no ambiguous noun booleans.
- Event handler props: `onX`; event handler implementations: `handleX` — never swap these.
