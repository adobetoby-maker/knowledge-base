# Silver Creek Logistics — Project Bundle

## What It Is

Silver Creek Logistics is a freight and delivery company site. It has a marketing/public site, a customer portal for tracking and invoices, and an admin panel for dispatch management.

Path: `/Users/drive/silver-creek-logistics`
Deployed: silvercreeklogistics.worker-bee.app

## Stack

- **Next.js 15** (App Router) + **React 19**
- **Supabase** (PostgreSQL + Auth)
- **Vercel** deployment
- **Cloudflare Worker** for dispatch automation (`cloudflare-worker/`)
- **Twilio** for SMS dispatch notifications
- **QuickBooks** integration for invoicing
- **Gmail** for email notifications

## Auth Architecture (SAME AS jrs-auto-repair — Two Systems)

**NEVER mix these:**

| System | Cookie | Users source | Protects |
|--------|--------|-------------|---------|
| Admin | `admin_session` | `data/admins.json` | `/admin/*` |
| Portal | Supabase JWT | Supabase auth.users | `/portal/*` |

Admin auth: `lib/adminAuth.ts` — validates `admin_session` cookie against `data/admins.json`
Portal auth: Supabase JWT — `lib/supabase/server.ts` reads session cookie, `getUser()` for auth check

## Three Supabase Clients

```typescript
lib/supabase/client.ts   // browser-only (portal client components)
lib/supabase/server.ts   // Server Components + Route Handlers (portal)
lib/supabase/admin.ts    // service role — admin panel + background jobs
```

NEVER import `admin.ts` in any client-side code. NEVER use `getSession()` — always `getUser()`.

## Route Structure

```
app/
  (site)/                    # Public marketing pages
    page.tsx                 # Homepage
    calculator/              # Freight calculator
    order/                   # Place an order
  admin/                     # Admin panel (cookie auth)
    crm/                     # Customer management
    clients/                 # Client list
    invoices/                # Invoice management
    dispatch/                # Dispatch management
    marketing/               # Marketing tools
    settings/                # Config
  portal/                    # Customer portal (Supabase auth)
    dashboard/
    invoices/
  invoice/[id]/              # Public invoice view (token-based, no auth)
  api/
    auth/                    # Auth routes
    invoices/                # Invoice CRUD
    dispatch/                # Dispatch operations
    cron/dispatch            # Daily dispatch cron
```

## Cloudflare Worker

The `cloudflare-worker/` directory contains `silvercreek-dispatch` — a Cloudflare Worker that runs on a 30-minute cron to handle dispatch automation.

`CRON_SECRET` must match between Vercel and Cloudflare dashboard for security.

Both `vercel.json` (daily cron at `/api/cron/dispatch`) and the Cloudflare Worker run dispatch jobs.

## Integrations

### Twilio SMS
```
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM=         # Twilio phone number
TWILIO_DISPATCH_PHONES= # comma-separated dispatcher numbers
```

### QuickBooks
```
QB_CLIENT_ID=
QB_CLIENT_SECRET=
QB_REDIRECT_URI=
QB_ENVIRONMENT=sandbox|production
```

### Gmail SMTP
```
GMAIL_USER=
GMAIL_APP_PASSWORD=  # App password (not account password)
```

## Static Data Files

```typescript
lib/shopInfo.ts    # Business info
lib/materials.ts   # Freight materials catalog
lib/drivers.ts     # Driver list
```

## All Env Vars

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
ADMIN_SECRET=
ANTHROPIC_API_KEY=
CRON_SECRET=
GMAIL_USER=
GMAIL_APP_PASSWORD=
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM=
TWILIO_DISPATCH_PHONES=
QB_CLIENT_ID=
QB_CLIENT_SECRET=
QB_REDIRECT_URI=
QB_ENVIRONMENT=
```

## Dev Commands

```bash
cd /Users/drive/silver-creek-logistics
npm run dev        # localhost:3000
npm run build
npm run lint

# Cloudflare Worker (from cloudflare-worker/ directory)
wrangler dev       # local Worker dev
wrangler deploy    # deploy Worker
```

## Critical Rules

1. `/admin/*` uses cookie auth — do NOT check Supabase auth
2. `/portal/*` uses Supabase JWT — do NOT check admin cookie
3. Public invoice URLs use a `public_token` column — no auth required
4. Cron endpoint (`/api/cron/dispatch`) validates `CRON_SECRET` header
5. Twilio SMS only sent for active dispatches — check status before sending
