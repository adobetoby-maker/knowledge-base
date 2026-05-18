# Plugin: Stripe React (Stripe.js + React)

## Overview
Stripe's client-side JavaScript handles PCI compliance by collecting card data directly in Stripe-hosted iframes — your server never touches raw card numbers. The React wrapper provides hooks and components that integrate with that iframe architecture. Getting the provider/hook pattern wrong (e.g., calling `useStripe` outside `Elements`) results in silent null refs, not helpful errors.

## Implementation

### Provider Setup
```tsx
import { loadStripe } from '@stripe/stripe-js';
import { Elements } from '@stripe/react-stripe-js';

// Load outside component to avoid re-initialization on re-renders
const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!);

export function CheckoutProvider({ clientSecret, children }: Props) {
  const appearance = {
    theme: 'stripe' as const,
    variables: {
      colorPrimary: '#6366f1',
      colorBackground: '#ffffff',
      fontFamily: 'Inter, sans-serif',
    },
  };

  return (
    <Elements stripe={stripePromise} options={{ clientSecret, appearance }}>
      {children}
    </Elements>
  );
}
```

### Payment Form
```tsx
import { PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js';

export function PaymentForm() {
  const stripe = useStripe();
  const elements = useElements();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!stripe || !elements) return; // Stripe.js not loaded yet

    setLoading(true);

    const { error } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/payment/success`,
      },
    });

    // Only reached if confirmPayment fails immediately (redirect didn't happen)
    if (error) {
      setError(error.message ?? 'Payment failed');
    }
    setLoading(false);
  };

  return (
    <form onSubmit={handleSubmit}>
      <PaymentElement />
      {error && <p className="text-red-500">{error}</p>}
      <button disabled={!stripe || loading}>
        {loading ? 'Processing...' : 'Pay Now'}
      </button>
    </form>
  );
}
```

### Server: Create PaymentIntent
```ts
// Route handler — never in client code
import Stripe from 'stripe';
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function POST(req: Request) {
  const { amount, currency = 'usd' } = await req.json();

  const paymentIntent = await stripe.paymentIntents.create({
    amount, // in cents
    currency,
    automatic_payment_methods: { enabled: true },
  });

  return Response.json({ clientSecret: paymentIntent.client_secret });
}
```

### 3DS Redirect Handling
```tsx
// On the return_url page, confirm the outcome
import { useStripe } from '@stripe/react-stripe-js';

export function PaymentResult() {
  const stripe = useStripe();

  useEffect(() => {
    if (!stripe) return;
    const clientSecret = new URLSearchParams(window.location.search).get(
      'payment_intent_client_secret'
    );
    if (!clientSecret) return;

    stripe.retrievePaymentIntent(clientSecret).then(({ paymentIntent }) => {
      switch (paymentIntent?.status) {
        case 'succeeded': /* show success */ break;
        case 'processing': /* show pending */ break;
        case 'requires_payment_method': /* retry */ break;
      }
    });
  }, [stripe]);
}
```

## Key Rules
- `loadStripe()` must be called outside any component to avoid creating multiple Stripe instances
- Use `PaymentElement` (not `CardElement`) — it handles all payment methods (cards, wallets, BNPL) automatically based on currency and region
- `useStripe()` and `useElements()` return `null` until Stripe.js loads; always null-check before calling methods
- `stripe.confirmPayment()` redirects the user for 3DS/bank redirects — code after it only runs on immediate failures
- `clientSecret` comes from your server's PaymentIntent creation; never expose `STRIPE_SECRET_KEY` client-side
- The `return_url` must be an absolute URL; Stripe appends query params for result retrieval
- Pass `appearance` options to `Elements`, not to individual components — it applies to all Stripe-hosted iframes
- Webhook verification (`stripe.webhooks.constructEvent`) requires the raw request body, not parsed JSON
