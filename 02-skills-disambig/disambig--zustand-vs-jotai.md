# Disambig: Zustand vs Jotai

## Overview
Both are minimal React state management libraries that avoid the boilerplate of Redux. They represent two different mental models: Zustand groups related state into store objects, while Jotai decomposes state into independent atoms. The choice affects component re-render patterns, how derived state works, and how naturally the library fits your state shape.

## Implementation / Key Points

### Zustand — Store-Based
```typescript
import { create } from 'zustand';

interface CartStore {
  items: CartItem[];
  total: number;
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
}

const useCartStore = create<CartStore>((set, get) => ({
  items: [],
  total: 0,
  addItem: (item) => set((state) => ({
    items: [...state.items, item],
    total: state.total + item.price,
  })),
  removeItem: (id) => {
    const removed = get().items.find(i => i.id === id);
    set((state) => ({
      items: state.items.filter(i => i.id !== id),
      total: state.total - (removed?.price ?? 0),
    }));
  },
}));

// Component — subscribe to only what you need (selector)
const itemCount = useCartStore(state => state.items.length);
// Only re-renders when items.length changes, not on total change
```

**Characteristics:**
- One store object per domain
- Selector function controls what triggers re-renders
- Store can hold actions (not just state)
- Works outside React (access via `useCartStore.getState()`)
- DevTools via `zustand/middleware`

### Jotai — Atom-Based
```typescript
import { atom, useAtom, useAtomValue, useSetAtom } from 'jotai';

const cartItemsAtom = atom<CartItem[]>([]);
const cartTotalAtom = atom((get) => 
  get(cartItemsAtom).reduce((sum, item) => sum + item.price, 0)
);

// Derived atom — recalculates when cartItemsAtom changes
const cartCountAtom = atom((get) => get(cartItemsAtom).length);

// Write atom
const addItemAtom = atom(null, (get, set, item: CartItem) => {
  set(cartItemsAtom, [...get(cartItemsAtom), item]);
});

// Component — subscribe to specific atom only
function CartCount() {
  const count = useAtomValue(cartCountAtom);  // only re-renders when count changes
  return <span>{count}</span>;
}
```

**Characteristics:**
- Fine-grained subscriptions — each atom is an independent subscription
- Derived atoms compose like computed values
- React Concurrent Mode friendly (atomic updates)
- No store object — atoms are module-level primitives
- Can be scoped with `Provider` for testing or multi-instance

### Comparison
| Aspect | Zustand | Jotai |
|---|---|---|
| Mental model | Store / slice | Individual atoms |
| Bundle size | ~3KB | ~3KB |
| Derived state | Manual in store | `atom(get => get(a) + get(b))` |
| Re-render control | Selector function | Each atom is its own subscription |
| Access outside React | `store.getState()` | `store.get(atom)` (with store) |
| Concurrent Mode | Good | Excellent (atomic by design) |

## Key Rules
- Use Zustand when state naturally groups together (cart: items + total + actions belong together)
- Use Jotai when state values are independent and fine-grained re-renders matter
- Use Jotai for atomic state that should update without triggering re-renders in unrelated components
- Both handle async operations — Jotai has `atomWithQuery` (jotai-tanstack-query), Zustand handles it manually
- Don't use Zustand for state that changes at high frequency (mouse position, scroll) — selector overhead adds up
- Don't mix Zustand stores and Jotai atoms for the same domain — pick one pattern per concern
- Jotai is better when you need `Provider`-scoped instances (multi-tenant, testing isolation)
