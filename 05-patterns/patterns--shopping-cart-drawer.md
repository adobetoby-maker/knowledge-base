# Pattern: Slide-Out Cart Drawer

## Overview

The cart drawer slides in from the right (or bottom on mobile) without navigating away from the product page. It must handle: focus management (trap focus inside when open), quantity updates, remove, subtotal, and empty state. Use a real dialog/drawer primitive — not a `position: fixed` div — so that screen readers and keyboard users get the correct semantics.

## Using Vaul for the Drawer Shell

Vaul (`vaul`) is purpose-built for this. It handles the slide animation, focus trap, scroll lock, and dismiss-on-backdrop-click:

```tsx
import { Drawer } from 'vaul'

function CartDrawer({ open, onClose }: { open: boolean; onClose: () => void }) {
  return (
    <Drawer.Root open={open} onOpenChange={(v) => !v && onClose()}>
      <Drawer.Portal>
        <Drawer.Overlay className="fixed inset-0 bg-black/40 z-40" />
        <Drawer.Content
          className="fixed right-0 top-0 h-full w-full max-w-sm bg-white z-50 flex flex-col shadow-xl"
          aria-label="Shopping cart"
        >
          <CartDrawerInner onClose={onClose} />
        </Drawer.Content>
      </Drawer.Portal>
    </Drawer.Root>
  )
}
```

If not using Vaul, use `<dialog>` with `showModal()` / `close()` — it provides a native focus trap and `Escape` dismiss for free.

## Cart State

Keep cart state in a context or global store. The drawer reads from it; product pages write to it.

```ts
interface CartItem {
  id: string
  name: string
  price: number       // in cents
  quantity: number
  imageUrl: string
  maxQuantity?: number
}

interface CartStore {
  items: CartItem[]
  addItem: (item: Omit<CartItem, 'quantity'>) => void
  updateQuantity: (id: string, quantity: number) => void
  removeItem: (id: string) => void
  subtotal: number    // derived: sum of price * quantity
}
```

Derive `subtotal` from items on every render — don't store it as separate state that can drift out of sync.

## Cart Drawer Inner Content

```tsx
function CartDrawerInner({ onClose }: { onClose: () => void }) {
  const { items, updateQuantity, removeItem, subtotal } = useCartStore()

  return (
    <>
      <header className="flex items-center justify-between px-4 py-3 border-b">
        <h2 className="font-semibold text-lg">Cart ({items.length})</h2>
        <button type="button" onClick={onClose} aria-label="Close cart">
          <XIcon />
        </button>
      </header>

      <div className="flex-1 overflow-y-auto">
        {items.length === 0 ? (
          <EmptyCartState onClose={onClose} />
        ) : (
          <ul className="divide-y">
            {items.map((item) => (
              <CartLineItem
                key={item.id}
                item={item}
                onQuantityChange={(qty) => updateQuantity(item.id, qty)}
                onRemove={() => removeItem(item.id)}
              />
            ))}
          </ul>
        )}
      </div>

      {items.length > 0 && (
        <footer className="border-t px-4 py-4 space-y-3">
          <div className="flex justify-between text-sm">
            <span>Subtotal</span>
            <span>{formatCurrency(subtotal)}</span>
          </div>
          <p className="text-xs text-gray-500">Shipping and taxes calculated at checkout</p>
          <a href="/checkout" className="block w-full bg-black text-white text-center py-3 rounded-lg font-medium">
            Checkout
          </a>
        </footer>
      )}
    </>
  )
}
```

## Cart Line Item with Quantity Update

```tsx
function CartLineItem({ item, onQuantityChange, onRemove }: {
  item: CartItem
  onQuantityChange: (qty: number) => void
  onRemove: () => void
}) {
  return (
    <li className="flex gap-3 px-4 py-3">
      <img src={item.imageUrl} alt={item.name} className="w-16 h-16 object-cover rounded" />
      <div className="flex-1 min-w-0">
        <p className="font-medium truncate">{item.name}</p>
        <p className="text-sm text-gray-600">{formatCurrency(item.price)}</p>
        <div className="flex items-center gap-2 mt-1">
          <button
            type="button"
            onClick={() => item.quantity > 1 ? onQuantityChange(item.quantity - 1) : onRemove()}
            aria-label={`Decrease quantity of ${item.name}`}
          >−</button>
          <span aria-label={`Quantity: ${item.quantity}`}>{item.quantity}</span>
          <button
            type="button"
            onClick={() => onQuantityChange(item.quantity + 1)}
            disabled={item.maxQuantity !== undefined && item.quantity >= item.maxQuantity}
            aria-label={`Increase quantity of ${item.name}`}
          >+</button>
        </div>
      </div>
      <button type="button" onClick={onRemove} aria-label={`Remove ${item.name} from cart`}>
        <TrashIcon />
      </button>
    </li>
  )
}
```

## Empty State

The empty state should encourage continuation, not just say "cart is empty":

```tsx
function EmptyCartState({ onClose }: { onClose: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center h-full gap-4 text-center px-8">
      <ShoppingBagIcon className="w-16 h-16 text-gray-200" />
      <h3 className="font-medium">Your cart is empty</h3>
      <p className="text-sm text-gray-500">Add items to get started</p>
      <button type="button" onClick={onClose} className="underline text-sm">
        Continue shopping
      </button>
    </div>
  )
}
```

## Key Rules

- Use Vaul or a native `<dialog>` for the drawer shell — not `position: fixed` with manual focus management.
- Derive `subtotal` from items on render; never store it as separate state.
- Reduce to 0 should trigger remove, not leave a quantity-0 item in the list.
- All interactive elements need descriptive `aria-label` values including the item name.
- The checkout CTA should be a real `<a>` link, not a button, so it works correctly if JS is slow to hydrate.
- Scroll lock is handled by Vaul; if rolling your own, `document.body.style.overflow = 'hidden'` on open and restore on close.
