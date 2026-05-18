# Pattern: Multi-Step Checkout Form

A three-step checkout (Shipping → Payment → Review) where data persists across steps, errors recover gracefully, and the order summary stays visible throughout.

## Why Multi-Step

Splitting a ~15-field form into three steps reduces cognitive load and increases completion rates. Each step has a clear responsibility boundary, which also maps cleanly to validation domains — address validation, card validation, and final confirmation are distinct concerns with different APIs and timing.

## Step State Architecture

Store the entire checkout in a single parent component or context. Never store step data inside individual step components — the back button would destroy it.

```tsx
type CheckoutState = {
  step: 'shipping' | 'payment' | 'review';
  shipping: ShippingData | null;
  payment: PaymentData | null;
};

function CheckoutPage() {
  const [state, setState] = useState<CheckoutState>({
    step: 'shipping',
    shipping: null,
    payment: null,
  });

  const goToPayment = (shipping: ShippingData) =>
    setState(s => ({ ...s, step: 'payment', shipping }));

  const goToReview = (payment: PaymentData) =>
    setState(s => ({ ...s, step: 'review', payment }));

  const goBack = () =>
    setState(s => ({
      ...s,
      step: s.step === 'review' ? 'payment' : 'shipping',
    }));
  // ...
}
```

## Address Validation

Validate addresses server-side before advancing. Client-side field validation (required, format) is instant feedback; address existence requires an API call.

```tsx
async function validateShipping(data: ShippingData) {
  // 1. Client format checks first (no network)
  const parsed = ShippingSchema.safeParse(data);
  if (!parsed.success) return { valid: false, errors: parsed.error.flatten() };

  // 2. USPS/SmartyStreets/Google Address Validation API
  const result = await verifyAddress(data);
  if (result.status === 'NOT_FOUND') {
    return { valid: false, errors: { address1: 'Address not found — check for typos' } };
  }
  if (result.status === 'CORRECTED') {
    // Offer correction without blocking
    return { valid: true, suggestion: result.correctedAddress };
  }
  return { valid: true };
}
```

Surface address suggestions as an inline prompt ("Did you mean 123 Main St?"), not a blocking error. Let the user override — real addresses sometimes fail third-party validators.

## Sticky Order Summary

The sidebar must stay visible while the user fills forms. On mobile, collapse it to a toggle.

```tsx
// Two-column layout: form (left) + sticky summary (right)
<div className="grid grid-cols-1 lg:grid-cols-[1fr_360px] gap-8">
  <div>{/* Step form */}</div>
  <aside className="lg:sticky lg:top-6 lg:self-start">
    <OrderSummary items={cart} shipping={state.shipping} />
  </aside>
</div>
```

`self-start` prevents the sticky sidebar from stretching to the form height. `top-6` clears the sticky header.

## Payment Error Recovery

Payment failures are the highest-stakes errors. Never clear form fields on a payment error — forcing users to re-enter card details destroys trust.

```tsx
const [paymentError, setPaymentError] = useState<string | null>(null);
const [isRetrying, setIsRetrying] = useState(false);

async function submitPayment(data: PaymentData) {
  setPaymentError(null);
  setIsRetrying(true);
  try {
    await processPayment(data);
    goToConfirmation();
  } catch (err) {
    if (err.code === 'card_declined') {
      setPaymentError('Your card was declined. Please try a different card or contact your bank.');
    } else if (err.code === 'insufficient_funds') {
      setPaymentError('Insufficient funds. Please try a different payment method.');
    } else {
      setPaymentError('Payment failed. Your card was not charged. Please try again.');
    }
    // Fields stay populated — user can retry without re-entering
  } finally {
    setIsRetrying(false);
  }
}
```

Always clarify "your card was not charged" on generic failures. Users will abandon rather than retry if they're unsure whether they were double-charged.

## Back Navigation Data Preservation

The back button should restore the previous step's form with the values already entered.

```tsx
// Pre-populate form with stored data
function PaymentStep({ onBack, defaultValues }: {
  onBack: () => void;
  defaultValues: PaymentData | null;
}) {
  const form = useForm<PaymentData>({
    defaultValues: defaultValues ?? {},
  });
  // Form renders with previously entered values restored
}
```

## Step Validation Gate

Only enable the "Continue" button when the current step is valid. Use `react-hook-form`'s `formState.isValid` with `mode: 'onChange'` so the button enables as soon as the form is complete.

```tsx
const form = useForm<ShippingData>({ mode: 'onChange' });
const { isValid, isSubmitting } = form.formState;

<Button type="submit" disabled={!isValid || isSubmitting}>
  {isSubmitting ? 'Verifying…' : 'Continue to Payment'}
</Button>
```

## Key Rules

- Store all step data in the parent — never in step-local state that gets destroyed on unmount
- Validate addresses with an API but offer corrections rather than hard blocks
- Never clear payment fields after a failure; always say "you were not charged"
- Sticky sidebar requires `self-start` — without it, `sticky` has no effect on a flex/grid child stretching to full height
- Pre-populate each step's form from saved state so back navigation is lossless
- Use `mode: 'onChange'` validation so the Continue button enables progressively as the user fills fields
