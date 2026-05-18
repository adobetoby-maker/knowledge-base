# Project: silver-creek-logistics

**Path:** `/Users/drive/silver-creek-logistics/`
**Deployed:** `silvercreeklogistics.worker-bee.app`
**Stack:** Next.js 16, Supabase, Twilio, QuickBooks

## Commands
```bash
npm run dev     # localhost:3000
npm run build
npm run lint
# Cloudflare Worker deployed separately — see cloudflare-worker/
```

## Auth — Two Systems (Same as JR's)
1. **Admin** (`/admin`) — cookie `admin_session`, `lib/adminAuth.ts`
2. **Portal** (`/portal`) — Supabase JWT

## Route Structure
```
/admin/crm          /admin/clients      /admin/invoices
/admin/dispatch     /admin/marketing    /admin/settings
/portal/dashboard   /portal/invoices
/(site)/            — public marketing pages
/invoice/[id]       — public invoice (shared via token)
/(site)/calculator  /(site)/order
```

## Cloudflare Worker (`cloudflare-worker/`)
Worker name: `silvercreek-dispatch`
Runs on 30-min cron for dispatch automation.
`CRON_SECRET` must match between Vercel env vars AND Cloudflare dashboard.
`vercel.json` also has daily cron at `/api/cron/dispatch`.

## Static Data Files
- `lib/shopInfo.ts` — business info
- `lib/materials.ts` — freight materials list
- `lib/drivers.ts` — driver roster

## Env Vars
```
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
ADMIN_SECRET
ANTHROPIC_API_KEY
CRON_SECRET                    # shared: Vercel + Cloudflare Worker
GMAIL_USER / GMAIL_APP_PASSWORD # email notifications
TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN / TWILIO_FROM / TWILIO_DISPATCH_PHONES
QB_CLIENT_ID / QB_CLIENT_SECRET / QB_REDIRECT_URI / QB_ENVIRONMENT
```

## Key Patterns
Same dual-auth + Supabase pattern as jrs-auto-repair.
Supabase three-client pattern applies: client.ts / server.ts / admin.ts.
Cloudflare Worker is a separate deploy — `wrangler deploy` from `cloudflare-worker/`.
QuickBooks integration: OAuth flow, token refresh in `lib/quickbooks.ts`.
