# Skill: Multi-Step Checkout

## Overview
Multi-step checkout breaks a complex form into cognitive chunks — users complete smaller pieces rather than facing a wall of fields. URL updates per step enable deep-linking, browser back/forward, and shareable checkout links. Each step validates independently before advancing so users never lose work by hitting a final submit that fails on step 2 of 4.

## Implementation / Key Points

### Step Definitions
```ts
const STEPS = ['cart', 'shipping', 'payment', 'confirmation'] as const;
type CheckoutStep = typeof STEPS[number];

interface CheckoutState {
  step: CheckoutStep;
  cart: CartItem[];
  shipping: ShippingDetails | null;
  payment: PaymentDetails | null;
  orderId: string | null;
}
```

### URL Updates Per Step (No Page Reload)
```ts
// Next.js App Router
function useCheckoutStep() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const step = (searchParams.get('step') ?? 'cart') as CheckoutStep;

  function advance() {
    const nextIndex = STEPS.indexOf(step) + 1;
    if (nextIndex < STEPS.length) {
      router.push(`/checkout?step=${STEPS[nextIndex]}`, { scroll: false });
    }
  }

  function goBack() {
    const prevIndex = STEPS.indexOf(step) - 1;
    if (prevIndex >= 0) {
      router.push(`/checkout?step=${STEPS[prevIndex]}`, { scroll: false });
    }
  }

  return { step, advance, goBack };
}
```

### Step-Level Validation Before Advancing
```ts
async function validateShipping(data: ShippingDetails): Promise<ValidationResult> {
  const schema = z.object({
    name: z.string().min(2),
    address: z.string().min(5),
    city: z.string().min(2),
    postalCode: z.string().regex(/^\d{5}(-\d{4})?$/, 'Invalid ZIP'),
    country: z.string().length(2),
  });
  const result = schema.safeParse(data);
  return result.success ? { valid: true } : { valid: false, errors: result.error.flatten() };
}

// In step component:
async function handleShippingContinue(data: ShippingDetails) {
  const { valid, errors } = await validateShipping(data);
  if (!valid) { setErrors(errors); return; }
  saveToLocalStorage('checkout_shipping', data);
  advance();
}
```

### Save Partial Progress to localStorage
```ts
const STORAGE_KEY = 'checkout_draft';

function saveProgress(state: Partial<CheckoutState>) {
  const existing = loadProgress();
  localStorage.setItem(STORAGE_KEY, JSON.stringify({
    ...existing,
    ...state,
    savedAt: new Date().toISOString()
  }));
}

function loadProgress(): Partial<CheckoutState> | null {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return null;
  const parsed = JSON.parse(raw);
  // Expire after 24 hours
  if (Date.now() - new Date(parsed.savedAt).getTime() > 86_400_000) {
    localStorage.removeItem(STORAGE_KEY);
    return null;
  }
  return parsed;
}
```

### Progress Indicator
```tsx
function CheckoutProgress({ currentStep }: { currentStep: CheckoutStep }) {
  return (
    <nav aria-label="Checkout progress">
      {STEPS.filter(s => s !== 'confirmation').map((step, i) => (
        <div key={step} className={`step ${step === currentStep ? 'active' : ''}`}>
          <span>{i + 1}</span>
          <span>{step.charAt(0).toUpperCase() + step.slice(1)}</span>
        </div>
      ))}
    </nav>
  );
}
```

### Order Confirmation with Stable URL
```ts
// After successful payment:
const orderId = await createOrder(cart, shipping, payment);
localStorage.removeItem(STORAGE_KEY);  // clear draft
router.replace(`/checkout/confirmation/${orderId}`);  // stable, bookmarkable URL
```
Use `replace` not `push` — users should not be able to go "back" to the payment step.

## Key Rules
- Each step validates independently before `advance()` is called.
- URL reflects current step (`?step=shipping`) — never store step only in component state.
- Save partial progress to localStorage after each successful step; expire after 24 hours.
- Use `router.push` with `{ scroll: false }` — the page does not reload, no scroll jump.
- Confirmation page uses `router.replace` — prevent back-navigation to payment.
- Confirmation URL (`/checkout/confirmation/:orderId`) must be stable for bookmarking.
- Clear localStorage draft after order creation — don't let stale data pollute a future checkout.
