# ADR: Silver Creek Logistics — Architecture and Integrations

**Project:** silver-creek-logistics
**Path:** `/Users/drive/silver-creek-logistics/`
**Deployed:** silvercreeklogistics.worker-bee.app

## Stack

Next.js 16 + Supabase + Twilio (SMS dispatch) + QuickBooks API + Cloudflare Worker cron

## Auth — Same Dual System as JRS

Two completely separate auth systems (see `adr--dual-auth-why.md`):
- **Admin** `/admin/*` — cookie `admin_session`, `ADMIN_SECRET`, `lib/adminAuth.ts`, `data/admins.json`
- **Portal** `/portal/*` — Supabase JWT, `proxy.ts` refreshes sessions
- Never import one into the other's routes.

## Admin Routes

`/admin/crm` — customer relationship management
`/admin/clients` — client list and detail
`/admin/invoices` — invoice creation and management
`/admin/dispatch` — freight dispatch interface
`/admin/marketing` — marketing tools
`/admin/settings` — system configuration

## Portal Routes (Customer-Facing)

`/portal/dashboard` — customer load tracking
`/portal/invoices` — customer invoice view

## Public Routes

`/(site)/` — marketing pages
`/invoice/[id]` — public token-based invoice view (no auth required)
`/(site)/calculator` — freight quote calculator
`/(site)/order` — order submission

## Cloudflare Worker — Dispatch Cron

`cloudflare-worker/` contains `silvercreek-dispatch` worker.
- Runs on a 30-minute cron schedule
- Handles dispatch automation (driver assignment, SMS notifications)
- `CRON_SECRET` must match between Vercel env and Cloudflare Worker dashboard env
- If crons stop firing, check both places — they're separate deployments

Vercel also has a daily cron at `/api/cron/dispatch` in `vercel.json`. Two cron systems:
- **Cloudflare Worker**: 30-min interval, dispatch-critical real-time tasks
- **Vercel cron**: daily, lower-priority batch tasks (summaries, cleanup)

## Twilio SMS Dispatch

```
TWILIO_ACCOUNT_SID
TWILIO_AUTH_TOKEN
TWILIO_FROM           # The sending phone number
TWILIO_DISPATCH_PHONES # Comma-separated list of driver phones
```

Driver phones are in `TWILIO_DISPATCH_PHONES` env var as a comma-separated string — not in the database. This means adding/removing dispatch numbers requires an env var update + redeployment. It's intentional for a small fleet (5-10 drivers).

SMS fires when: a load is assigned, a pickup is confirmed, a delivery ETA changes.

## QuickBooks Integration

```
QB_CLIENT_ID
QB_CLIENT_SECRET
QB_REDIRECT_URI
QB_ENVIRONMENT    # "sandbox" | "production"
```

OAuth2 flow — the app has a QuickBooks OAuth callback route that stores refresh tokens in Supabase. The token refresh is handled automatically on API calls. If `QB_ENVIRONMENT=sandbox`, all QuickBooks calls hit their sandbox endpoint — never accidentally bill real customers from dev.

Invoice sync: when an invoice is created in the admin, it syncs to QuickBooks via their API. The Supabase `invoices` table stores a `qb_invoice_id` column to track the mapping.

## Static Data

- `lib/shopInfo.ts` — business info (same pattern as JRS)
- `lib/materials.ts` — freight material types and hazmat classifications
- `lib/drivers.ts` — driver list with truck numbers (internal reference, not auth)

## Gmail Integration

```
GMAIL_USER
GMAIL_APP_PASSWORD
```

Email notifications for: new order submissions, dispatch confirmations, invoice delivery.
Uses nodemailer with Gmail app password (not OAuth). App password is generated in Google account security settings — this is intentional: simpler than OAuth for outbound-only notification email.
