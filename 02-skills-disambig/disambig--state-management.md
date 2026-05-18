# Disambiguation: State Management Library Choice

## The Decision Matrix

| State Type | What It Is | Use |
|------------|-----------|-----|
| Server data | API responses, database records | TanStack Query |
| URL state | Filters, search query, pagination | `useSearchParams` + `router.push` |
| Global UI state | Theme, sidebar open, modal queue | Zustand |
| Form state | Input values, validation errors | React Hook Form |
| Component-local state | Toggle, hover, animation step | `useState` |
| Auth state | Current user, session | Supabase Auth + Context |

**99% of the time, one of these six options is right.** If you're considering Redux, Recoil, Jotai, Valtio, or MobX, first verify that none of the above fits.

## The Right Tool for Each

### TanStack Query — For All Server Data

```ts
// Any data that comes from a server belongs in TanStack Query
const { data: invoices, isLoading } = useQuery({
  queryKey: ['invoices', userId],
  queryFn: () => fetchInvoices(userId),
  staleTime: 60_000,  // 1 minute cache
})

// Mutations with automatic cache invalidation
const mutation = useMutation({
  mutationFn: createInvoice,
  onSuccess: () => queryClient.invalidateQueries({ queryKey: ['invoices'] }),
})
```

Don't store server data in Zustand or useState. TanStack Query gives you: caching, background refetch, loading/error states, deduplication, and cache invalidation for free.

### Zustand — Only for Global UI State

```ts
// Sidebar open/close, active modal, theme, global toast queue
const useUIStore = create<UIState>((set) => ({
  sidebarOpen: false,
  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
  activeModal: null,
  openModal: (id) => set({ activeModal: id }),
  closeModal: () => set({ activeModal: null }),
}))
```

Don't put user data or API responses in Zustand. If the data would become stale, it belongs in TanStack Query.

### URL State — For Shareable Filter/Search State

```ts
// All state that should survive a page refresh or be shareable via URL
const searchParams = useSearchParams()
const router = useRouter()

const setFilter = (key: string, value: string) => {
  const params = new URLSearchParams(searchParams.toString())
  params.set(key, value)
  router.push(`?${params.toString()}`, { scroll: false })
}
```

Never put filter state in useState when users should be able to bookmark or share their filtered view.

### React Context — Only for True Shared State Without Cross-Component Subscriptions

Context is appropriate when:
- A provider wraps a subtree and every consumer needs the same value
- Rerenders from context change are acceptable (full subtree rerenders)
- Auth context, theme context, locale context

Context is NOT appropriate when:
- Different components need different slices (use Zustand instead — it has selectors)
- Updates are frequent (every rerender propagates to all consumers)
- You're doing prop drilling to avoid writing 2 more lines of prop passing

### Component State — Default Starting Point

```ts
// Start here. Lift when you need to share.
const [isOpen, setIsOpen] = useState(false)
```

Before reaching for global state, ask: "Do I actually need this from somewhere else?" If no, `useState` is correct.

## Anti-Pattern: Server State in Zustand

```ts
// WRONG — server data in Zustand
const useOrderStore = create((set) => ({
  orders: [],
  loading: false,
  fetchOrders: async () => {
    set({ loading: true })
    const orders = await getOrders()
    set({ orders, loading: false })
  },
}))

// CORRECT — server data in TanStack Query
function useOrders() {
  return useQuery({ queryKey: ['orders'], queryFn: getOrders })
}
```

Building a data store in Zustand means rebuilding what TanStack Query gives you: loading states, error states, background refetch, deduplication, stale-while-revalidate. Use TanStack Query.

## When to Use Context vs. Zustand

Use Context when the value is mostly read, rarely changes, and all consumers need the full value (theme, locale, auth user).

Use Zustand when:
- State is updated frequently
- Different components need different slices (Zustand's selector system prevents unnecessary renders)
- State spans many levels of the tree

Zustand's selector: `const sidebar = useUIStore(state => state.sidebarOpen)` — only rerenders when `sidebarOpen` changes, not when any other store value changes.
