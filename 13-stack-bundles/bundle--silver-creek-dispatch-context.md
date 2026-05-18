# Stack Bundle: Silver Creek Logistics Dispatch Context

## Purpose

Compact context for the dispatch automation system in silver-creek-logistics. Load for batch jobs or agents working on dispatch features.

## Business

```
Business: Silver Creek Logistics
Site: silvercreeklogistics.worker-bee.app
Stack: Next.js 16, Supabase, Twilio, QuickBooks
Path: /Users/drive/silver-creek-logistics
```

## Dispatch Architecture

### Cloudflare Worker Cron (`cloudflare-worker/`)

The `silvercreek-dispatch` Worker runs on a 30-min cron. It handles automated dispatch:
- Reads pending orders from Supabase
- Assigns drivers based on availability and location
- Sends SMS via Twilio to assigned drivers
- Updates order status in DB

```typescript
// cloudflare-worker/src/index.ts pattern:
export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(runDispatch(env))  // async, doesn't block response
  }
}
```

### Vercel Cron Fallback (`api/cron/dispatch`)

Daily cron at `/api/cron/dispatch` as fallback:
```typescript
// Verify secret matches:
const authHeader = req.headers.get('authorization')
if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
  return Response.json({ error: 'Unauthorized' }, { status: 401 })
}
```

`CRON_SECRET` must match between Vercel environment and Cloudflare Worker secret.

## Auth Systems (Two — Never Mix)

Same pattern as jrs-auto-repair:
- `/admin/*` — cookie auth via `lib/adminAuth.ts`, cookie name `admin_session`
- `/portal/*` — Supabase JWT for driver/customer portal

## Database Schema (Key Tables)

```sql
-- Orders table:
orders (
  id uuid primary key,
  status text,  -- 'pending' | 'assigned' | 'in_transit' | 'delivered' | 'cancelled'
  customer_id uuid,
  driver_id uuid,
  pickup_address text,
  delivery_address text,
  scheduled_date date,
  notes text,
  created_at timestamptz
)

-- Drivers table:
drivers (
  id uuid primary key,
  name text,
  phone text,  -- E.164 format: +12085551234
  status text,  -- 'available' | 'on_route' | 'off_duty'
  vehicle_type text
)
```

## Twilio Integration

Phone numbers MUST be in E.164 format before sending SMS:

```typescript
// lib/twilio.ts
import twilio from 'twilio'

const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN)

export async function sendDispatchSMS(to: string, message: string): Promise<void> {
  // Validate E.164:
  if (!/^\+1\d{10}$/.test(to)) {
    console.error(`Invalid phone format: ${to}`)
    return  // don't throw — SMS is non-critical
  }
  
  try {
    await client.messages.create({
      from: process.env.TWILIO_FROM,
      to,
      body: message,
    })
  } catch (error) {
    // SMS failure is non-critical — log but don't crash dispatch
    console.error('SMS send failed:', error)
  }
}
```

SMS failures are logged but never thrown — they should not fail the dispatch job.

## QuickBooks Integration

OAuth 2.0 with short-lived tokens (1 hour TTL):

```typescript
// lib/quickbooks.ts
// Tokens expire after 1 hour — always refresh before use
// Refresh tokens expire after 100 days — store in DB, never in memory
// Sandbox: sandbox-quickbooks.api.intuit.com
// Production: quickbooks.api.intuit.com
```

Environment: `QB_ENVIRONMENT` must be `'sandbox'` in dev, `'production'` in prod.

## Static Data Files

```typescript
lib/shopInfo.ts    // business contact info
lib/materials.ts   // freight material types for calculator
lib/drivers.ts     // driver roster (supplement to DB)
```

Never create markdown files for content — all static data is TypeScript arrays.

## Environment Variables

```
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
ADMIN_SECRET
ANTHROPIC_API_KEY
CRON_SECRET                    # shared with Cloudflare Worker
GMAIL_USER / GMAIL_APP_PASSWORD
TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN / TWILIO_FROM / TWILIO_DISPATCH_PHONES
QB_CLIENT_ID / QB_CLIENT_SECRET / QB_REDIRECT_URI / QB_ENVIRONMENT
```
