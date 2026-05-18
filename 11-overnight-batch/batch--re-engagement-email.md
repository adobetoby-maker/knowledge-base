# Re-Engagement Email Batch Job

Re-engagement sequences win back inactive users by surfacing what they're missing. They only work if they're personalized, correctly suppressed, and not so aggressive that they drive unsubscribes faster than they drive logins.

## Identifying Inactive Users

Inactivity thresholds should be tiered, not a single cutoff. A user who hasn't logged in for 30 days gets different messaging than one absent for 90 days:

```sql
-- 30-day inactive: gentle nudge
SELECT user_id FROM users
WHERE last_login_at < NOW() - INTERVAL '30 days'
  AND last_login_at >= NOW() - INTERVAL '60 days'
  AND email_opt_in = TRUE
  AND re_engagement_sent_30d IS NULL;

-- 60-day inactive: stronger value reminder
-- 90-day inactive: final call / win-back offer
```

Use `last_login_at` not `created_at` — a user who created an account but never returned needs a different onboarding message, not a re-engagement message. Segment separately.

## Segmenting by Last Activity Type

Last activity type determines which feature to highlight in the re-engagement message. A user whose last action was creating a document should receive a message about documents; a user who was mid-onboarding should receive a message about getting started. Querying last activity type:

```sql
SELECT user_id, event_type, occurred_at
FROM user_events
WHERE (user_id, occurred_at) IN (
  SELECT user_id, MAX(occurred_at)
  FROM user_events
  GROUP BY user_id
);
```

Map event types to messaging tracks: `DOCUMENT_CREATED` → "Your documents are waiting", `ONBOARDING_STARTED` → "Finish setting up your account", `SUBSCRIPTION_VIEWED` → "Still thinking it over?".

## Personalized Subject Line Generation

Dynamic subject lines outperform generic ones. Use the user's first name and the feature they last touched:

- `"{{first_name}}, your {{feature}} is waiting for you"`
- `"It's been a while, {{first_name}} — here's what's new in {{feature}}"`

If generating subject lines with an LLM for personalization at scale, batch the generation job before the send job — don't block the send pipeline on LLM calls. Pre-generate and store subject lines per segment the night before the send.

A/B test subject lines within segments. Track open rate by variant; pick the winner after 4 hours and send winner to remaining recipients.

## Suppression After Unsubscribe

Never send to a suppressed address. The suppression check must happen at send time, not just at list-build time — a user may unsubscribe in the window between when the batch ran and when the email is sent.

Suppression list must include:
- Explicit unsubscribes (`email_opt_in = FALSE`).
- Bounced addresses (hard bounce = permanent suppress; soft bounce = suppress after 3 bounces).
- Spam complaint addresses (suppress immediately and permanently).
- Accounts deleted or deactivated since the list was built.

Check the suppression list via a real-time query at send time, not a cached snapshot. Sending to unsubscribed users violates CAN-SPAM and GDPR; it also triggers spam filter penalties for your sending domain.

## Key Rules

- Tier inactivity thresholds (30/60/90 days) with distinct messaging per tier.
- Segment by last activity type to send feature-relevant messaging, not generic "we miss you" copy.
- Pre-generate personalized subject lines in a batch job; don't block sends on LLM calls.
- Suppression check happens at send time via real-time query — never use a cached list.
- Hard bounces suppress permanently; soft bounces suppress after 3.
- Track open rate and unsubscribe rate per re-engagement sequence; pause sequences with >0.5% unsubscribe rate and investigate.
