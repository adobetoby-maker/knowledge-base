# Plugin: Zustand

## What It Is

Zustand is a minimal global state management library for React. ~1KB. Uses hooks to subscribe to specific slices of state — components only re-render when their subscribed slice changes. Alternative to Context + useReducer for app-wide state.

## Installation

```bash
npm install zustand
```

## When to Use Zustand vs React State vs Context

| State type | Solution |
|-----------|---------|
| Component-local (one component) | `useState` |
| Feature-local (component tree) | `useState` + prop drilling or `useContext` |
| Cross-page, cross-component | Zustand |
| Server state (remote data) | TanStack Query |
| Form state | React Hook Form |

Use Zustand for: UI state that's needed by many unrelated components (sidebar open/close, selected item, notification queue, cart), not for server data.

## Basic Store

```ts
// lib/stores/ui-store.ts
import { create } from 'zustand'

interface UIState {
  sidebarOpen: boolean
  toggleSidebar: () => void
  setSidebarOpen: (open: boolean) => void
}

export const useUIStore = create<UIState>()((set) => ({
  sidebarOpen: false,
  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
  setSidebarOpen: (open) => set({ sidebarOpen: open }),
}))
```

```tsx
// In any component
import { useUIStore } from '@/lib/stores/ui-store'

function Sidebar() {
  const isOpen = useUIStore((state) => state.sidebarOpen)
  return <aside className={isOpen ? 'open' : 'closed'}>...</aside>
}

function NavButton() {
  const toggle = useUIStore((state) => state.toggleSidebar)
  return <button onClick={toggle}>Menu</button>
}
```

Each component subscribes to exactly what it needs — `Sidebar` only re-renders when `sidebarOpen` changes, not when other store values change.

## Store with Async Actions

```ts
// lib/stores/cart-store.ts
import { create } from 'zustand'

interface CartItem {
  id: string
  name: string
  priceCents: number
  quantity: number
}

interface CartState {
  items: CartItem[]
  loading: boolean
  addItem: (item: Omit<CartItem, 'quantity'>) => void
  removeItem: (id: string) => void
  updateQuantity: (id: string, quantity: number) => void
  clear: () => void
  totalCents: () => number
}

export const useCartStore = create<CartState>()((set, get) => ({
  items: [],
  loading: false,

  addItem: (item) =>
    set((state) => {
      const existing = state.items.find((i) => i.id === item.id)
      if (existing) {
        return {
          items: state.items.map((i) =>
            i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i
          ),
        }
      }
      return { items: [...state.items, { ...item, quantity: 1 }] }
    }),

  removeItem: (id) =>
    set((state) => ({ items: state.items.filter((i) => i.id !== id) })),

  updateQuantity: (id, quantity) =>
    set((state) => ({
      items:
        quantity <= 0
          ? state.items.filter((i) => i.id !== id)
          : state.items.map((i) => (i.id === id ? { ...i, quantity } : i)),
    })),

  clear: () => set({ items: [] }),

  // Computed value — use get() to read current state
  totalCents: () =>
    get().items.reduce((sum, item) => sum + item.priceCents * item.quantity, 0),
}))
```

## Persisted Store

```ts
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

interface PrefsState {
  theme: 'light' | 'dark' | 'system'
  language: string
  setTheme: (theme: PrefsState['theme']) => void
  setLanguage: (lang: string) => void
}

export const usePrefsStore = create<PrefsState>()(
  persist(
    (set) => ({
      theme: 'system',
      language: 'en',
      setTheme: (theme) => set({ theme }),
      setLanguage: (language) => set({ language }),
    }),
    {
      name: 'user-preferences',  // localStorage key
      storage: createJSONStorage(() => localStorage),
    }
  )
)
```

Persistence hydrates on mount. Use `onRehydrateStorage` if you need a callback when hydration completes.

## Devtools Integration

```ts
import { create } from 'zustand'
import { devtools } from 'zustand/middleware'

export const useStore = create<State>()(
  devtools(
    (set) => ({
      // store definition
    }),
    { name: 'MyStore' }  // Name shown in Redux DevTools
  )
)
```

## Sliced Store (Large Stores)

```ts
// For large stores, split into slices
type StoreState = UISlice & CartSlice & UserSlice

const useStore = create<StoreState>()((...a) => ({
  ...createUISlice(...a),
  ...createCartSlice(...a),
  ...createUserSlice(...a),
}))
```

## Zustand vs TanStack Query

Never put server data in Zustand:
```ts
// WRONG — server data in Zustand (stale, no invalidation, no dedup)
const useInvoiceStore = create(() => ({
  invoices: [],
  fetchInvoices: async () => { /* fetch and set */ }
}))

// CORRECT — server data in TanStack Query
const { data: invoices } = useQuery({
  queryKey: ['invoices'],
  queryFn: fetchInvoices,
})
```

Zustand is for UI state. TanStack Query is for server state.
