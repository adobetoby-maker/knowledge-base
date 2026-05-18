# Project: SaaS MVP Launch Checklist

## Overview
A SaaS MVP must prove the core value proposition while providing the scaffolding that real customers require: authentication they trust, billing that actually charges, and the minimum workflow that demonstrates the product works. Launching without billing or auth is a demo, not an MVP. Launching with broken billing is worse than no billing.

## Authentication

- [ ] Sign up (email + password, or OAuth provider)
- [ ] Sign in
- [ ] Sign out
- [ ] Password reset (email flow)
- [ ] Email verification on signup
- [ ] Session management (persistent login with secure token refresh)
- [ ] Route protection (authenticated vs public routes)
- [ ] Auth state persistence across page refresh

## Billing Integration

- [ ] Stripe (or equivalent) customer created on signup
- [ ] At least two plans: free/trial + paid
- [ ] Checkout flow (plan selection → payment → success redirect)
- [ ] Webhook handling: `payment_intent.succeeded`, `invoice.payment_failed`, `customer.subscription.deleted`
- [ ] Subscription status visible to user (current plan, next billing date)
- [ ] Upgrade/downgrade flow
- [ ] Cancellation (end-of-period, not immediate unless requested)
- [ ] Payment failed handling: email notification + grace period + downgrade to free

## User Management

- [ ] User profile (name, email, avatar)
- [ ] Account settings page
- [ ] Email change with re-verification
- [ ] Password change (authenticated)
- [ ] Account deletion (GDPR requirement — must have it)
- [ ] If multi-user: invite team member, assign role, remove member

## Usage Limits

- [ ] Define limits per plan (seats, API calls, storage, etc.)
- [ ] Enforce limits in the backend (not just UI)
- [ ] Limit reached UX: helpful message + upgrade prompt
- [ ] Admin override mechanism (for support)

## Email Notifications

- [ ] Welcome email on signup
- [ ] Email verification
- [ ] Password reset
- [ ] Payment successful receipt
- [ ] Payment failed alert (with retry link)
- [ ] Subscription cancelled confirmation
- [ ] Trial expiring reminder (D-7, D-1)

## Analytics (Minimum)

- [ ] Signup count (by day)
- [ ] Active users (daily/monthly)
- [ ] Conversion rate (trial → paid)
- [ ] Churn rate
- [ ] Revenue (MRR, ARR)

## Error Handling + Observability

- [ ] Error tracking (Sentry or equivalent) — crash reports with context
- [ ] Failed background jobs alerted (not silently swallowed)
- [ ] Basic health check endpoint

## Security

- [ ] HTTPS everywhere
- [ ] Passwords hashed (bcrypt/argon2 — never stored plaintext)
- [ ] Rate limiting on auth endpoints (prevents brute force)
- [ ] CSRF protection on state-changing requests
- [ ] Secrets in environment variables (never in code)

## Legal / Compliance

- [ ] Terms of Service page
- [ ] Privacy Policy page
- [ ] Cookie consent (if using tracking in jurisdictions requiring it)
- [ ] Data deletion mechanism (GDPR Art. 17)

## Key Rules

- Billing webhooks must be idempotent — Stripe may send the same event twice
- Enforce limits server-side, not just in UI — clients can be modified
- Account deletion must delete or anonymize all PII — GDPR is enforceable outside the EU
- Test the payment failure path explicitly before launch — it's the path that breaks
- Onboarding email sequence is not optional — users who don't activate in 48h rarely return
