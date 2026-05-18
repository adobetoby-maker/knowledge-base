# Pattern: Credit Card Input

## Overview

Never collect raw card data yourself. Use Stripe Elements or similar PCI-compliant hosted inputs. This pattern covers the Stripe Elements integration — attempting to build raw card input yourself requires PCI DSS SAQ D compliance, which is impractical for most applications.

## Why Hosted Fields

When Stripe Elements renders in an iframe, card data never touches your server. Your PCI scope drops to SAQ A — the simplest tier. Building your own card fields means card data passes through your servers, requiring full PCI DSS audit.

## Stripe Elements (React)

```tsx
import { loadStripe } from '@stripe/stripe-js'
import {
  Elements,
  PaymentElement,
  useStripe,
  useElements,
} from '@stripe/react-stripe-js'

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)

export function CheckoutPage({ clientSecret }: { clientSecret: string }) {
  return (
    <Elements stripe={stripePromise} options={{ clientSecret }}>
      <CheckoutForm />
    </Elements>
  )
}

function CheckoutForm() {
  const stripe = useStripe()
  const elements = useElements()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!stripe || !elements) return

    setLoading(true)
    setError(null)

    const { error } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/checkout/complete`,
      },
    })

    // Only reaches here on error (success redirects away)
    setError(error.message ?? 'Payment failed')
    setLoading(false)
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <PaymentElement />
      {error && <p className="text-sm text-red-600">{error}</p>}
      <button type="submit" disabled={!stripe || loading} className="btn-primary w-full">
        {loading ? 'Processing...' : 'Pay Now'}
      </button>
    </form>
  )
}
```

## Server Side: Create Payment Intent

```ts
// app/api/checkout/create-intent/route.ts
export async function POST(req: Request) {
  const { amount, currency = 'usd' } = await req.json()
  const user = await requireAuth()

  const intent = await stripe.paymentIntents.create({
    amount,           // in cents
    currency,
    customer: user.stripeCustomerId ?? undefined,
    automatic_payment_methods: { enabled: true },
    metadata: { userId: user.id },
  })

  return Response.json({ clientSecret: intent.client_secret })
}
```

## Card Logos and Detecting Brand

```tsx
// Stripe sends card brand events
elements?.getElement('cardNumber')?.on('change', (event) => {
  setBrand(event.brand)  // 'visa', 'mastercard', 'amex', 'unknown'
})
```

Or use the payment method attached to a customer to display saved card brand.

## Saved Cards (SetupIntent)

For saving a card for future use without charging:

```ts
const setupIntent = await stripe.setupIntents.create({
  customer: stripeCustomerId,
  payment_method_types: ['card'],
})
// Return setupIntent.client_secret to frontend
// Frontend uses stripe.confirmCardSetup(clientSecret, { payment_method: ... })
```

## Key Rules

- Never log, store, or transmit raw card numbers — treat them as toxic data.
- `clientSecret` from a PaymentIntent contains no sensitive data itself — safe to pass to frontend.
- Always check that the payment intent's `customer` and `amount` match your expected order before confirming — prevent tampering.
- Test with Stripe test cards: `4242 4242 4242 4242` (success), `4000 0000 0000 9995` (declined).
