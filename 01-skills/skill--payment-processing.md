# Payment Processing with Stripe

## Where It's Used

`silver-creek-logistics` and potentially `jrs-auto-repair` for online invoice payments.

## Architecture

```
Client → Stripe Elements (hosted card form) → Stripe servers
Browser never touches card data — PCI compliance handled by Stripe

Flow:
1. Server: create PaymentIntent → returns clientSecret
2. Client: Stripe Elements collects card info using clientSecret
3. Client: stripe.confirmPayment() → Stripe processes
4. Client: receives redirect with payment_intent status
5. Server: webhook confirms payment_intent.succeeded → mark invoice paid
```

## Setup

```bash
npm install @stripe/stripe-js @stripe/react-stripe-js stripe
```

## Server: Create PaymentIntent

```typescript
// app/api/payments/create-intent/route.ts
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export async function POST(req: NextRequest) {
  const isAdmin = await validateAdminSession(req)
  if (!isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  
  const { invoiceId } = await req.json()
  
  const supabase = createAdminClient()
  const { data: invoice } = await supabase
    .from('invoices')
    .select('total, number, customer_name')
    .eq('id', invoiceId)
    .single()
  
  if (!invoice) return NextResponse.json({ error: 'Invoice not found' }, { status: 404 })
  
  const paymentIntent = await stripe.paymentIntents.create({
    amount: Math.round(invoice.total * 100),  // Stripe uses cents
    currency: 'usd',
    metadata: {
      invoiceId,
      invoiceNumber: invoice.number,
    },
  })
  
  return NextResponse.json({ clientSecret: paymentIntent.client_secret })
}
```

## Client: Stripe Elements

```typescript
'use client'
import { loadStripe } from '@stripe/stripe-js'
import { Elements, PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js'
import { useState } from 'react'

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)

export function PaymentForm({ invoiceId }: { invoiceId: string }) {
  const [clientSecret, setClientSecret] = useState<string | null>(null)

  async function initPayment() {
    const res = await fetch('/api/payments/create-intent', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ invoiceId }),
    })
    const { clientSecret } = await res.json()
    setClientSecret(clientSecret)
  }

  if (!clientSecret) {
    return <button onClick={initPayment}>Pay Now</button>
  }

  return (
    <Elements stripe={stripePromise} options={{ clientSecret }}>
      <CheckoutForm invoiceId={invoiceId} />
    </Elements>
  )
}

function CheckoutForm({ invoiceId }: { invoiceId: string }) {
  const stripe = useStripe()
  const elements = useElements()
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!stripe || !elements) return

    setLoading(true)
    const { error } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/portal/invoices/${invoiceId}/payment-success`,
      },
    })

    if (error) {
      setError(error.message ?? 'Payment failed')
      setLoading(false)
    }
    // On success, Stripe redirects to return_url
  }

  return (
    <form onSubmit={handleSubmit}>
      <PaymentElement />
      {error && <p className="text-red-500 text-sm mt-2">{error}</p>}
      <button type="submit" disabled={loading || !stripe}>
        {loading ? 'Processing...' : 'Pay Now'}
      </button>
    </form>
  )
}
```

## Webhook: Confirm Payment Server-Side

NEVER mark an invoice paid based on the client redirect — the client can be manipulated. Always confirm via webhook:

```typescript
// app/api/webhooks/stripe/route.ts
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!

export async function POST(req: NextRequest) {
  const body = await req.text()  // MUST use text(), not json()
  const sig = req.headers.get('stripe-signature')!
  
  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, sig, webhookSecret)
  } catch {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 })
  }
  
  if (event.type === 'payment_intent.succeeded') {
    const intent = event.data.object as Stripe.PaymentIntent
    const invoiceId = intent.metadata.invoiceId
    
    const supabase = createAdminClient()
    await supabase
      .from('invoices')
      .update({ status: 'paid', paid_at: new Date().toISOString() })
      .eq('id', invoiceId)
  }
  
  return NextResponse.json({ received: true })
}
```

## Test Cards

| Card Number | Result |
|---|---|
| 4242 4242 4242 4242 | Success |
| 4000 0000 0000 0002 | Card declined |
| 4000 0025 0000 3155 | 3D Secure required |

Use any future expiry (12/34), any 3-digit CVV, any ZIP.

## Env Vars

```
STRIPE_SECRET_KEY              # sk_test_... or sk_live_...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY  # pk_test_... or pk_live_...
STRIPE_WEBHOOK_SECRET          # whsec_... (from Stripe webhook settings)
```
