# Twilio (SMS / Voice)

## When to Use

Twilio is used in `silver-creek-logistics` for SMS dispatch notifications. Use for:
- Dispatching drivers (automated SMS on job assignment)
- Appointment reminders
- Order status updates requiring immediate attention

Do NOT use for marketing SMS without explicit opt-in (CAN-SPAM / TCPA compliance required).

## Installation

```bash
npm install twilio
```

## Sending SMS

```typescript
// lib/twilio.ts
import Twilio from 'twilio'

const client = Twilio(
  process.env.TWILIO_ACCOUNT_SID!,
  process.env.TWILIO_AUTH_TOKEN!
)

export async function sendSMS(to: string, body: string): Promise<void> {
  await client.messages.create({
    from: process.env.TWILIO_FROM!,  // Your Twilio number: +12085551234
    to,                              // Recipient: +12085559876
    body,
  })
}
```

Always use E.164 format for phone numbers: `+1XXXXXXXXXX`.

## silver-creek-logistics Dispatch Pattern

```typescript
// lib/dispatch.ts
import { sendSMS } from './twilio'

export async function notifyDriver(driver: Driver, job: Job): Promise<void> {
  const phones = process.env.TWILIO_DISPATCH_PHONES?.split(',') ?? []
  
  const message = `
DISPATCH: ${job.type}
Customer: ${job.customerName}
Pickup: ${job.pickupAddress}
Delivery: ${job.deliveryAddress}
Time: ${formatDate(job.scheduledAt)}
Load: ${job.loadDescription}
  `.trim()

  // Send to all dispatch phones (multiple drivers)
  await Promise.all(
    phones.map(phone => sendSMS(phone.trim(), message))
  )
}
```

## Handling Delivery Failures

Twilio SMS can fail (invalid number, carrier block, rate limit). Log failures but don't block the primary operation:

```typescript
export async function sendSMSNonCritical(to: string, body: string): Promise<void> {
  try {
    await sendSMS(to, body)
  } catch (error) {
    console.error('SMS failed:', { to, error })
    // Don't throw — SMS failure shouldn't break the dispatch workflow
  }
}
```

## SMS from Cron/Worker

silver-creek-logistics has a Cloudflare Worker cron that dispatches SMS. The Worker needs the Twilio credentials as secrets:

```bash
# Set in Cloudflare dashboard or via wrangler
wrangler secret put TWILIO_ACCOUNT_SID
wrangler secret put TWILIO_AUTH_TOKEN
wrangler secret put TWILIO_FROM
```

Access in Worker:
```typescript
// cloudflare-worker/index.ts
export default {
  async scheduled(controller, env: Env) {
    const client = Twilio(env.TWILIO_ACCOUNT_SID, env.TWILIO_AUTH_TOKEN)
    // ...
  }
}

interface Env {
  TWILIO_ACCOUNT_SID: string
  TWILIO_AUTH_TOKEN: string
  TWILIO_FROM: string
}
```

## Env Vars

```
TWILIO_ACCOUNT_SID        # AC...
TWILIO_AUTH_TOKEN         # secret
TWILIO_FROM               # your Twilio phone number in E.164 format
TWILIO_DISPATCH_PHONES    # comma-separated list: +12085551234,+12085555678
```

## Testing

Use Twilio test credentials for CI/CD:
- `TWILIO_ACCOUNT_SID = AC_TEST_SID` (starts with `AC_TEST`)
- Messages sent with test credentials are not delivered but don't fail

Alternatively, skip SMS in tests by checking `NODE_ENV`:
```typescript
if (process.env.NODE_ENV === 'test') return
await sendSMS(to, body)
```

## Rate Limits

Twilio trial accounts: 1 message/second. Production: higher limits vary by carrier. For bulk sends, add a 100ms delay between messages:
```typescript
for (const phone of phones) {
  await sendSMS(phone, message)
  await new Promise(r => setTimeout(r, 100))
}
```
