# Phone Number / SMS Authentication

Phone auth is a second factor or passwordless login. It proves the user physically controls a phone number at the time of verification. It doesn't prove identity — SIM swapping and SS7 attacks exist — but it's sufficient for most applications and much better than nothing.

## Twilio Verify vs Manual OTP

**Use Twilio Verify (or equivalent managed service) by default.** Managed verification services handle:
- OTP generation and storage (you never touch the code)
- SMS delivery with fallback providers
- Automatic expiry
- Regional carrier relationships
- Brute-force protection built in
- VOIP/landline detection

Manual OTP (generate code, store in DB, send via Twilio SMS directly) is only worth building if you need custom code length, custom expiry, or multi-channel delivery (SMS + WhatsApp fallback) that the managed service doesn't support. The engineering cost of doing it right (rate limiting, secure storage, expiry, delivery tracking) is non-trivial.

## E.164 Format

Store and transmit phone numbers in E.164 format: `+{country_code}{number}`, no spaces, no dashes, no parentheses. Example: `+12085552101`.

Why: E.164 is the format SMS providers expect. Storing in any other format requires conversion at send time, and inconsistent formats cause duplicate accounts when the same number is entered different ways.

Normalize on input using a library like `libphonenumber-js`:

```ts
import { parsePhoneNumber } from 'libphonenumber-js';
const phone = parsePhoneNumber(rawInput, 'US'); // default country for local numbers
if (!phone.isValid()) throw new Error('Invalid phone number');
const e164 = phone.format('E.164'); // "+12085552101"
```

Do not assume a default country — require the user to select country code or enter `+` prefix.

## OTP Specifics

- **6 digits** — standard expectation. 4 digits is too guessable; 8 digits creates friction with no security benefit.
- **10-minute expiry** — enough time for SMS delivery in poor network conditions; short enough to limit the attack window.
- **Single use** — invalidate the code immediately on successful verification, not at expiry.
- **Hash the code in storage** — if building manual OTP, store `sha256(code + salt)`, not the plaintext code. If the DB is compromised, stored codes can't be used.

## Rate Limiting Per Phone Number

Rate limit aggressively at the phone number level to prevent SMS bombing (using your app to spam arbitrary phone numbers) and brute-forcing codes:

- **Send rate**: 3 OTP sends per phone number per hour. A legitimate user entering a wrong number by mistake won't hit this; an attacker will.
- **Verify attempts**: 5 incorrect attempts per code before the code is invalidated. Regenerate only after the rate limit window resets.
- **Global send rate**: Cap total outbound SMS per minute to prevent abuse in bulk.

Implement rate limiting in Redis with sliding window counters, not in your database. DB-based rate limiting can't keep up with concurrent requests.

## Regional SMS Restrictions

Certain countries block or heavily filter SMS from foreign numbers. China, India, some Middle Eastern countries have strict regulations. Users in these regions may never receive codes sent via US/EU numbers.

Mitigations:
- Use a provider (Twilio, Vonage) that offers local sender IDs per region
- Offer WhatsApp OTP as fallback in restricted regions (WhatsApp delivery is less blocked)
- Clearly communicate to users if SMS isn't supported in their country

Never build a product that silently fails to deliver OTPs in certain countries — implement delivery status tracking and surface errors clearly.

## Key Rules

- Use a managed OTP service (Twilio Verify) unless you have a specific reason to build manual OTP
- Normalize all phone numbers to E.164 on input before storage or sending
- 6-digit codes, 10-minute expiry, single use, invalidated on first successful verification
- Rate limit: 3 sends/hour/number, 5 failed verify attempts before invalidation
- Hash codes at rest if storing manually; never store plaintext OTPs
- Test delivery in target regions during development; don't assume global deliverability
- Offer WhatsApp fallback for high-restriction regions
