# Principle: Semantic Logging

## Overview
Semantic logging treats log entries as structured events with machine-parseable names, not as human-readable strings. The difference between `logger.info("User upgraded their subscription to Pro plan")` and `logger.info("user.subscription.upgraded", { plan: "pro" })` is the difference between logs you can only grep and logs you can query, aggregate, alert on, and feed into analytics pipelines. When logs are events, your log aggregator becomes a queryable event store.

## The Problem With String-Based Logs

```typescript
// String-based — readable by humans, useless for machines
logger.info(`User ${userId} upgraded subscription from ${oldPlan} to ${newPlan}`);

// To find this: grep for the string pattern — brittle if the string changes
// To count upgrades to "pro": grep + count — slow, error-prone
// To dashboard upgrade rate: impossible without parsing free text
// To alert on spike in downgrades: can't distinguish from upgrades
```

With 10 million log lines, string matching is slow and fragile. If one engineer changes the phrasing, automated alerts break silently.

## The Semantic Event Pattern

```typescript
// Semantic — machine-parseable event name + structured context
logger.info("user.subscription.upgraded", {
  userId,
  previousPlan: oldPlan,
  newPlan,
  upgradeValue: newPlan === "pro" ? 49 : 99,
  source: "settings-page",
});
```

Now:
- **Filter:** `event:"user.subscription.upgraded"` → all upgrade events
- **Aggregate:** count by `newPlan` → plan distribution
- **Dashboard:** plot `upgradeValue` over time → revenue impact
- **Alert:** rate of `user.subscription.downgraded` spikes → churn alert
- **Analytics:** join with user signup source → conversion analysis

## Event Name Conventions

Use dot-notation with `domain.entity.action` format:

```
user.registered
user.login.succeeded
user.login.failed
user.subscription.upgraded
user.subscription.cancelled
order.created
order.payment.succeeded
order.payment.failed
order.shipped
order.refunded
api.request.received
api.request.completed
api.rate_limit.hit
background.job.started
background.job.completed
background.job.failed
```

These names are stable identifiers — changing them is a breaking change for anyone who has alerts or dashboards keyed on them.

## What to Include in Event Context

```typescript
logger.info("order.payment.succeeded", {
  // Identity
  userId: user.id,
  orderId: order.id,
  
  // Business metrics (for dashboards)
  amountCents: payment.amount,
  currency: payment.currency,
  provider: "stripe",
  
  // Debug context (for incident investigation)
  stripePaymentIntentId: payment.externalId,
  retryCount: attempt,
  durationMs: Date.now() - startTime,
  
  // Infrastructure context (from middleware/child logger)
  requestId: ctx.requestId,
  environment: process.env.NODE_ENV,
});
```

## Semantic Logging Enables Automated Alerting

```yaml
# Datadog alert rule
name: High payment failure rate
query: |
  (sum:logs.event{"order.payment.failed"}.as_rate() /
   sum:logs.event{"order.payment.succeeded"}.as_rate()) > 0.05
message: "Payment failure rate exceeded 5% — investigate immediately"
```

This alert would be impossible to write reliably against string-based logs.

## Mapping Events to Business Outcomes

Every key business outcome should have a corresponding event:
- User acquisition: `user.registered`, `user.onboarding.completed`
- Revenue: `order.payment.succeeded`, `subscription.renewed`
- Retention: `user.login.succeeded` (frequency = engagement proxy)
- Churn: `user.subscription.cancelled`
- Support load: `support.ticket.created`

These events feed dashboards, product analytics (Mixpanel, Amplitude), and anomaly detection — all from the same log stream.

## Key Rules
- Event names are `domain.entity.action`, dot-separated, snake_case within segments
- Event names are stable identifiers — they appear in dashboards and alerts, not just logs
- Numeric metrics belong in the event context (amounts, durations, counts)
- Changing an event name requires updating all alert rules and dashboards first
- Do not embed variable data in the event name: `user.subscription.upgraded.to.pro` is wrong; `{ newPlan: "pro" }` is right
- Error events use the same domain structure: `order.payment.failed` not a generic `error`
- Log every significant state transition as a discrete event
