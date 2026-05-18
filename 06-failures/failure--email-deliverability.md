# Failure: Emails Landing in Spam

## Why Email Is Hard to Deliver

Email providers (Gmail, Outlook, Yahoo) run reputation-based spam filters. Every email you send either builds or damages your sending reputation. The filters check DNS records, sending volume patterns, engagement rates, and content. Getting into spam is easy; getting out requires deliberate action over weeks.

The most important thing: spam filters are asymmetric. Good reputation is built slowly. Bad reputation is earned instantly (a single spam complaint from 0.1% of recipients can flag your domain).

## DNS Records That Must Be Configured

These three records are table stakes. Without them, major providers will reject or spam your email.

**SPF (Sender Policy Framework)** — TXT record on your domain that lists which mail servers are authorized to send email from it. If your email comes from a server not in the SPF record, receiving servers treat it as suspicious.

```
v=spf1 include:sendgrid.net include:_spf.google.com ~all
```

**DKIM (DomainKeys Identified Mail)** — a cryptographic signature added to every outbound email, verified against a public key in your DNS. Proves the email wasn't tampered with in transit and came from a server with access to your private key. Your email provider generates the key pair; you add the public key as a DNS TXT record on a specific subdomain they specify.

**DMARC (Domain-based Message Authentication, Reporting, and Conformance)** — tells receiving servers what to do when SPF or DKIM checks fail (none = take no action, quarantine = spam folder, reject = bounce). Also sends you aggregate reports of who's sending mail claiming to be your domain.

```
_dmarc.yourdomain.com  TXT  "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"
```

Start with `p=none` (reporting only) and move to `p=quarantine` then `p=reject` as you verify your legitimate mail is all passing SPF and DKIM.

## Why Sending From gmail.com Domain Is Blocked

Gmail applies DMARC policy on behalf of its users. If you try to send email with a `From:` address of `you@gmail.com` but your mail isn't actually coming from Google's servers, Google's DMARC policy (`p=reject`) tells receiving servers to reject it. You cannot impersonate a Gmail address from external infrastructure.

The fix: use your own domain (`hello@yourbusiness.com`) for transactional email. Set up SPF, DKIM, and DMARC for that domain.

## Using Resend/Postmark vs Raw SMTP

**Don't use raw SMTP with a new domain/IP.** New IP addresses have zero reputation. Major email providers rate-limit or block unknown senders by default. Building IP reputation from scratch requires weeks of warm-up with very low volumes.

Transactional email providers (Resend, Postmark, SendGrid, Mailgun) send from IPs with established positive reputation. Your emails inherit that reputation while you build your domain reputation separately. They also handle DKIM signing for you and provide bounce/complaint handling.

**Resend** is the simplest modern option. Add a DNS record to verify your domain, use the API:

```typescript
import { Resend } from "resend";

const resend = new Resend(process.env.RESEND_API_KEY);

await resend.emails.send({
  from: "Acme <hello@acme.com>",   // must be from your verified domain
  to: user.email,
  subject: "Your order confirmation",
  html: "<p>Thanks for your order!</p>",
});
```

**Postmark** is the industry standard for high-reliability transactional email. More expensive, better deliverability reputation, clearer bounce/complaint analytics.

## Warming Up a New Sending Domain

Even with a reputable ESP, a brand-new domain starts with no reputation. Send too much too fast and spam filters flag it. Warm up gradually:

- Week 1: 50–100 emails/day
- Week 2: 500/day
- Week 3: 5,000/day
- After: scale to volume

Only send to engaged users during warm-up (users who have recently opened or clicked). High engagement rates signal to filters that recipients want your email.

## Content and Engagement Signals

- **Avoid spam trigger words** in subject lines: "FREE," "URGENT," "Act now," excessive caps.
- **Include a plaintext version** alongside HTML — HTML-only emails score worse.
- **Include an unsubscribe link** — legally required in many jurisdictions (CAN-SPAM, GDPR); its absence also signals spam.
- **Monitor bounce rates** — remove hard-bounced addresses immediately; high bounce rates tank reputation.
- **Watch complaint rates** — if more than 0.1% of recipients mark you as spam in Gmail Postmaster Tools, you have a problem.

## Key Rules

- **SPF + DKIM + DMARC are mandatory** — configure all three before sending production email.
- **Never send from a `@gmail.com` or `@yahoo.com` From address** — use your own domain.
- **Use an ESP (Resend, Postmark, SendGrid)** — raw SMTP from a new IP goes to spam.
- **Warm up new domains gradually** — start at 50–100 emails/day, scale over weeks.
- **Set up Google Postmaster Tools** for your domain — it shows your spam rate and domain reputation score.
- **Remove hard bounces immediately** — accumulating bounced addresses signals a dirty list to providers.
- **Test with mail-tester.com before launch** — it scores your email's spamminess before you send to real users.
