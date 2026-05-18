# Principle: Metrics vs Proxy Metrics

## Overview
A proxy metric is easy to measure and correlated with a real metric — until it isn't. The danger is that optimizing a proxy metric without tracking whether it moves the real metric produces activity that looks like progress but isn't. Growth hacking that produces impressive proxy metrics while the real metric stagnates is the classic failure mode: the dashboard looks great, the business isn't growing.

## Implementation / Key Points

### The Metric Hierarchy
```
Real metric (business outcome):
  Revenue, churn, customer lifetime value, net new customers

Leading real metric (predicts the real metric):
  Activated users (users who experienced core value), DAU/MAU ratio

Proxy metric (correlated with leading metrics, easier to measure):
  Pageviews, signups, email open rate, App Store downloads

Vanity metric (impressive but disconnected from business outcomes):
  Total registered users (includes churned), raw pageviews (includes bots),
  social media followers
```

### Tracing Proxy Metrics to Real Metrics
Before adding a proxy metric to a dashboard, answer: "If this metric improves, what real metric will follow and with what lag?"

```
Email open rate ↑ → (assumption) click-through ↑ → activated users ↑ → revenue ↑

Verification: Run a cohort analysis:
  - Users who opened the email: what was their 30-day conversion rate?
  - Users who didn't open: what was their 30-day conversion rate?
  - If no difference → email open rate is not a useful proxy for this goal
```

### When Proxies Decouple from Real Metrics
Common failure modes where proxy metrics improve while real metrics don't:
- **Pageviews up, signups flat**: Traffic is from wrong audience; acquisition targeting is broken.
- **Signups up, activation flat**: Signup friction removed but product value not delivered.
- **DAU up, revenue flat**: Users engage but don't hit paywall; feature-to-conversion path broken.
- **Support tickets down, NPS flat**: Support metrics improved but root cause (product bugs) unchanged.

### Dashboard Design
```
Primary dashboard (weekly review):
  - MRR / ARR
  - Net new MRR (expansion - churn)
  - Activation rate (% of signups who hit activation event within 7 days)
  - Churn rate

Secondary dashboard (weekly, actionable):
  - Funnel conversion per step
  - Feature adoption rates
  - Cohort retention curves

Proxy metrics (for teams, not leadership):
  - Email metrics → owned by growth team
  - SEO traffic → owned by content team
  - Support volume → owned by CS team
```

### "Goodhart's Law" Warning
When a proxy metric becomes a target, it ceases to be a good proxy. If a team is measured on email open rates, they will optimize subject lines for opens, not for the downstream action. Measure the behavior you want, not the behavior you can easily count.

## Key Rules
- Every proxy metric on a dashboard must have a documented path to a real business metric.
- Verify the proxy-to-real correlation at least quarterly.
- Never manage teams to proxy metrics without also tracking the real metric they proxy for.
- "Vanity metrics" (total registered users, raw pageviews) belong in footnotes, not reports.
- If a proxy metric improves but the real metric doesn't, the proxy is broken — remove it.
- Growth hacking with proxy metrics without a path to real metrics is waste, not progress.
