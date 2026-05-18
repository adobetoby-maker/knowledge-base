# Plugin: Immer (Immutable State Updates)

## Overview

Immer lets you write mutating code that produces immutable updates. The key value: complex nested state updates that would require spread operators 3-4 levels deep become readable. Use it when state update logic is hard to follow due to deeply nested spreads.

## Installation

```bash
npm install immer
```

## produce

```ts
import { produce } from 'immer'

const state = {
  user: { name: 'Alice', settings: { theme: 'light', notifications: { email: true, sms: false } } },
  items: [{ id: '1', done: false }, { id: '2', done: false }],
}

// Without Immer — deeply nested update
const nextState = {
  ...state,
  user: {
    ...state.user,
    settings: {
      ...state.user.settings,
      notifications: {
        ...state.user.settings.notifications,
        sms: true,
      },
    },
  },
}

// With Immer — same result, readable
const nextState = produce(state, draft => {
  draft.user.settings.notifications.sms = true
})
```

## React useState

```tsx
import { useImmer } from 'use-immer'

function Editor() {
  const [doc, updateDoc] = useImmer({
    title: '',
    blocks: [] as Block[],
    meta: { tags: [], published: false },
  })

  function addBlock(type: string) {
    updateDoc(draft => {
      draft.blocks.push({ id: crypto.randomUUID(), type, content: '' })
    })
  }

  function updateBlockContent(id: string, content: string) {
    updateDoc(draft => {
      const block = draft.blocks.find(b => b.id === id)
      if (block) block.content = content
    })
  }

  function togglePublished() {
    updateDoc(draft => { draft.meta.published = !draft.meta.published })
  }
}
```

```bash
npm install use-immer
```

## zustand + immer

```ts
import { create } from 'zustand'
import { immer } from 'zustand/middleware/immer'

const useStore = create(immer<State>((set) => ({
  todos: [],
  addTodo: (text) => set(state => {
    state.todos.push({ id: crypto.randomUUID(), text, done: false })
  }),
  toggleTodo: (id) => set(state => {
    const todo = state.todos.find(t => t.id === id)
    if (todo) todo.done = !todo.done
  }),
})))
```

## When NOT to Use Immer

Immer adds overhead — a proxy layer wraps every access. Don't use it for:

- Simple top-level updates: `setCount(c => c + 1)` — spread is cleaner
- Performance-critical hot paths processing thousands of items
- Arrays of primitives: `setTags(prev => [...prev, newTag])` — spread is fine

Use Immer when your update function looks like nested spreading more than 2 levels deep.

## produce with Return Value

```ts
const nextState = produce(state, draft => {
  if (draft.user.plan === 'free') {
    return state  // Return original — abort the draft
  }
  draft.user.plan = 'pro'
})
```

Returning a value from the recipe replaces the draft entirely. Useful for conditional updates.

## Key Rules

- Immer drafts are Proxies — they behave like mutable objects but never modify the original.
- Never return the draft from the recipe AND mutate it — pick one.
- `produce` is pure — the same draft recipe always produces the same output given the same input.
- The `current(draft)` utility gives you a plain snapshot of the draft for debugging: `console.log(current(draft))`.
