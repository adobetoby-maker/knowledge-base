# Failure: Cron Jobs Running at Wrong Times

## The Core Problem

Cron expressions are deceptively simple but hide two major failure classes: timezone confusion and distributed execution. A job configured to run "every day at midnight" can run at the wrong time, run twice, or not run at all — without any error.

## UTC vs Local Time in Cron Expressions

Cron daemons, CI schedulers (GitHub Actions, Vercel), and cloud schedulers (AWS EventBridge, Cloudflare) almost always interpret cron expressions in **UTC**. Your server may be in UTC. Your developers may be in UTC-7. Your customers may be in UTC+9.

```
# Intended: midnight Pacific (UTC-8)
0 0 * * *   # This runs at UTC midnight = 4pm Pacific
0 8 * * *   # This runs at midnight Pacific Standard Time
```

Always specify cron times in UTC and annotate with the UTC offset for every timezone you care about:

```
0 8 * * *  # 08:00 UTC = 00:00 PST / 01:00 PDT / 17:00 JST
```

Never use "midnight" as shorthand — specify the UTC hour explicitly in code comments.

## Daylight Saving Time Shifts

Jobs that run at times affected by DST shifts are problematic:
- In spring (clocks spring forward), jobs at the skipped hour simply don't run.
- In fall (clocks fall back), jobs at the repeated hour run twice.

Mitigation: schedule critical jobs at times that don't exist in DST transition windows (avoid 1:00–3:00 AM local time in affected regions). Better: keep all cron expressions in UTC, which has no DST.

If a job must run at a specific local time, use a scheduler library that understands IANA time zone identifiers (not UTC offsets, which don't account for DST):

```ts
// Wrong — fixed offset doesn't handle DST
schedule('0 8 * * *', { timezone: 'UTC-7' });

// Correct — IANA name handles DST automatically
schedule('0 8 * * *', { timezone: 'America/Los_Angeles' });
```

## Distributed Cron: Multiple Instances Running the Same Job

When your app runs on multiple instances (horizontal scaling, multiple dynos, multiple containers), every instance runs its own cron scheduler. A job fires on all instances simultaneously. For idempotent jobs this is harmless but wasteful. For non-idempotent jobs (sending an email, charging a card, generating a report) it's a serious bug.

The fix is a distributed lock acquired before running the job. Only the instance that wins the lock executes; others skip.

Using Redis `SETNX` (SET if Not eXists):

```ts
async function runWithLock(key: string, ttlMs: number, fn: () => Promise<void>) {
  const acquired = await redis.set(key, '1', 'PX', ttlMs, 'NX');
  if (!acquired) return; // another instance is running
  try {
    await fn();
  } finally {
    await redis.del(key);
  }
}

// Usage
runWithLock('cron:daily-report', 60_000, generateDailyReport);
```

TTL should be slightly longer than the expected job duration — if the job crashes, the lock auto-expires. Release explicitly on success.

## Missing Execution Monitoring

Cron jobs fail silently. The job doesn't run, no error is thrown, and nothing alerts. Add heartbeat monitoring: on successful completion, send a ping to a dead-man's-switch service (Cronitor, Sentry cron, Better Uptime). If the ping doesn't arrive within the expected window, you get an alert.

```ts
// After successful job completion
await fetch(`https://cronitor.link/p/${CRONITOR_ID}/complete`);
```

## Key Rules

- **Write all cron expressions in UTC** and annotate the local-time equivalents in comments.
- **Use IANA timezone names** (not UTC offsets) when a scheduler must run at a local time.
- **Assume every deployment runs multiple instances** — any non-idempotent cron must use a distributed lock.
- **`SETNX` with TTL** is the correct Redis locking primitive — `SETNX` alone leaks locks on crash.
- **Monitor cron completion, not just cron execution** — a dead-man's-switch catches silent failures.
