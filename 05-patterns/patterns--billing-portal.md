# Pattern: Billing Portal

## Why This Pattern Matters

Billing pages directly impact revenue and churn. Users who can't find their plan, can't update their card, or can't download an invoice escalate to support or cancel. The billing portal must be the most reliable, clearly labeled section in the app — any confusion here is a trust breach.

## Stripe Customer Portal vs Custom UI

**Default to Stripe Customer Portal** unless you need tight design integration or custom upgrade flows.

| Stripe Portal | Custom UI |
|---|---|
| Zero code for payment method, invoice, cancel | Full design control |
| PCI-compliant out of the box | Must use Stripe Elements |
| Redirects away from app | Stays in-app |
| No access to raw events before render | Can add upsell copy, prorated previews |

Redirect to Stripe Portal via a server-side session:

```ts
// Route handler — never expose secret key client-side
const session = await stripe.billingPortal.sessions.create({
  customer: user.stripeCustomerId,
  return_url: `${process.env.APP_URL}/settings/billing`,
});
return redirect(session.url);
```

For custom UI: use Stripe Elements for payment method updates — never build raw card input fields.

## Current Plan Display

Show clearly: plan name, billing interval (monthly/annual), next renewal date, price. If on a trial, show days remaining in a prominent banner. If on a legacy plan, label it explicitly and show what the current equivalent is.

## Upgrade / Downgrade Flow

Always show a **prorated preview** before confirming a plan change. Users cancel upgrades when they're surprised by immediate charges. Fetch the proration from Stripe:

```ts
const preview = await stripe.invoices.retrieveUpcoming({
  customer: customerId,
  subscription: subscriptionId,
  subscription_items: [{ id: itemId, price: newPriceId }],
});
```

Present: "You'll be charged $X today (prorated credit of $Y applied)" before the confirm button.

Downgrade to free: don't cancel immediately — schedule cancellation at period end and show "Your plan will downgrade on [date]" with an undo option until that date.

## Payment Method Management

List all saved payment methods. Mark the default. Allow adding a new card (Stripe Elements `PaymentElement`). Allow setting a different card as default. Allow removing non-default cards only — prevent removing the last card if an active subscription exists.

## Invoice History Table

| Date | Amount | Status | Action |
|---|---|---|---|
| May 1, 2026 | $49.00 | Paid | Download PDF |
| Apr 1, 2026 | $49.00 | Paid | Download PDF |

PDF download is a direct link to `invoice.invoice_pdf` from the Stripe invoice object. Never generate PDFs manually — Stripe's are compliant. Show status as a badge (Paid=green, Open=yellow, Void=gray, Uncollectible=red). Limit to last 12 invoices with a "View all" link to the full Stripe portal.

## Cancellation Flow

Cancellation should feel considered, not hidden. Show a short retention modal with the top reason for canceling (use a radio group: "Too expensive", "Missing feature", "Not using it", "Switching to competitor", "Other"). On submit, cancel at period end via the API. Show confirmation with the end date. Offer a one-click "Resume subscription" button that remains active until the period end.

## Key Rules

- Default to Stripe Customer Portal; only build custom UI for design-critical flows
- Always show prorated preview before confirming a plan change
- Downgrade schedules to period end — never immediate unless user explicitly selects "Cancel immediately"
- Never build raw card inputs; use Stripe Elements
- Remove card blocked if it's the last card on an active subscription
- Invoice PDFs link directly to Stripe-generated URLs
- Cancellation flow captures reason for churn analysis
