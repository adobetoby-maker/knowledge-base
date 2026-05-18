# Disambig: Email Sending Approach

## Choose by Provider and Use Case

| Scenario | Recommended approach |
|----------|---------------------|
| New project, transactional email | Resend + React Email |
| Client has Gmail, low volume | Nodemailer + Gmail App Password |
| Need marketing/campaigns with analytics | Resend Broadcasts |
| Existing SMTP server | Nodemailer generic SMTP |
| Bulk email (>10k/month) | SendGrid or Postmark |
| Edge/Worker environment | Resend API (fetch-based) |

## Choose Resend

When:
- New project without existing email setup
- Want deliverability without configuring SPF/DKIM manually (Resend handles it)
- React Email templates (best DX)
- Need open/click tracking
- On Vercel/Cloudflare (Resend works everywhere, no Node-only deps)

```ts
const { data, error } = await resend.emails.send({
  from: 'invoices@yourdomain.com',
  to: client.email,
  subject: 'Invoice #1042',
  html: renderedEmailHtml,
})
```

## Choose Nodemailer

When:
- Client already has Gmail / business SMTP credentials
- No third-party service wanted
- Small volume (<500 emails/month)
- Admin notifications only (not marketing)

```ts
// See plugin--nodemailer.md for full setup
await transporter.sendMail({ from, to, subject, html })
```

## Never Use

- `sendmail` CLI — not available on Vercel/Cloudflare
- Direct SMTP without authentication — marked as spam
- Marketing emails from transactional providers — violates ToS, hurts deliverability
- Client-side email sending — exposes credentials

## Transactional vs Marketing Email

Always use different domains/subdomains:

| Type | Domain | Provider |
|------|--------|---------|
| Transactional (invoices, receipts, passwords) | `invoices@yourdomain.com` | Resend transactional |
| Marketing (newsletters, campaigns) | `hello@yourdomain.com` | Resend Broadcasts |

Mixing them causes transactional emails to get filtered as marketing.

## Required DNS Records

Before sending, add to DNS (Resend adds these for you):
- `SPF` — TXT record listing authorized senders
- `DKIM` — TXT record for cryptographic signing
- `DMARC` — TXT record for policy (`p=quarantine` or `p=reject`)

Without these, emails land in spam or are rejected by major providers.

## Testing Email in Development

```ts
if (process.env.NODE_ENV === 'development') {
  // Option 1: Log instead of send
  console.log('DEV EMAIL:', { to, subject, html })
  return

  // Option 2: Only send to test email
  const safeTo = process.env.DEV_EMAIL_OVERRIDE ?? to
  await sendEmail({ to: safeTo, subject, html })
}
```

Or use Resend's test mode — emails are not delivered but appear in the Resend dashboard.

## Rate Limiting Email Sends

Always implement send rate limits to prevent accidental bulk sends:

```ts
import { Ratelimit } from '@upstash/ratelimit'

const emailRateLimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '1 h'),  // 10 emails per hour per user
})

const { success } = await emailRateLimit.limit(userId)
if (!success) throw new Error('Email rate limit exceeded')
```

## Queuing vs Sending Inline

For time-sensitive transactional email (password resets, invoice confirmations): send inline, accept ~200ms latency.

For bulk operations (invoice follow-ups, monthly summaries): queue via background job (see `batch--email-campaign-jobs.md`).

Never send bulk email in a synchronous request — blocks the response, risks timeout.
