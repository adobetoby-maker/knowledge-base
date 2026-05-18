# Skill: GDPR Data Export (Right of Access)

## Purpose
Respond to a user's Subject Access Request (SAR) by collecting all their personal data across every table, packaging it into a structured download, and delivering it via a secure, expiring link. Legally required within 30 days of request (GDPR Article 15). The failure mode is forgetting a table — maintain a data map.

## Data Map — The Critical Artifact
Before writing any code, create and maintain a data map: every table that stores personal data, which column links it to a user, and what category the data falls into (identity, behavioral, financial, content). The data map is what auditors look at. Keep it in a `data_map.ts` or similar source file so it stays in sync with the schema.

```ts
export const DATA_MAP: DataCategory[] = [
  { table: 'users', userIdCol: 'id', fields: ['email','name','phone','created_at'] },
  { table: 'orders', userIdCol: 'user_id', fields: '*' },
  { table: 'sessions', userIdCol: 'user_id', fields: ['created_at','ip_address','user_agent'] },
  { table: 'messages', userIdCol: 'sender_id', fields: ['body','created_at','recipient_id'] },
  // ...
];
```

## Exclusions
Include only the requesting user's data. Explicit exclusions:
- Other users' data — if a `messages` row has both `sender_id` and `recipient_id`, export the message for the sender's SAR but redact the recipient's identity (replace with `[user]`)
- Derived analytics aggregates — if the value can't be traced back to a specific action, omit
- Internal operational data (fraud scores, internal notes flagged confidential)
- Third-party data you don't control

## Package Structure
Generate a ZIP containing one JSON file per data category:

```
export-{userId}-{date}.zip
├── profile.json
├── orders.json
├── sessions.json
├── messages.json
├── README.txt   ← explain what each file contains in plain language
```

Use `jszip` or similar. Stream large tables — don't load 100k rows into memory. Process in 1000-row batches and append to the JSON array.

The `README.txt` is often overlooked but required: GDPR says the export must be "in a commonly used, machine-readable format" and "in an intelligible form." Plain JSON is machine-readable; the README makes it intelligible.

## Delivery: Signed URL Expiring in 24h
Never email the ZIP as an attachment. Generate a signed, time-limited URL:
- Upload the ZIP to S3/R2/Supabase Storage with a random filename (not the userId)
- Generate a presigned URL with 24-hour expiry
- Email the URL to the verified email address on the account
- Delete the file from storage when the URL expires or after download

If using Supabase Storage: `storage.from('exports').createSignedUrl(path, 86400)`.

## Background Processing
SAR exports are triggered by user request but processed async — large accounts can take minutes. Architecture:
1. User clicks "Request my data" — write a `sar_requests` row with status `pending`
2. Enqueue a background job
3. Job collects data, builds ZIP, uploads, generates signed URL, updates `sar_requests` row with URL and `completed_at`, sends email
4. Show status in the UI ("Your export is being prepared — you'll receive an email within 1 hour")

## Audit Logging
Log every SAR:
```sql
sar_requests (
  id, user_id, requested_at, completed_at,
  delivered_to_email, status, ip_address
)
```
This log is your proof of compliance. Retain for the legal minimum (typically 3 years). Log both the request and the delivery — not just one.

## Request Verification
Verify identity before exporting. For logged-in users: require re-authentication (password re-entry or email OTP). For email-only requests: send a confirmation link to the registered email. Never export to an email address that doesn't match the account.

## Key Rules
- **Maintain a data map** — it's the contract between your schema and your export code
- **Redact other users' identities** — export your user's side of a relationship, not the counterparty
- **Use signed expiring URLs** — never attach exports to email or expose via predictable paths
- **Process async** — never make the user wait synchronously for large exports
- **Verify identity before exporting** — a SAR is an attack vector if not gated
- **Log every request and delivery** — you need this for compliance audits
- **Include a README** — "machine-readable" and "intelligible" are both required
