# Pattern: Split Form Layout (Form + Summary Panel)

## Overview
Checkout and order forms benefit from a persistent order summary visible while the user fills in their details — it eliminates the need to scroll down to see what they're buying. Without it, users abandon because they lose context. Placing the primary action button only at the bottom of a long form means users scroll past the summary to click "Place Order" — the sticky summary should contain the CTA.

## Implementation

```tsx
// CheckoutLayout.tsx — content left, sticky summary right
export function CheckoutLayout({
  form,
  summary,
}: {
  form: React.ReactNode
  summary: React.ReactNode
}) {
  return (
    <div className="checkout-layout">
      {/* Left: scrollable form */}
      <div className="checkout-form">
        {form}
      </div>

      {/* Right: sticky summary — stays fixed as form scrolls */}
      <aside className="checkout-summary" aria-label="Order summary">
        {summary}
      </aside>
    </div>
  )
}
```

```css
.checkout-layout {
  display: grid;
  /* Form takes 60%, summary takes 40% */
  grid-template-columns: 3fr 2fr;
  gap: 48px;
  align-items: start;
  max-width: 1100px;
  margin: 0 auto;
  padding: 32px 24px;
}

.checkout-form {
  /* Form scrolls naturally with the page */
}

.checkout-summary {
  /* Sticks to viewport top as user scrolls through form */
  position: sticky;
  top: 24px;
  /* Cap height in case summary is very long */
  max-height: calc(100vh - 48px);
  overflow-y: auto;
}

/* Mobile: summary below form (never hidden behind form on small screens) */
@media (max-width: 768px) {
  .checkout-layout {
    grid-template-columns: 1fr;
  }

  .checkout-summary {
    /* On mobile: summary comes after form in DOM, appears below */
    position: static;  /* not sticky on mobile */
    order: 2;
  }

  .checkout-form {
    order: 1;
  }
}
```

```tsx
// OrderSummary.tsx — real-time total update as user changes form values
import { useFormContext, useWatch } from 'react-hook-form'
import { formatCurrency } from '@/lib/currency'

interface OrderSummaryProps {
  items: CartItem[]
  onSubmit: () => void
  isSubmitting: boolean
}

export function OrderSummary({ items, onSubmit, isSubmitting }: OrderSummaryProps) {
  // Watch live values from the form — total updates as user types
  const shippingMethod = useWatch({ name: 'shippingMethod' })
  const promoCode = useWatch({ name: 'promoCode' })

  const subtotal = items.reduce((sum, item) => sum + item.price * item.quantity, 0)
  const shipping = getShippingCost(shippingMethod) // cents
  const discount = promoCode ? getDiscount(promoCode, subtotal) : 0
  const total = subtotal + shipping - discount

  return (
    <div className="order-summary-card">
      <h2>Order Summary</h2>

      {/* Line items */}
      <ul>
        {items.map(item => (
          <li key={item.id} style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span>{item.name} × {item.quantity}</span>
            <span>{formatCurrency(item.price * item.quantity)}</span>
          </li>
        ))}
      </ul>

      <hr />

      {/* Totals — update in real-time as form changes */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        <TotalRow label="Subtotal"  value={subtotal} />
        <TotalRow label="Shipping"  value={shipping} />
        {discount > 0 && <TotalRow label="Discount" value={-discount} />}
        <TotalRow label="Total"     value={total} bold />
      </div>

      {/* CTA lives in the summary, not at the bottom of the form */}
      {/* This is reachable without scrolling past all the form fields */}
      <button
        onClick={onSubmit}
        disabled={isSubmitting}
        style={{ width: '100%', marginTop: 24 }}
      >
        {isSubmitting ? 'Placing order…' : `Place Order — ${formatCurrency(total)}`}
      </button>

      {/* Trust signals near the CTA */}
      <p style={{ fontSize: 12, textAlign: 'center', marginTop: 8, color: '#666' }}>
        🔒 Secured with 256-bit encryption
      </p>
    </div>
  )
}

function TotalRow({ label, value, bold }: { label: string; value: number; bold?: boolean }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: bold ? 700 : 400 }}>
      <span>{label}</span>
      <span>{formatCurrency(value)}</span>
    </div>
  )
}
```

```tsx
// Checkout page — wiring it together with react-hook-form
export function CheckoutPage({ cart }: { cart: Cart }) {
  const methods = useForm<CheckoutFormValues>()

  async function onSubmit(data: CheckoutFormValues) {
    await createOrder(data, cart)
  }

  return (
    <FormProvider {...methods}>
      <CheckoutLayout
        form={
          <form onSubmit={methods.handleSubmit(onSubmit)} id="checkout-form">
            <ShippingSection />
            <PaymentSection />
          </form>
        }
        summary={
          <OrderSummary
            items={cart.items}
            // The summary button submits the form by ID
            onSubmit={() => document.getElementById('checkout-form')?.requestSubmit()}
            isSubmitting={methods.formState.isSubmitting}
          />
        }
      />
    </FormProvider>
  )
}
```

## Key Rules
- The sticky summary stays visible while the user scrolls through form fields — they always know what they're paying for.
- Place the primary CTA ("Place Order") inside the sticky summary, not only at the bottom of the form.
- Show total in the button label: "Place Order — $49.99" removes uncertainty at click time.
- Update totals in real-time as the user changes shipping method, applies promo codes, etc. — use `useWatch` or equivalent.
- On mobile (<768px), summary appears below the form in DOM order — never overlay or hide it on small screens.
- `position: sticky; top: 24px` on the summary panel — it follows the user's scroll without re-rendering.
- Set `max-height` with `overflow-y: auto` on the summary to handle very long item lists without covering the page.
- Trust signals (security icons, guarantees) belong near the CTA button, not at the page footer.
- Use `grid-template-columns: 3fr 2fr` — the form deserves more width than the summary.
