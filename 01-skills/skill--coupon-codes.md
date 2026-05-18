# Skill: Coupon / Discount Codes

## Overview

Coupon codes apply discounts at checkout: percentage, fixed amount, or free shipping. Key concerns: prevent reuse (enforce max uses), validate before applying, and handle edge cases (expired, invalid, minimum order not met). Stripe Coupons + Promotion Codes handle this for subscription billing; build custom for e-commerce.

## Database Schema

```sql
CREATE TABLE coupons (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code         TEXT UNIQUE NOT NULL,  -- Uppercase, e.g., SUMMER20
  type         TEXT NOT NULL,         -- 'percent', 'fixed', 'free_shipping'
  value        NUMERIC(10,2) NOT NULL,  -- 20 for 20%, 1000 for $10.00 (in cents for fixed)
  min_order    INTEGER DEFAULT 0,     -- Min order amount in cents
  max_uses     INTEGER,               -- NULL = unlimited
  uses_count   INTEGER DEFAULT 0,
  expires_at   TIMESTAMPTZ,
  active       BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE coupon_uses (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id  UUID NOT NULL REFERENCES coupons(id),
  user_id    UUID NOT NULL REFERENCES users(id),
  order_id   UUID NOT NULL REFERENCES orders(id),
  used_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(coupon_id, user_id)  -- One use per user per coupon
);
```

## Validation Function

```ts
interface CouponValidation {
  valid: boolean
  discount: number   // Calculated discount in cents
  error?: string
}

async function validateCoupon(
  code: string,
  userId: string,
  orderAmountCents: number,
): Promise<CouponValidation> {
  const coupon = await db.query.coupons.findFirst({
    where: and(
      eq(coupons.code, code.toUpperCase()),
      eq(coupons.active, true),
    ),
  })

  if (!coupon) return { valid: false, discount: 0, error: 'Invalid coupon code' }
  if (coupon.expiresAt && coupon.expiresAt < new Date()) {
    return { valid: false, discount: 0, error: 'Coupon has expired' }
  }
  if (coupon.maxUses !== null && coupon.usesCount >= coupon.maxUses) {
    return { valid: false, discount: 0, error: 'Coupon has reached its usage limit' }
  }
  if (orderAmountCents < coupon.minOrder) {
    const minFormatted = formatCurrency(coupon.minOrder)
    return { valid: false, discount: 0, error: `Minimum order of ${minFormatted} required` }
  }

  // Check user-specific usage
  const used = await db.query.couponUses.findFirst({
    where: and(eq(couponUses.couponId, coupon.id), eq(couponUses.userId, userId)),
  })
  if (used) return { valid: false, discount: 0, error: 'You have already used this coupon' }

  // Calculate discount
  let discount = 0
  if (coupon.type === 'percent') {
    discount = Math.round(orderAmountCents * (Number(coupon.value) / 100))
  } else if (coupon.type === 'fixed') {
    discount = Math.min(Number(coupon.value), orderAmountCents)
  }

  return { valid: true, discount }
}
```

## Applying at Checkout (Atomic)

```ts
async function applyAndRecordCoupon(
  couponId: string,
  userId: string,
  orderId: string,
): Promise<void> {
  await db.transaction(async tx => {
    // Record use
    await tx.insert(couponUses).values({ couponId, userId, orderId })

    // Increment counter atomically
    await tx
      .update(coupons)
      .set({ usesCount: sql`uses_count + 1` })
      .where(eq(coupons.id, couponId))
  })
}
```

## Stripe Coupon Integration

For subscription billing, delegate to Stripe:

```ts
// Create a coupon (once, in Stripe dashboard or via API)
const coupon = await stripe.coupons.create({
  percent_off: 20,
  duration: 'once',  // 'once', 'forever', 'repeating'
  max_redemptions: 100,
})

// Create a promotion code customers enter
const promoCode = await stripe.promotionCodes.create({
  coupon: coupon.id,
  code: 'SUMMER20',
  restrictions: { minimum_amount: 5000, minimum_amount_currency: 'usd' },
})

// Apply at checkout
const session = await stripe.checkout.sessions.create({
  allow_promotion_codes: true,  // Let Stripe validate automatically
  // ...
})
```

## Key Rules

- Validate server-side at checkout, never trust client-side validation alone.
- Use a transaction when incrementing `uses_count` + recording the use — prevents race conditions where two simultaneous uses both succeed at the last allowed use.
- Normalize input to uppercase: `code.toUpperCase().trim()`.
- Return specific error messages ("Expired" vs "Already used") — it helps users understand without revealing security details.
