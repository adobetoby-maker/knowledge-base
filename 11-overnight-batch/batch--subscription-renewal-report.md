# Batch: Subscription Renewal Pipeline

## Overview
Subscription renewals require proactive work, not reactive payment retries. By the time a payment fails, you've already lost the customer's attention and goodwill. The pipeline identifies subscriptions expiring in the next 7 days, quantifies the revenue at risk, triggers reminder emails at the right intervals, retries failed payments with escalating urgency, and gives the CS team visibility into high-value accounts that need human outreach. Running nightly ensures no at-risk subscription falls through the cracks.

## Implementation

### Job Structure (Nightly at 3:00 AM)
```ts
interface RenewalBatch {
  runDate: Date;
  expiring7Days: Subscription[];
  expiring1Day: Subscription[];
  failedPayments: Subscription[];
  highValueAtRisk: Subscription[];   // MRR > $500
  mrrAtRisk: number;
  emailsSent: number;
  retryAttempts: number;
}
```

### Query: Expiring Subscriptions
```sql
-- Subscriptions expiring in 7 days (not yet notified at 7-day mark)
SELECT
  s.*,
  u.email, u.name,
  p.name AS plan_name,
  p.amount_cents AS mrr_cents,
  s.current_period_end AS expires_at,
  EXTRACT(DAY FROM s.current_period_end - CURRENT_TIMESTAMP) AS days_until_expiry
FROM subscriptions s
JOIN users u ON u.id = s.user_id
JOIN plans p ON p.id = s.plan_id
WHERE
  s.status = 'active'
  AND s.cancel_at_period_end = false
  AND s.current_period_end BETWEEN NOW() AND NOW() + INTERVAL '8 days'
  AND s.id NOT IN (
    SELECT subscription_id FROM renewal_notifications
    WHERE sent_at >= NOW() - INTERVAL '8 days'
    AND notification_type = 'day_7'
  )
ORDER BY p.amount_cents DESC;
```

### Email Trigger Logic
```ts
export async function processRenewals() {
  const expiring7d = await getExpiringSubs(7);
  const expiring1d = await getExpiringSubs(1);
  const failed = await getFailedRenewalSubs();

  const report: RenewalBatch = {
    runDate: new Date(),
    expiring7Days: expiring7d,
    expiring1Day: expiring1d,
    failedPayments: failed,
    highValueAtRisk: [...expiring7d, ...expiring1d, ...failed]
      .filter(s => s.mrrCents >= 50_000), // $500+/month
    mrrAtRisk: calculateMRRAtRisk([...expiring7d, ...expiring1d, ...failed]),
    emailsSent: 0,
    retryAttempts: 0,
  };

  // Send day-7 reminders
  for (const sub of expiring7d) {
    await sendRenewalEmail(sub, 'day_7');
    await logNotification(sub.id, 'day_7');
    report.emailsSent++;
  }

  // Send day-1 reminders (more urgent tone)
  for (const sub of expiring1d) {
    await sendRenewalEmail(sub, 'day_1');
    await logNotification(sub.id, 'day_1');
    report.emailsSent++;
  }

  // Retry failed payments with backoff
  for (const sub of failed) {
    const retryNumber = await getRetryCount(sub.id);
    if (retryNumber < 4) { // max 4 retries over ~2 weeks
      try {
        await stripe.paymentIntents.create({
          amount: sub.mrrCents,
          currency: 'usd',
          customer: sub.stripeCustomerId,
          payment_method: sub.defaultPaymentMethodId,
          confirm: true,
          off_session: true,
        });
        await markPaymentSucceeded(sub.id);
      } catch (err) {
        await logFailedRetry(sub.id, retryNumber + 1, (err as Error).message);
        if (retryNumber === 3) {
          await sendPaymentFinalFailureEmail(sub);
          await markSubscriptionCancelled(sub.id, 'payment_failure');
        }
        report.retryAttempts++;
      }
    }
  }

  return report;
}
```

### MRR at Risk Calculation
```ts
function calculateMRRAtRisk(subs: Subscription[]): number {
  return subs.reduce((total, sub) => total + sub.mrrCents, 0);
}

function getMRRAtRiskByTier(subs: Subscription[]) {
  return {
    enterprise: subs.filter(s => s.mrrCents >= 100_000).reduce((t, s) => t + s.mrrCents, 0),
    business:   subs.filter(s => s.mrrCents >= 20_000 && s.mrrCents < 100_000).reduce((t, s) => t + s.mrrCents, 0),
    starter:    subs.filter(s => s.mrrCents < 20_000).reduce((t, s) => t + s.mrrCents, 0),
  };
}
```

### CS Team Alert for High-Value Accounts
```ts
async function alertCSForHighValueAccounts(report: RenewalBatch) {
  if (report.highValueAtRisk.length === 0) return;

  const totalMRR = report.highValueAtRisk.reduce((t, s) => t + s.mrrCents, 0);

  await sendSlackMessage('#cs-alerts', {
    text: `*Renewal Alert: ${report.highValueAtRisk.length} high-value accounts at risk*`,
    blocks: [
      {
        type: 'section',
        text: `*${report.highValueAtRisk.length} subscriptions ≥ $500/mo expiring in 7 days*\n` +
              `MRR at risk: *$${(totalMRR / 100).toLocaleString()}*`,
      },
      ...report.highValueAtRisk.map(sub => ({
        type: 'section',
        text: `• ${sub.userName} (${sub.userEmail}) — $${(sub.mrrCents / 100).toLocaleString()}/mo — ${sub.daysUntilExpiry}d remaining`,
      })),
    ],
  });
}
```

### Notification Log (Prevents Duplicate Sends)
```sql
CREATE TABLE renewal_notifications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id),
  notification_type TEXT NOT NULL,  -- 'day_7', 'day_1', 'payment_failed', 'final_notice'
  sent_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(subscription_id, notification_type, date_trunc('day', sent_at))
);
```

## Key Rules
- Query notifications log before sending — duplicate renewal emails are a customer complaint waiting to happen.
- Maximum 4 payment retries over 2 weeks — more retries antagonize customers who chose not to renew.
- High-value accounts ($500+/month) get CS outreach, not just automated emails — churn at this level requires human intervention.
- Track MRR at risk in the report — "$24,000 at risk this week" is a metric leadership cares about.
- Log every failed retry attempt with the error message — payment failures often have patterns (expired cards vs insufficient funds vs bank blocks).
- Send day-1 reminder with a different, more urgent subject line than day-7 — same template twice signals automation to users.
- If Stripe payment retry fails, do not mark the subscription cancelled until the final retry — premature cancellation is irreversible and damages trust.
