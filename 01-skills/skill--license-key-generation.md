# Skill: License Key Generation and Validation

## Overview
License keys authenticate software entitlements without requiring a server round-trip for every startup (offline validation). Storing only the hash of a key means a database breach doesn't hand attackers a list of valid keys. The activation count limit prevents seat sharing. Revocation must work even for offline-validated keys.

## Implementation / Key Points

### Key Generation (CSPRNG)
```ts
import { randomBytes, createHash, createSign } from 'crypto';

function generateLicenseKey(): string {
  // 20 random bytes → 40 hex chars → formatted as XXXX-XXXX-XXXX-XXXX-XXXX
  const raw = randomBytes(20).toString('hex').toUpperCase();
  return raw.match(/.{4}/g)!.join('-');
  // e.g. "A3F9-2B7E-C041-9D83-1F6A"
}
```
Never use `Math.random()` — it is not cryptographically secure and can be predicted.

### Storing the Key (Hash Only)
```ts
async function storeKey(key: string, customerId: string, plan: string) {
  const hash = createHash('sha256').update(key).digest('hex');
  await db.licenses.create({
    keyHash: hash,         // store only this — never the plaintext key
    customerId,
    plan,
    activations: 0,
    maxActivations: 2,     // seat limit
    expiresAt: addYears(new Date(), 1),
    revokedAt: null,
  });
}
```
Deliver the plaintext key to the customer once (email or download page). After that, you only need the hash.

### Online Validation Endpoint
```ts
// POST /api/licenses/validate
async function validateLicense(key: string, machineId: string) {
  const hash = createHash('sha256').update(key).digest('hex');
  const license = await db.licenses.findByHash(hash);

  if (!license) return { valid: false, reason: 'not_found' };
  if (license.revokedAt) return { valid: false, reason: 'revoked' };
  if (license.expiresAt < new Date()) return { valid: false, reason: 'expired' };
  if (license.activations >= license.maxActivations) {
    // Check if this machineId is already activated
    const existing = await db.activations.find({ licenseHash: hash, machineId });
    if (!existing) return { valid: false, reason: 'seat_limit_reached' };
  }

  // Register activation if new machine
  await db.activations.upsert({ licenseHash: hash, machineId, activatedAt: new Date() });
  return { valid: true, plan: license.plan, expiresAt: license.expiresAt };
}
```

### Offline Validation via RSA Signature
```ts
// At key generation time, create a signed license payload:
function signLicense(payload: LicensePayload, privateKey: string): string {
  const data = JSON.stringify(payload);
  const sign = createSign('RSA-SHA256');
  sign.update(data);
  const signature = sign.sign(privateKey, 'base64');
  return Buffer.from(JSON.stringify({ data, signature })).toString('base64');
}

// In the client application (offline check):
function verifyOfflineLicense(token: string, publicKey: string): LicensePayload | null {
  const { data, signature } = JSON.parse(Buffer.from(token, 'base64').toString());
  const verify = createVerify('RSA-SHA256');
  verify.update(data);
  const valid = verify.verify(publicKey, signature, 'base64');
  if (!valid) return null;
  const payload: LicensePayload = JSON.parse(data);
  if (new Date(payload.expiresAt) < new Date()) return null;
  return payload;
}
```
Embed the public key in the application binary. Keep the private key off all production servers.

### Revocation List
Offline-validated keys cannot be "un-signed," so maintain a revocation list distributed via CDN:
```ts
// https://cdn.yourapp.com/licenses/revoked.json — updated on revocation
// Application downloads this list periodically (e.g., every 24h)
const revokedList: string[] = await fetchRevocationList();  // array of key hashes
if (revokedList.includes(licenseHash)) refuse();
```

## Key Rules
- Use `crypto.randomBytes` (Node) or `crypto.getRandomValues` (browser) — never `Math.random`.
- Store only SHA-256 hash of the key; the plaintext key is never stored after delivery.
- Validate hash + expiry + activation count on every online check.
- Offline validation requires RSA signature with an embedded public key.
- Revocation list must be checked even for offline-validated keys.
- Machine ID should be derived from hardware fingerprint, not user-changeable values.
- Activation count resets on purchase of additional seats, not on support request.
