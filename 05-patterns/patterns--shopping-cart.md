# Shopping Cart — State and UI

## Storage Strategy

Cart lives in two places simultaneously: `localStorage` for guests, server for authenticated users. The sync rules are:

- **Guest:** write every mutation to `localStorage` only. On login, merge guest cart into server cart — item quantities add, don't replace.
- **Logged in:** optimistic write to `localStorage` immediately, then fire a server mutation. If the server rejects (e.g. item out of stock), roll back local state and show toast.
- **Hydration mismatch:** on first render, read `localStorage` synchronously in `useLayoutEffect` not `useEffect` — avoids a flash of empty cart.

```ts
// cartStore.ts — Zustand with persistence
export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      items: [],
      addItem: (product, qty = 1) => {
        const existing = get().items.find(i => i.id === product.id)
        if (existing) {
          set(s => ({ items: s.items.map(i =>
            i.id === product.id ? { ...i, qty: i.qty + qty } : i
          )}))
        } else {
          set(s => ({ items: [...s.items, { ...product, qty }] }))
        }
        if (isLoggedIn()) syncToServer(get().items)
      },
      removeItem: (id) => set(s => ({ items: s.items.filter(i => i.id !== id) })),
    }),
    { name: 'cart-store' }
  )
)
```

## Quantity Stepper

Inline +/− within the cart row. The decrement button is `disabled` when `qty === 1` (not `qty === 0` — removing is a separate explicit action). Removing at quantity 1 requires the trash icon, not a further decrement — prevents accidental removals.

```tsx
<button
  onClick={() => updateQty(item.id, item.qty - 1)}
  disabled={item.qty <= 1}
  aria-label="Decrease quantity"
>−</button>
<span aria-live="polite">{item.qty}</span>
<button
  onClick={() => updateQty(item.id, item.qty + 1)}
  disabled={item.qty >= item.maxQty}
  aria-label="Increase quantity"
>+</button>
```

## Remove with Undo

Don't `window.confirm` — it blocks the thread and feels archaic. Instead, remove optimistically and show a toast with an undo action for ~5 seconds. Store the removed item in a ref; if undo fires, re-insert at its original index.

```ts
const removedRef = useRef<{ item: CartItem; index: number } | null>(null)

const handleRemove = (id: string) => {
  const idx = items.findIndex(i => i.id === id)
  removedRef.current = { item: items[idx], index: idx }
  removeItem(id)
  toast('Item removed', {
    action: { label: 'Undo', onClick: () => restoreItem(removedRef.current!) }
  })
}
```

## Cart Count Badge

Derive count from store, not a separate piece of state — they can't desync.

```tsx
const count = useCartStore(s => s.items.reduce((n, i) => n + i.qty, 0))
// Show nothing at 0, not "0"
{count > 0 && <span className="badge">{count > 99 ? '99+' : count}</span>}
```

## Drawer vs Page

Use a **drawer** for impulse/quick-add flows (e.g., product listing page). Use a **full cart page** for the final review before checkout. Never put checkout inside the drawer — the cognitive load of a multi-step flow in a slide-over panel is too high. The drawer should only show items, totals, and a "View cart / Checkout" CTA that navigates to the full page.

## Key Rules

- Merge guest cart into user cart on login — never silently discard it.
- Decrement disables at `qty === 1`; removal is always intentional via trash icon.
- Remove optimistically with 5-second undo toast, not a confirm dialog.
- Badge shows nothing at zero, clips at `99+`.
- Drawer for quick review; full page for checkout — never nest checkout in drawer.
- Sync to server on every mutation for logged-in users; roll back on failure.
