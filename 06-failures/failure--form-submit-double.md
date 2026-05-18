# Failure: Form Double-Submission

## Overview
Double-submission happens when a user clicks a submit button more than once before the first response arrives — or when a page refresh replays a POST request. Both produce duplicate records or duplicate charges. Frontend-only prevention (disabling the button) is necessary but insufficient — network delays, race conditions, or direct API calls can still bypass it. The backend must be idempotent.

## Implementation

### Frontend: disable on first click

```tsx
function CheckoutForm() {
  const [isSubmitting, setIsSubmitting] = useState(false)
  const { mutate } = useMutation({
    mutationFn: submitOrder,
    onSettled: () => setIsSubmitting(false),  // Re-enable after success OR error
  })

  async function handleSubmit(values: FormValues) {
    if (isSubmitting) return  // Guard against rapid re-click before state update
    setIsSubmitting(true)
    mutate(values)
  }

  return (
    <form onSubmit={form.handleSubmit(handleSubmit)}>
      {/* ...fields... */}
      <Button type="submit" disabled={isSubmitting}>
        {isSubmitting ? (
          <><Spinner className="mr-2" /> Processing…</>
        ) : (
          'Place order'
        )}
      </Button>
    </form>
  )
}
```

### Backend: idempotency key

```ts
// Client generates a unique key per submission attempt
function generateIdempotencyKey(): string {
  return crypto.randomUUID()
}

// Include it with every mutation request
async function submitOrder(values: OrderFormValues) {
  const idempotencyKey = generateIdempotencyKey()
  // Store in sessionStorage so page refresh re-uses same key
  const storageKey = `order_idem_${JSON.stringify(values)}`
  const existingKey = sessionStorage.getItem(storageKey)

  return fetch('/api/orders', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Idempotency-Key': existingKey ?? idempotencyKey,
    },
    body: JSON.stringify(values),
  })
}
```

### Server: idempotency check

```ts
// app/api/orders/route.ts
export async function POST(req: Request) {
  const idempotencyKey = req.headers.get('Idempotency-Key')

  if (idempotencyKey) {
    // Check if we already processed this key
    const existing = await redis.get(`idem:${idempotencyKey}`)
    if (existing) {
      // Return the same response as the original successful request
      return Response.json(JSON.parse(existing), { status: 200 })
    }
  }

  // Process the order
  const order = await createOrder(await req.json())

  // Store the result for this key (expire after 24h)
  if (idempotencyKey) {
    await redis.setex(`idem:${idempotencyKey}`, 86400, JSON.stringify(order))
  }

  return Response.json(order, { status: 201 })
}
```

### POST-Redirect-GET for HTML forms (prevents refresh re-submission)

```ts
// After successful form submission, redirect to a result page
// This means refreshing the result page won't re-submit the POST
export async function POST(req: Request) {
  const data = await req.formData()
  const result = await processForm(data)

  // Redirect to GET route — browser can safely refresh this
  return Response.redirect(`/orders/${result.id}/confirmation`, 303)
}
```

### Stripe Payments: always use idempotency keys

```ts
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

async function chargeCustomer(customerId: string, amount: number, orderId: string) {
  // orderId makes this idempotent — re-running with same orderId returns the same PaymentIntent
  return stripe.paymentIntents.create(
    { amount, currency: 'usd', customer: customerId },
    { idempotencyKey: `order_${orderId}` }
  )
}
```

## Key Rules
- Disabling the submit button is necessary but not sufficient — it can be bypassed
- The backend must be idempotent regardless of frontend protections
- Re-enable the button on error, not just on success — users need to be able to retry failed requests
- POST-Redirect-GET pattern prevents browser refresh from re-submitting the same POST body
- Idempotency keys should be request-scoped (new UUID per submit click), not session-scoped
- Stripe and other payment processors have built-in idempotency key support — always use it
- For payment flows, store the idempotency key before making the payment API call, not after
