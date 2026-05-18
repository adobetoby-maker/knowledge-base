# Twilio SMS

## Stack Context

Twilio SMS is used in `silver-creek-logistics` for dispatch notifications — alerting drivers when new loads are available.

## Setup

```bash
npm install twilio
```

```typescript
// lib/twilio.ts
import twilio from 'twilio'

let _client: twilio.Twilio | null = null

function getClient() {
  if (_client) return _client
  _client = twilio(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_AUTH_TOKEN
  )
  return _client
}

export { getClient as getTwilioClient }
```

Lazy init avoids build-time crash if env vars aren't set.

## Sending a Single SMS

```typescript
// lib/sms.ts
import { getTwilioClient } from './twilio'

export async function sendSMS(to: string, body: string): Promise<void> {
  const client = getTwilioClient()
  
  await client.messages.create({
    from: process.env.TWILIO_FROM,  // your Twilio number
    to,
    body,
  })
}
```

## Phone Number Format

All phone numbers must be in E.164 format: `+12085551234` (country code + area code + number, no dashes).

```typescript
function formatE164(phone: string): string {
  // Remove all non-digits:
  const digits = phone.replace(/\D/g, '')
  
  // Assume US if 10 digits:
  if (digits.length === 10) return `+1${digits}`
  
  // Already has country code (11 digits for US):
  if (digits.length === 11 && digits.startsWith('1')) return `+${digits}`
  
  throw new Error(`Invalid phone number: ${phone}`)
}
```

## Dispatch Notification (silver-creek pattern)

```typescript
// lib/dispatch.ts
const DISPATCH_PHONES = process.env.TWILIO_DISPATCH_PHONES?.split(',') ?? []

export async function notifyDrivers(load: LoadRecord): Promise<void> {
  const message = [
    `NEW LOAD AVAILABLE`,
    `From: ${load.originCity}, ${load.originState}`,
    `To: ${load.destCity}, ${load.destState}`,
    `Weight: ${load.weightLbs} lbs`,
    `Date: ${format(new Date(load.pickupDate), 'MM/dd')}`,
    `Reply ACCEPT ${load.id.slice(0, 8)} to claim`,
  ].join('\n')
  
  // Send to all dispatch phones in parallel:
  await Promise.allSettled(
    DISPATCH_PHONES.map(phone => sendSMS(formatE164(phone), message))
  )
}
```

Use `Promise.allSettled` not `Promise.all` — if one phone fails, the others still get the message.

## Receiving SMS (Webhook)

```typescript
// app/api/sms/route.ts
import { URLSearchParams } from 'url'
import twilio from 'twilio'

export async function POST(request: Request) {
  // Verify Twilio signature:
  const authToken = process.env.TWILIO_AUTH_TOKEN!
  const signature = request.headers.get('X-Twilio-Signature') ?? ''
  const url = process.env.TWILIO_WEBHOOK_URL!
  
  const body = await request.text()
  const params = Object.fromEntries(new URLSearchParams(body))
  
  const isValid = twilio.validateRequest(authToken, signature, url, params)
  if (!isValid) return new Response('Unauthorized', { status: 403 })
  
  const from = params.From  // sender's phone number
  const messageBody = params.Body?.trim().toUpperCase()
  
  // Handle ACCEPT command:
  if (messageBody?.startsWith('ACCEPT ')) {
    const loadId = messageBody.split(' ')[1]
    await assignLoadToDriver(loadId, from)
  }
  
  // Twilio expects TwiML response:
  return new Response('<Response></Response>', {
    headers: { 'Content-Type': 'text/xml' },
  })
}
```

Always validate the Twilio signature — the webhook endpoint is public and can receive spoofed requests.

## Environment Variables

```
TWILIO_ACCOUNT_SID=AC...
TWILIO_AUTH_TOKEN=...
TWILIO_FROM=+12085551234          # your Twilio phone number
TWILIO_DISPATCH_PHONES=+12085551111,+12085552222  # comma-separated list
TWILIO_WEBHOOK_URL=https://your-domain.com/api/sms  # for signature validation
```

## Cost Management

Each SMS costs ~$0.0079 (US domestic). For dispatch use cases with small driver pools this is trivial. For larger volumes, consider:
- Batch sending during off-peak hours
- Opt-out tracking (STOP keywords) — required by law
- Using a single number for all notifications rather than per-driver numbers
