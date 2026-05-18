# Skill: Bulk Email Campaign Sending

## Purpose
Send large-volume transactional or marketing emails reliably without getting blocked by ESP rate limits, losing unsubscribes, or ignoring bounces. The easy part is writing the email. The hard part is everything that happens at volume: rate limits, deliverability, list hygiene, and regulatory compliance.

## ESP Rate Limits — Know Your Ceiling
Different ESPs have different rate limits. Never exceed them or you'll hit 429s and lose emails:
- **SES (AWS)**: default 50 emails/second, can be raised via support request (some accounts reach 1000+/s). Check `ses:GetSendQuota` for your current limit.
- **Postmark**: up to 500/s on paid plans; lower on trial accounts.
- **SendGrid**: varies by plan — 100/s on Essentials, higher on Pro.
- **Resend**: 100/s default.

Always implement a token bucket or rate limiter in the sending worker. Don't rely on catching 429s as your throttle mechanism — that causes retries and delays.

## Chunked Background Processing
Never send bulk emails in a synchronous request handler. Chunk and queue:
1. Upload or query your recipient list → write all records to a `campaign_sends` table with status `queued`
2. Enqueue a background job per chunk (500–1000 recipients per job)
3. Each job fetches its chunk, renders personalised emails, sends via ESP batch API, updates status per recipient

```sql
campaign_sends (
  id, campaign_id, recipient_email, personalization jsonb,
  status text,        -- queued | sent | failed | bounced | complained
  sent_at timestamptz,
  error text
)
```

Idempotency: before sending, check `status = 'queued'`. If it's already `sent`, skip. This means job retries are safe.

## Unsubscribe Handling — Legal and Technical
CAN-SPAM and GDPR both require functional unsubscribes. Two mechanisms:
1. **List-Unsubscribe header**: include `List-Unsubscribe: <https://yourapp.com/unsubscribe?token=...>` in every email header. Inbox providers show a one-click unsubscribe button. Gmail requires this for senders sending >5k/day.
2. **In-email link**: a clear "Unsubscribe" link at the bottom with a signed token (HMAC the email address — don't expose raw user IDs).

When unsubscribe fires: mark `email_preferences.unsubscribed_at = now()`. Never send to unsubscribed addresses again. Check this flag before every send, not just at campaign creation. Process unsubscribes within 10 business days (CAN-SPAM) — in practice, process them immediately.

## Bounce and Complaint Webhook Processing
Hard bounces mean the address doesn't exist. Complaints mean the user marked you as spam. Both destroy deliverability if ignored.

Register webhooks with your ESP for:
- **Hard bounce** (`permanent_failure`): suppress the address immediately. Never retry. Mark `email_addresses.bounced = true`.
- **Soft bounce** (`temporary_failure`): retry up to 3 times over 48h, then suppress.
- **Complaint/spam report**: suppress immediately, same as hard bounce. Sending to complainers gets you blacklisted.

Store suppression in a `email_suppressions` table. Check it at send time, not just on list import. If you switch ESPs, export your suppression list and import it — suppressions don't follow you automatically.

## Send-Time Optimization
For marketing emails (not transactional), send-time optimization improves open rates:
- Default: send at 10am in the recipient's timezone (requires storing timezone — fall back to 10am UTC)
- Personalized: if you have per-user open history, find each user's historical peak open hour and schedule accordingly
- Never send between 10pm–6am recipient local time
- For transactional (order confirmations, password resets): send immediately, ignore send-time rules

## Warm-Up New Sending Domains
A new domain or IP must warm up before sending high volumes or ESP filters will block you. Start with 100/day, double daily for 2–3 weeks. High engagement (opens, clicks) improves your sender reputation. Only send to your most engaged users during warm-up.

## Key Rules
- **Know your ESP's rate limit and enforce it in the worker** — don't discover it from 429 errors
- **Process bounces and complaints via webhook within minutes** — ignoring them gets you blacklisted
- **Check suppressions at send time** — not just at campaign creation, because unsubscribes happen between sends
- **`List-Unsubscribe` header on every email** — required by Gmail for bulk senders
- **Chunk into background jobs** — never send bulk email synchronously
- **Personalize with data from the DB at render time** — not at list-import time, which goes stale
- **Warm up new domains** — jumping to 100k/day on a new domain will get you blocked
