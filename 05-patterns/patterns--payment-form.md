# Pattern: Payment Form

## Overview

Payment forms should never touch raw card data — use Stripe Elements or Stripe Payment Element to handle card input entirely in Stripe's iframe. The integration pattern is: client creates a PaymentIntent, Stripe Element collects card, client confirms — server only handles the metadata.

## Stripe Payment Element Setup

```tsx
import { Elements, PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js'
import { loadStripe } from '@stripe/stripe-js'

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)

export function CheckoutPage({ amount, orderId }: { amount: number; orderId: string }) {
  const [clientSecret, setClientSecret] = useState('')

  useEffect(() => {
    // Create PaymentIntent server-side, get clientSecret
    fetch('/api/create-payment-intent', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount, orderId }),
    })
      .then(r => r.json())
      .then(data => setClientSecret(data.clientSecret))
  }, [amount, orderId])

  if (!clientSecret) return <Spinner />

  return (
    <Elements stripe={stripePromise} options={{ clientSecret, appearance: { theme: 'stripe' } }}>
      <PaymentForm />
    </Elements>
  )
}
```

## Payment Form

```tsx
function PaymentForm() {
  const stripe = useStripe()
  const elements = useElements()
  const [error, setError] = useState('')
  const [processing, setProcessing] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!stripe || !elements) return

    setProcessing(true)
    setError('')

    const { error: stripeError } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/order/success`,
      },
    })

    if (stripeError) {
      // Only reached if redirect failed (e.g., 3DS cancelled)
      setError(stripeError.message ?? 'Payment failed')
      setProcessing(false)
    }
    // On success, Stripe redirects to return_url
  }

  return (
    <form onSubmit={handleSubmit}>
      <PaymentElement />
      {error && <p role="alert" className="text-red-600 text-sm mt-2">{error}</p>}
      <button type="submit" disabled={!stripe || processing}>
        {processing ? 'Processing…' : 'Pay now'}
      </button>
    </form>
  )
}
```

## Server: Create PaymentIntent

```ts
// app/api/create-payment-intent/route.ts
import Stripe from 'stripe'
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export async function POST(req: Request) {
  const { amount, orderId } = await req.json()
  const user = await getServerUser()
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 })

  // Fetch amount from DB — never trust client-provided amount
  const order = await db.query.orders.findFirst({
    where: and(eq(orders.id, orderId), eq(orders.userId, user.id)),
  })
  if (!order) return Response.json({ error: 'Order not found' }, { status: 404 })

  const paymentIntent = await stripe.paymentIntents.create({
    amount: order.totalCents,  // amount from DB, not request body
    currency: 'usd',
    metadata: { orderId, userId: user.id },
  })

  return Response.json({ clientSecret: paymentIntent.client_secret })
}
```

## Webhook Handler

```ts
// app/api/webhooks/stripe/route.ts
export async function POST(req: Request) {
  const body = await req.text()
  const sig = req.headers.get('stripe-signature')!

  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET!)
  } catch {
    return Response.json({ error: 'Invalid signature' }, { status: 400 })
  }

  if (event.type === 'payment_intent.succeeded') {
    const intent = event.data.object as Stripe.PaymentIntent
    await db.update(orders)
      .set({ status: 'paid', paidAt: new Date() })
      .where(eq(orders.id, intent.metadata.orderId))
  }

  return Response.json({ received: true })
}
```

## Key Rules

- Never pass `amount` from the client to the PaymentIntent — fetch it from the database server-side using `orderId`. A malicious client can modify the amount.
- Use webhooks as the source of truth for payment status — the redirect `return_url` can be manipulated or never hit.
- `constructEvent` with the raw body (text, not parsed JSON) — Stripe signature verification fails on parsed/re-serialized JSON.
- The PaymentElement handles card, Apple Pay, Google Pay, and SEPA automatically — don't use CardElement unless you need the minimal UI.
- 3DS redirects happen inside Stripe — `confirmPayment` only resolves with an error if 3DS was cancelled.
