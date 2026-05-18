# Plugin: Jotai (Atomic State Management)

## Overview

Jotai is atomic state management for React — each piece of state is an "atom" and components subscribe only to what they need. Positioning: lighter than Zustand (no store boilerplate), more composable than Context, and designed for React's rendering model. Best for UI state that needs to be shared across components without prop drilling.

## Installation

```bash
npm install jotai
```

## Basic Atoms

```ts
import { atom } from 'jotai'

// Primitive atom — like useState but global
export const sidebarOpenAtom = atom(false)
export const themeAtom = atom<'light' | 'dark'>('light')
export const selectedIdsAtom = atom<Set<string>>(new Set())

// Derived (read-only) atom — computed from other atoms
export const selectedCountAtom = atom(get => get(selectedIdsAtom).size)
```

## Using Atoms in Components

```tsx
import { useAtom, useAtomValue, useSetAtom } from 'jotai'

function Sidebar() {
  const [open, setOpen] = useAtom(sidebarOpenAtom)
  return (
    <div className={open ? 'w-64' : 'w-0'}>
      <button onClick={() => setOpen(o => !o)}>Toggle</button>
    </div>
  )
}

function NavButton() {
  // Only needs the setter — won't re-render when sidebar state changes
  const setOpen = useSetAtom(sidebarOpenAtom)
  return <button onClick={() => setOpen(true)}>Open Menu</button>
}

function SelectionBadge() {
  // Only reads derived value — subscribes to count changes
  const count = useAtomValue(selectedCountAtom)
  return count > 0 ? <span>{count} selected</span> : null
}
```

## Writable Derived Atoms

```ts
export const todoListAtom = atom<Todo[]>([])

// Write atom that encapsulates toggle logic
export const toggleTodoAtom = atom(null, (get, set, id: string) => {
  set(todoListAtom, prev =>
    prev.map(todo => todo.id === id ? { ...todo, done: !todo.done } : todo)
  )
})

// Usage
const toggleTodo = useSetAtom(toggleTodoAtom)
toggleTodo('123')
```

## Async Atoms (Data Fetching)

```ts
import { atom } from 'jotai'

export const userIdAtom = atom<string | null>(null)

// Derived async atom — automatically suspends
export const userAtom = atom(async get => {
  const id = get(userIdAtom)
  if (!id) return null
  const res = await fetch(`/api/users/${id}`)
  return res.json()
})
```

```tsx
// Wrap in Suspense
function UserProfile() {
  const user = useAtomValue(userAtom)  // Suspends until resolved
  return <div>{user?.name}</div>
}

<Suspense fallback={<Skeleton />}>
  <UserProfile />
</Suspense>
```

## atomWithStorage (Persistence)

```ts
import { atomWithStorage } from 'jotai/utils'

export const themeAtom = atomWithStorage<'light' | 'dark'>('theme', 'light')
// Reads from localStorage on init, persists on change
```

## atomWithReset

```ts
import { atomWithReset, useResetAtom } from 'jotai/utils'

export const filterAtom = atomWithReset({ status: 'all', sort: 'date' })

function FilterReset() {
  const resetFilter = useResetAtom(filterAtom)
  return <button onClick={resetFilter}>Clear filters</button>
}
```

## Jotai vs Zustand

| | Jotai | Zustand |
|---|---|---|
| Model | Atoms (fine-grained) | Single store |
| Boilerplate | Less | More |
| DevTools | Jotai DevTools | Zustand DevTools |
| Async | Built-in Suspense | Manual loading state |
| Best for | UI state, many small pieces | App-wide state, business logic |

## Key Rules

- `useAtomValue` when you only read — prevents re-renders when other atoms change.
- `useSetAtom` when you only write — also prevents re-renders.
- Atoms are module-level singletons — don't create atoms inside components.
- For server-side rendering: use `Provider` with `initialValues` to seed atom state without a global mutable default.
