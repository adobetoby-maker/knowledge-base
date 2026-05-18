# Pattern: Subscription Upgrade Flow

## Overview
Plan upgrades involve money changing hands and access level changes. Users need to see exactly what they'll be charged before committing — a surprise charge is the fastest way to generate chargebacks and cancellations. Access must update atomically with payment so users aren't in a broken intermediate state.

## Implementation

### Step 1: Show Plan Comparison + Proration Preview
```typescript
// Server: calculate proration before showing upgrade UI
async function getUpgradePreview(userId: string, targetPlanId: string) {
  const currentSub = await stripe.subscriptions.retrieve(user.stripeSubscriptionId);
  const targetPlan = await stripe.prices.retrieve(targetPlanId);

  // Stripe's proration preview
  const preview = await stripe.invoices.retrieveUpcoming({
    customer: user.stripeCustomerId,
    subscription: user.stripeSubscriptionId,
    subscription_items: [{ id: currentSub.items.data[0].id, price: targetPlanId }],
    subscription_proration_behavior: 'create_prorations',
  });

  return {
    amountDueToday: preview.amount_due, // cents
    nextBillingDate: new Date(currentSub.current_period_end * 1000),
    nextBillingAmount: targetPlan.unit_amount,
  };
}
```

```tsx
function UpgradeModal({ currentPlan, targetPlan, preview }) {
  return (
    <div>
      <PlanComparison current={currentPlan} target={targetPlan} />
      <div className="proration-preview">
        <p>Charged today: <strong>${(preview.amountDueToday / 100).toFixed(2)}</strong></p>
        <p className="text-muted text-sm">
          Prorated for remaining {preview.daysRemaining} days of current billing period.
        </p>
        <p>Starting {formatDate(preview.nextBillingDate)}: ${(preview.nextBillingAmount / 100).toFixed(2)}/mo</p>
      </div>
      <Button onClick={confirmUpgrade}>
        Confirm Upgrade — Charge ${(preview.amountDueToday / 100).toFixed(2)} Now
      </Button>
    </div>
  );
}
```

### Step 2: Execute Upgrade
```typescript
async function executeUpgrade(userId: string, targetPlanId: string) {
  const user = await db.users.findById(userId);

  // Perform the Stripe subscription change
  const subscription = await stripe.subscriptions.update(user.stripeSubscriptionId, {
    items: [{ id: currentItemId, price: targetPlanId }],
    proration_behavior: 'create_prorations',
    payment_behavior: 'error_if_incomplete', // fail fast if card declines
  });

  // Update access immediately — don't wait for webhook
  await db.users.update({ id: userId }, {
    planId: targetPlanId,
    planUpdatedAt: new Date(),
  });

  await sendEmail({ to: user.email, template: 'plan-upgraded', data: { plan: targetPlan.name } });

  return { success: true };
}
```

### Step 3: Handle Payment Failure
```typescript
// If stripe throws on payment_behavior: 'error_if_incomplete'
catch (err) {
  if (err.code === 'card_declined') {
    return {
      error: 'payment_failed',
      message: 'Your card was declined. Please update your payment method and try again.',
      updatePaymentUrl: '/billing/payment-method',
    };
  }
  throw err;
}
```

### Webhook: Reconcile via Events (belt-and-suspenders)
```typescript
// Handle customer.subscription.updated webhook
// This catches cases where the API call succeeded but the app crashed
async function handleSubscriptionUpdated(event: Stripe.Event) {
  const sub = event.data.object as Stripe.Subscription;
  const priceId = sub.items.data[0].price.id;
  await db.users.update(
    { stripeSubscriptionId: sub.id },
    { planId: priceId, planUpdatedAt: new Date() }
  );
}
```

## Key Rules
- Always show the proration amount before charging — never surprise the user
- Show both what's charged today AND what the recurring amount will be going forward
- Update access immediately after the API call succeeds — don't wait for webhook
- Use webhooks as a reconciliation mechanism, not the primary update path
- Use `payment_behavior: 'error_if_incomplete'` to surface card failures immediately
- On payment failure, link directly to the payment method update page
- Send a confirmation email with the new plan name and next billing amount
- Do not downgrade features during upgrade — handle the window between payment and access atomically
- Cache the proration preview briefly (30s) to avoid calling Stripe on every render
- Log all plan changes to your audit log with the actor, old plan, new plan, and timestamp
