# Skill: Two-Way SMS (Inbound + Outbound)

## Overview
Two-way SMS requires more than just sending messages: you must handle inbound replies, normalize phone numbers for consistent thread tracking, route messages to the right user or conversation, and handle compliance requirements (STOP opt-out) automatically. Missing opt-out handling is a legal liability in the US and most countries. Missing phone normalization causes "ghost threads" where the same person appears as multiple contacts.

## Implementation

### Phone Number Normalization (E.164)
All phone numbers must be stored and compared in E.164 format (`+15551234567`). Inconsistent formats break thread matching.

```ts
import { parsePhoneNumber, isValidPhoneNumber } from 'libphonenumber-js';

export function normalizePhone(raw: string, defaultCountry = 'US'): string | null {
  try {
    if (!isValidPhoneNumber(raw, defaultCountry)) return null;
    const parsed = parsePhoneNumber(raw, defaultCountry);
    return parsed.format('E.164'); // e.g., "+15551234567"
  } catch {
    return null;
  }
}
```

### Twilio Inbound Webhook
Twilio sends a POST to your webhook when a message arrives:

```ts
// POST /api/sms/inbound
import twilio from 'twilio';

export async function POST(req: Request) {
  const body = await req.formData();

  // Validate Twilio signature
  const signature = req.headers.get('X-Twilio-Signature') ?? '';
  const url = `${BASE_URL}/api/sms/inbound`;
  const params = Object.fromEntries(body.entries()) as Record<string, string>;

  const valid = twilio.validateRequest(
    process.env.TWILIO_AUTH_TOKEN!,
    signature,
    url,
    params
  );
  if (!valid) return new Response('Forbidden', { status: 403 });

  const from = normalizePhone(params.From);
  const to = normalizePhone(params.To);
  const messageBody = params.Body?.trim() ?? '';
  const sid = params.MessageSid;

  if (!from || !to) {
    return new Response('<Response/>', { headers: { 'Content-Type': 'text/xml' } });
  }

  // Handle opt-out keywords immediately (STOP, STOPALL, UNSUBSCRIBE, CANCEL, END, QUIT)
  const OPT_OUT_KEYWORDS = ['STOP', 'STOPALL', 'UNSUBSCRIBE', 'CANCEL', 'END', 'QUIT'];
  if (OPT_OUT_KEYWORDS.includes(messageBody.toUpperCase())) {
    await db.smsOptOuts.upsert({ phone: from }, { updated_at: new Date() });
    // Twilio handles the compliance reply automatically; return empty TwiML
    return new Response('<Response/>', { headers: { 'Content-Type': 'text/xml' } });
  }

  // Handle opt-in keywords
  if (['START', 'YES', 'UNSTOP'].includes(messageBody.toUpperCase())) {
    await db.smsOptOuts.destroy({ where: { phone: from } });
    return new Response('<Response/>', { headers: { 'Content-Type': 'text/xml' } });
  }

  // Look up user by phone number
  const user = await db.users.findOne({ where: { phone: from } });

  if (!user) {
    // Unknown sender — log but don't respond to avoid spam loops
    await db.unknownSmsMessages.create({ from, to, body: messageBody, sid });
    return new Response('<Response/>', { headers: { 'Content-Type': 'text/xml' } });
  }

  // Store message in conversation thread
  await db.smsMessages.create({
    userId: user.id,
    direction: 'inbound',
    from,
    to,
    body: messageBody,
    twilioSid: sid,
  });

  // Route to relevant handler
  await routeInboundMessage(user, messageBody);

  // Return empty TwiML to acknowledge (Twilio requires 200 with TwiML or empty)
  return new Response('<Response/>', {
    status: 200,
    headers: { 'Content-Type': 'text/xml' },
  });
}
```

### Sending Outbound SMS
Always check opt-out before sending:

```ts
import twilio from 'twilio';

const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

export async function sendSMS(to: string, body: string, fromNumber?: string) {
  const normalizedTo = normalizePhone(to);
  if (!normalizedTo) throw new Error(`Invalid phone number: ${to}`);

  // Compliance: check opt-out
  const optedOut = await db.smsOptOuts.findOne({ where: { phone: normalizedTo } });
  if (optedOut) {
    throw new Error(`Phone ${normalizedTo} has opted out`);
  }

  const message = await twilioClient.messages.create({
    to: normalizedTo,
    from: fromNumber ?? process.env.TWILIO_FROM_NUMBER,
    body,
  });

  // Log outbound message
  await db.smsMessages.create({
    direction: 'outbound',
    to: normalizedTo,
    from: fromNumber ?? process.env.TWILIO_FROM_NUMBER!,
    body,
    twilioSid: message.sid,
    status: message.status,
  });

  return message.sid;
}
```

### Conversation Thread by Phone Number
```ts
export async function getConversationThread(userId: string, limit = 50) {
  const user = await db.users.findById(userId);
  return db.smsMessages.findAll({
    where: { userId },
    order: [['created_at', 'DESC']],
    limit,
  });
}
```

## Key Rules
- Normalize all phone numbers to E.164 on ingest — never store raw user-entered formats.
- Handle STOP/UNSUBSCRIBE/CANCEL/END/QUIT keywords unconditionally and immediately — this is a legal requirement under TCPA.
- Validate the Twilio webhook signature on every inbound request — unauthenticated webhooks allow SMS spoofing.
- Return empty TwiML (`<Response/>`) for messages you don't want to respond to — a 200 with no TwiML is valid; a non-200 response causes Twilio to retry.
- Log every outbound and inbound message with Twilio SID for debugging and compliance audits.
- Never respond to unrecognized senders with content — it looks like a spam bot and may trigger carrier filtering.
- Check opt-out status before every send, not just on subscription — users may opt out between sends.
