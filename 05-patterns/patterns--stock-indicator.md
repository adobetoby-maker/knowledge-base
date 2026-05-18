# Pattern: Stock/Availability Indicator

## Overview

Stock indicators communicate product availability status: in stock, low stock, out of stock, pre-order, back-order. The key decisions: threshold for "low stock" warning, whether to show exact quantity, and how to handle the edge case between "add to cart" state and actual inventory.

## Availability Status Type

```ts
type StockStatus = 'in_stock' | 'low_stock' | 'out_of_stock' | 'pre_order' | 'back_order'

interface StockInfo {
  status: StockStatus
  quantity?: number  // Only show if policy allows (some brands hide exact qty)
  expectedDate?: Date  // For pre_order and back_order
}

function getStockStatus(quantity: number, lowThreshold = 5): StockStatus {
  if (quantity <= 0) return 'out_of_stock'
  if (quantity <= lowThreshold) return 'low_stock'
  return 'in_stock'
}
```

## Stock Indicator Component

```tsx
const STATUS_CONFIG = {
  in_stock: {
    dot: 'bg-green-500',
    text: 'In stock',
    textColor: 'text-green-700',
  },
  low_stock: {
    dot: 'bg-amber-500',
    text: 'Low stock',
    textColor: 'text-amber-700',
  },
  out_of_stock: {
    dot: 'bg-red-500',
    text: 'Out of stock',
    textColor: 'text-red-700',
  },
  pre_order: {
    dot: 'bg-blue-500',
    text: 'Pre-order',
    textColor: 'text-blue-700',
  },
  back_order: {
    dot: 'bg-purple-500',
    text: 'Back-order',
    textColor: 'text-purple-700',
  },
} satisfies Record<StockStatus, { dot: string; text: string; textColor: string }>

interface StockIndicatorProps {
  status: StockStatus
  quantity?: number
  expectedDate?: Date
  showQuantity?: boolean
}

export function StockIndicator({ status, quantity, expectedDate, showQuantity = false }: StockIndicatorProps) {
  const config = STATUS_CONFIG[status]

  const label = (() => {
    if (status === 'low_stock' && showQuantity && quantity !== undefined) {
      return `Only ${quantity} left`
    }
    if ((status === 'pre_order' || status === 'back_order') && expectedDate) {
      return `${config.text} — ships ${formatDate(expectedDate)}`
    }
    return config.text
  })()

  return (
    <div className="flex items-center gap-1.5">
      <span className={`w-2 h-2 rounded-full ${config.dot} flex-shrink-0`} />
      <span className={`text-sm font-medium ${config.textColor}`}>{label}</span>
    </div>
  )
}
```

## Add to Cart Button State

```tsx
function AddToCartButton({ status, onAddToCart }: { status: StockStatus; onAddToCart: () => void }) {
  const disabled = status === 'out_of_stock'

  const labels: Record<StockStatus, string> = {
    in_stock: 'Add to cart',
    low_stock: 'Add to cart',
    out_of_stock: 'Out of stock',
    pre_order: 'Pre-order now',
    back_order: 'Order now — ships later',
  }

  return (
    <button
      onClick={disabled ? undefined : onAddToCart}
      disabled={disabled}
      className={`w-full py-3 px-6 rounded-lg font-medium transition-colors ${
        disabled
          ? 'bg-gray-200 text-gray-500 cursor-not-allowed'
          : 'bg-blue-600 text-white hover:bg-blue-700'
      }`}
    >
      {labels[status]}
    </button>
  )
}
```

## Notify When Back in Stock

```tsx
function OutOfStockNotify({ productId }: { productId: string }) {
  const [email, setEmail] = useState('')
  const [subscribed, setSubscribed] = useState(false)

  async function subscribe(e: React.FormEvent) {
    e.preventDefault()
    await fetch('/api/stock-notify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ productId, email }),
    })
    setSubscribed(true)
  }

  if (subscribed) {
    return <p className="text-sm text-green-600">We'll email you when it's back in stock.</p>
  }

  return (
    <form onSubmit={subscribe} className="flex gap-2">
      <input
        type="email"
        value={email}
        onChange={e => setEmail(e.target.value)}
        placeholder="Your email"
        required
        className="input flex-1 text-sm"
      />
      <button type="submit" className="btn-secondary text-sm">Notify me</button>
    </form>
  )
}
```

## Real-Time Stock Updates

```tsx
// Subscribe to stock changes for current product
function useRealtimeStock(productId: string, initialStock: StockInfo): StockInfo {
  const [stock, setStock] = useState(initialStock)

  useEffect(() => {
    const channel = supabase
      .channel(`stock:${productId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'products',
        filter: `id=eq.${productId}`,
      }, (payload) => {
        const qty = payload.new.inventory_count as number
        setStock({
          status: getStockStatus(qty),
          quantity: qty,
        })
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [productId])

  return stock
}
```

## Key Rules

- Don't show exact quantities unless it's strategic ("Only 3 left") — exact numbers invite gaming (adding to cart to hold stock).
- "Low stock" threshold should be configurable per product category — high-demand items may show "low" at 50; niche items at 3.
- Pre-order and back-order always need an expected ship date — without a date, they read as "indefinitely unavailable."
- Out-of-stock items should show the "Notify me" form rather than a dead-end — it captures demand and reduces bounce.
- Add-to-cart button text should match the status: "Pre-order now" not "Add to cart" for pre-order items.
