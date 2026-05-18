# Skill: Stripe Connect for Marketplaces

## Overview
Stripe Connect lets platforms process payments on behalf of other businesses. The right Connect type determines who owns the Stripe relationship, who handles disputes, and how much control users have over their payout settings. Choosing the wrong type is expensive to change: Express users have a Stripe-hosted onboarding flow and their own dashboard; Standard users have full Stripe accounts; Custom accounts are entirely platform-managed. Most marketplaces should start with Express.

## Implementation

### Connect Account Types
| Type | Use when | Onboarding | Dashboard |
|---|---|---|---|
| Standard | Users are established businesses who want full control | User creates Stripe account independently | User has full Stripe dashboard |
| Express | Platform manages UX but wants Stripe compliance | Stripe-hosted Connect onboarding | Limited Stripe Express dashboard |
| Custom | Platform needs complete control of UX and compliance | Platform-built, fully custom | No Stripe dashboard |

### Express: Creating a Connected Account
```ts
// Create account
const account = await stripe.accounts.create({ type: 'express' });

// Store account.id in your DB
await db.users.update({ stripeConnectId: account.id }, { where: { id: userId } });

// Generate onboarding link
const accountLink = await stripe.accountLinks.create({
  account: account.id,
  refresh_url: `${BASE_URL}/connect/refresh`,
  return_url: `${BASE_URL}/connect/return`,
  type: 'account_onboarding',
});

redirect(accountLink.url);
```

### Checking Onboarding Completion
```ts
const account = await stripe.accounts.retrieve(stripeConnectId);

if (account.details_submitted && account.charges_enabled) {
  // Account is fully onboarded and can receive payouts
}
// else: redirect to accountLink again for incomplete onboarding
```

### Destination Charges (Platform charges, transfers to connected account)
```ts
// Platform charges the customer; platform gets the remainder after transfer_amount
const paymentIntent = await stripe.paymentIntents.create({
  amount: 10000,            // $100.00 in cents
  currency: 'usd',
  transfer_data: {
    destination: connectedAccountId,
    amount: 8500,           // $85.00 goes to connected account (85% minus any fees)
  },
  // Platform application_fee is Stripe's way to track revenue
  application_fee_amount: 1000,  // $10 platform fee
});
```

### Separate Charges and Transfers (More flexible)
```ts
// Step 1: Create charge on platform account
const charge = await stripe.charges.create({
  amount: 10000,
  currency: 'usd',
  source: paymentMethodId,
});

// Step 2: Transfer after fulfillment (use this when payout should be delayed)
const transfer = await stripe.transfers.create({
  amount: 8500,
  currency: 'usd',
  destination: connectedAccountId,
  transfer_group: orderId, // group related transfers
  source_transaction: charge.id,
});
```

### Connect Webhooks vs Account Webhooks
```ts
// Events on your platform account: use standard webhook endpoint
// Events on connected accounts: Stripe sends with the account's perspective

// In your webhook handler, check for the Stripe-Account header:
const connectedAccountId = request.headers['stripe-account'];

if (connectedAccountId) {
  // This event is for a connected account
  const event = stripe.webhooks.constructEvent(
    rawBody,
    sig,
    CONNECT_WEBHOOK_SECRET // separate secret for connect webhooks
  );
  await handleConnectEvent(event, connectedAccountId);
} else {
  // Platform-level event
}
```

### Payout Schedule Configuration
```ts
// Set when creating or updating the account
await stripe.accounts.update(connectedAccountId, {
  settings: {
    payouts: {
      schedule: {
        interval: 'daily',  // 'manual' | 'daily' | 'weekly' | 'monthly'
      },
      debit_negative_balances: true,
    },
  },
});
```

### Refunds on Connect Charges
```ts
// Refunds on destination charges come from the platform account
// Stripe automatically reverses the transfer to the connected account
const refund = await stripe.refunds.create({
  charge: chargeId,
  reverse_transfer: true,   // also reverses the transfer
  refund_application_fee: true, // also refunds your platform fee
});
```

## Key Rules
- Store `account.id` immediately on creation — if the user closes the onboarding tab, you need to resume, not create a new account.
- Always check `charges_enabled` AND `details_submitted` before allowing transactions — `details_submitted` alone doesn't mean the account can receive money.
- Connect webhook secret is different from your platform webhook secret — configure both separately.
- Destination charges are simpler; separate charges + transfers are necessary when fulfillment and charging are decoupled.
- `application_fee_amount` (not `transfer_data.amount`) is the canonical way to define platform revenue — it's reported in Stripe's platform metrics.
- Custom accounts require your platform to handle all compliance (KYC) — only choose Custom if you have legal and compliance resources.
- Test with Stripe's test connected accounts — `acct_1MdGw0Qdm9T7P7qF` style IDs work in test mode.
