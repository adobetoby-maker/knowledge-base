# Debugging Production Issues

## The First Rule: Don't Make It Worse

Production debugging carries one absolute constraint: investigation must not create new incidents. Every action taken while a system is degraded is a potential second failure. Read before you write. Observe before you change. Confirm a theory before you act on it.

## Read-Only Investigation First

Start with what's already collected, in this order:

**1. Application error tracker (Sentry / Datadog / Bugsnag)**
- Look at the error volume chart — is this a spike or a slow ramp? A spike suggests a deploy or external dependency failure. A ramp suggests a data-driven problem accumulating.
- Check the first-seen timestamp relative to the last deploy.
- Read the stack trace — note the exact file + line, not just the message.
- Look at breadcrumbs — what did the user do 30 seconds before the error?

**2. Log aggregation (Datadog, Logtail, CloudWatch)**
```
# Good first queries
level:error service:api timestamp:[now-30m TO now]
"Connection refused" OR "ETIMEDOUT" timestamp:[now-1h TO now]
status:500 path:/api/checkout  # isolate endpoint
```

Look for correlated log lines — the same request ID appearing in multiple services shows the propagation path.

**3. DB slow query logs**
- Check `pg_stat_activity` for long-running queries blocking others.
- Check `pg_stat_user_tables` for unexpected sequential scans.
- Look at `lock_timeout` errors — often a sign that a migration is running on a hot table.

## Reproduce Without Affecting All Users

**Feature flags**: if the system supports it, enable verbose logging or an alternative code path for a single user ID. Never deploy debug logging for all users — logging is not free, and PII in logs is a compliance risk.

**Read-only DB queries**: reproduce the failing query against a read replica. Confirms the data shape without risk of modification. Most connection pools can target a replica with a query hint or connection string parameter.

**Capture the request**: if a specific request body causes the failure, extract it from logs and replay it against the API in a staging environment. Don't replay writes in production unless you understand the full side-effect surface.

## Adding Temporary Logging

When existing logs don't contain enough context, add targeted logging — but do it carefully:

**Via hot config**: feature flag systems (LaunchDarkly, Vercel feature flags) can gate a code path that includes additional logging without a deploy. This is the safest approach.

**Via deploy**: for systems without hot config, a deploy of a logging-only change is lower risk than debugging blind. Keep the diff minimal — add log lines, nothing else. Don't refactor while debugging production.

What to log:
```ts
logger.debug('payment_intent_create', {
  userId,           // context
  amount,           // inputs
  currency,
  stripeCustomerId, // intermediate state that could mismatch
  requestId: ctx.requestId,  // correlation ID
});
```

What NOT to log: passwords, full card numbers, SSNs, auth tokens, raw request bodies from untrusted input.

## Forming and Testing Hypotheses

Work through hypotheses methodically. For each candidate cause:
1. What observable evidence would confirm it? (Not "it might be X" — "if X, then log Y will show Z")
2. Is that evidence present?
3. What's the minimal reversible change to confirm?

Track hypotheses explicitly, even in a scratch doc. In an incident, the pressure to act overrides the discipline to think. Write down what you've ruled out — it stops you from re-investigating dead ends.

## Cleanup Is Mandatory

After the incident:
- Remove temporary logging — it adds noise and may log PII.
- Remove any feature flags created for investigation.
- Document what the log lines revealed (in a post-mortem or the ticket) so the next person doesn't have to rediscover them.
- If you added a DB index as a hotfix, schedule a proper migration to create it `CONCURRENTLY` and confirm the existing one can be dropped.

## Key Rules

- **Read-only first** — never modify production state without exhausting observation first.
- **Check deploy timestamps** against error spike timestamps before assuming a data issue.
- Use **correlation/request IDs** to trace a single request across services.
- **Reproduce on read replica** before touching the primary.
- **Gate verbose logging** to one user ID via feature flag — don't log for everyone.
- **Never log PII or credentials** — not even temporarily.
- **Remove all debug artifacts** before closing the incident — cleanup is not optional.
- In an incident: **write down hypotheses and what you've ruled out** — fatigue kills systematic thinking.
