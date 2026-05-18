# Processing Expired Trial Accounts

## Why a Dedicated Expiry Job

Trials expire at a specific moment but the business process — downgrade, email, access revocation — shouldn't happen at 3am exactly when the user's trial clock runs out. A nightly batch gives you a controlled window to process expirations in bulk, apply grace periods consistently, and send emails at a reasonable time rather than at midnight.

## Querying Trials to Process

Fetch trials that expired in the past 24 hours and haven't been processed yet:

```sql
SELECT u.id, u.email, u.name, t.expires_at
FROM users u
JOIN trials t ON t.user_id = u.id
WHERE t.expires_at < NOW()
  AND t.processed_at IS NULL
  AND t.status = 'active'
ORDER BY t.expires_at ASC
LIMIT 500;
```

The `processed_at IS NULL` gate is critical for idempotency. Without it, re-running the job double-emails users and double-applies downgrades.

Process in batches of 500 with a small delay between batches (1–2s) if sending email — bulk sends at full speed often trigger spam filters.

## Grace Period Logic

A 24-hour grace period prevents edge cases from penalizing users:
- User's credit card expired; they get one extra day to update it
- Trial ended at midnight; user logs in at 8am to upgrade and finds their account locked
- Payment processing delay (Stripe webhooks can lag)

Implementation:
```js
const GRACE_PERIOD_HOURS = 24;
const graceCutoff = subHours(new Date(), GRACE_PERIOD_HOURS);

// Only process trials that expired MORE than 24h ago
// Trials that expired within the last 24h are in grace period
const isExpiredBeyondGrace = trial.expires_at < graceCutoff;
```

Store `grace_period_ends_at` in the trial record so UI can show the user a countdown: "Your account will be downgraded in 6 hours."

## Downgrade vs Suspend Logic

Decide based on your product's model:
- **Downgrade (free tier):** User retains access to core features; premium features locked. Better for SaaS with a meaningful free tier. Fewer support tickets than suspension.
- **Suspend:** All access revoked. Use when the product has no free tier or when trial data should be preserved but inaccessible.

Don't delete data on trial expiry — ever. Data deletion requires a separate process with its own notification timeline (typically 90 days). Immediate deletion on expiry generates support escalations and potential legal exposure.

```js
async function processExpiredTrial(userId, action) {
  await db.transaction(async (tx) => {
    if (action === 'downgrade') {
      await tx.query('UPDATE users SET plan = $1 WHERE id = $2', ['free', userId]);
    } else if (action === 'suspend') {
      await tx.query('UPDATE users SET status = $1 WHERE id = $2', ['suspended', userId]);
    }
    await tx.query('UPDATE trials SET status = $1, processed_at = NOW() WHERE user_id = $2',
      ['expired', userId]);
  });
}
```

Wrap the status change and the `processed_at` update in a single transaction. If the email sends but the status change fails (or vice versa), you end up in an inconsistent state.

## Personalized Expiry Email

Include in the expiry email:
- User's name
- Specific date/time the trial ended (their timezone if known)
- What access they've lost (be specific — vague "features locked" generates support questions)
- Clear upgrade CTA with a direct link to the pricing page
- Data preservation assurance — explicitly tell them their data is safe for X days

Don't send the downgrade email at the exact moment of processing (batch job timing is arbitrary). If your job runs at 2am, users get a jarring email at 2am. Schedule emails for 9am user-local time, or for a fixed hour in the account's timezone. If timezone is unknown, use 9am UTC.

## Idempotency Double-Check

Three layers of protection against double-sending:

1. `processed_at IS NULL` in the query (primary gate)
2. `status = 'active'` in the query (secondary gate — already-processed trials have status 'expired')
3. Unique constraint or advisory lock on `trial_id` during processing (prevents concurrent job runs from double-processing)

## Key Rules

- Set `processed_at` in the same transaction as the plan/status change — never in a separate step.
- Apply a 24-hour grace period between trial expiry and access revocation; edge cases will thank you.
- Never delete user data on trial expiry; set a clear retention period (90 days minimum) and communicate it.
- Schedule expiry emails for business hours (9am) rather than at batch job run time (2–4am).
- Use three idempotency layers: query filter + status check + advisory lock.
- Log every processed trial with outcome (downgraded/suspended/skipped) and reason for audit trails.
