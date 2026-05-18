# MCP: Stripe Operations

## Overview
The Stripe MCP tools are appropriate for targeted, interactive operations: setting up products and prices, investigating specific payment failures, and issuing individual refunds. They are not appropriate for bulk operations (use the Stripe Dashboard or API scripts) or financial reporting (use Stripe Dashboard or Sigma). Always `authenticate` first in a session—the MCP requires a fresh auth token and operations silently fail without it.

## Authentication
```
stripe authenticate
→ opens OAuth flow to connect your Stripe account
→ required once per session; tokens expire
```

## Setting Up Products and Prices
```
// Create a product
stripe create product:
  name: "Pro Plan"
  description: "Unlimited projects, priority support"
  metadata: { plan_tier: "pro" }
→ returns product.id: "prod_xxx"

// Create a recurring price for the product
stripe create price:
  product: "prod_xxx"
  unit_amount: 2900        // cents ($29.00)
  currency: "usd"
  recurring:
    interval: "month"
→ returns price.id: "price_xxx"

// Create a one-time price
stripe create price:
  product: "prod_xxx"
  unit_amount: 9900
  currency: "usd"
→ price.id for checkout sessions
```

## Investigating Failed Payments
```
// Find a specific payment intent by customer email
stripe list payment_intents filter: {
  customer: "cus_xxx",
  limit: 10
}

// Get failure details
stripe retrieve payment_intent pi_xxx
→ status: "requires_payment_method"
→ last_payment_error:
    code: "card_declined"
    decline_code: "insufficient_funds"
    message: "Your card has insufficient funds."

// Common decline codes and meanings:
// card_declined / insufficient_funds    → customer issue
// card_declined / do_not_honor          → bank blocked; customer must call bank
// card_declined / card_velocity_exceeded → fraud protection triggered
// card_declined / incorrect_cvc         → CVC mismatch; re-enter card
// expired_card                          → card expired
```

## Issuing Refunds
```
// Full refund
stripe create refund:
  payment_intent: "pi_xxx"
  reason: "customer_request"

// Partial refund
stripe create refund:
  payment_intent: "pi_xxx"
  amount: 1500           // cents — partial refund of $15.00
  reason: "fraudulent"  // or "duplicate", "customer_request"

// Refund reasons:
// "customer_request"   → standard customer-requested refund
// "duplicate"          → accidental double charge
// "fraudulent"         → fraud confirmed; also triggers chargeback protection
```

## Creating Coupon Codes
```
// Percent off coupon
stripe create coupon:
  percent_off: 20
  duration: "once"       // or "forever", "repeating"
  name: "LAUNCH20"
  max_redemptions: 100

// Amount off coupon
stripe create coupon:
  amount_off: 1000       // $10.00 off
  currency: "usd"
  duration: "once"

// Create a promotion code (human-readable code pointing to coupon)
stripe create promotion_code:
  coupon: "coupon_xxx"
  code: "LAUNCH20"       // the code customers enter at checkout
```

## Querying Subscriptions
```
// Find all subscriptions for a customer
stripe list subscriptions filter: {
  customer: "cus_xxx",
  status: "active"
}

// Cancel a subscription at period end (not immediately)
stripe update subscription sub_xxx:
  cancel_at_period_end: true

// Immediate cancellation
stripe cancel subscription sub_xxx
```

## Key Rules
- **`authenticate` at session start** — Stripe MCP requires a valid token; operations fail silently without it.
- **Never use MCP for bulk operations** — updating 500 prices or migrating customers belongs in a script with the Stripe SDK, not interactive MCP calls.
- **Never use MCP for reporting** — Stripe Dashboard → Reports or Sigma for revenue queries; MCP is for individual record inspection.
- **Check `last_payment_error.decline_code`** — the top-level `code` ("card_declined") is generic; `decline_code` tells you the actual reason.
- **Partial refunds use cents** — `amount: 1500` = $15.00; always double-check the value before confirming.
- **`cancel_at_period_end: true` over immediate cancel** — immediate cancellation terminates access now; period-end preserves the customer's paid time.
