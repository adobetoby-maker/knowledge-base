# Passkey / WebAuthn Authentication

## Why Passkeys Beat Passwords

Passkeys are phishing-resistant by design — the credential is scoped to the exact origin (`example.com`) via the Relying Party ID, so a clone site (`examp1e.com`) can never trigger a valid assertion. The private key never leaves the device; the server only stores a public key. Biometric unlock is local; no biometric data is ever transmitted.

## Registration Flow

```
Browser → navigator.credentials.create(options) → Authenticator → signed credential
```

1. Server generates a random 32-byte challenge, stores it in session (TTL: 5 min).
2. Browser calls `navigator.credentials.create({ publicKey: { challenge, rp, user, pubKeyCredParams, authenticatorSelection } })`.
3. Authenticator generates a key pair, stores private key in secure enclave, returns `AuthenticatorAttestationResponse`.
4. Send `credential.id`, `credential.rawId` (base64url), `response.attestationObject`, `response.clientDataJSON` to server.
5. Server verifies with `@simplewebauthn/server` → `verifyRegistrationResponse()`. On success, store credential.

**Don't skip `authenticatorSelection`**: set `residentKey: "required"` and `userVerification: "required"` to ensure passkey (not just security key) behaviour.

## Credential Storage Schema

```sql
create table passkeys (
  id            text primary key,   -- base64url credential ID
  user_id       uuid not null references users(id),
  public_key    bytea not null,     -- COSE-encoded public key
  counter       integer not null default 0,
  device_type   text,               -- "platform" | "cross-platform"
  backed_up     boolean default false,
  created_at    timestamptz default now(),
  last_used_at  timestamptz
);
```

The `counter` field is critical — increment it on every authentication and reject any assertion with a counter ≤ stored value. This detects cloned authenticators.

## Authentication Flow

```
Browser → navigator.credentials.get(options) → Authenticator → signed assertion
```

1. Server generates new challenge, stores in session.
2. Browser calls `navigator.credentials.get({ publicKey: { challenge, rpId, userVerification } })`.
3. Returns `AuthenticatorAssertionResponse` — `authenticatorData`, `clientDataJSON`, `signature`, `userHandle`.
4. Server calls `verifyAuthenticationResponse()` from `@simplewebauthn/server`, passing stored public key and expected counter.
5. On success: update `counter`, update `last_used_at`, issue session.

**Never reuse challenges** — a replayed assertion with the same challenge is a valid attack vector.

## Fallback Strategy

Passkeys are additive, not a hard requirement at launch. Correct layering:

1. User registers with email/password first (or magic link).
2. Post-login, prompt to add a passkey ("Sign in faster next time").
3. On subsequent visits, `navigator.credentials.get()` with `allowCredentials: []` (discoverable credential) shows the OS passkey picker.
4. If passkey fails or is unavailable, fall back to password flow without friction.

Do not force passkeys as the only auth method until adoption is high — users on unsupported browsers (older Firefox, some Linux setups) will be locked out.

## Multi-Device / Cross-Device

Platform authenticators (Face ID, Windows Hello) create device-bound passkeys. `backed_up: true` in the authenticator data means the passkey syncs to the platform cloud (iCloud Keychain, Google Password Manager). Cross-platform authenticators (security keys via USB/NFC) are device-bound.

Allow multiple passkeys per user — users register each device. Surface a passkey management UI so they can revoke individual credentials without losing access.

## Server Library Setup (`@simplewebauthn/server`)

```ts
import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} from '@simplewebauthn/server';

const rpID = 'example.com'; // must match window.location.hostname exactly
const rpName = 'Example App';
const origin = 'https://example.com'; // passed to verify functions
```

The `rpID` must match for both registration and authentication. In dev, `localhost` is allowed without TLS. Never hard-code production rpID in shared env vars without environment guards.

## Key Rules

- Store only the **public key** — never the private key, never biometric data.
- Increment and validate the **counter** on every authentication to detect cloned authenticators.
- Set `userVerification: "required"` to ensure biometric/PIN unlock — not just presence.
- Keep challenges **server-side** with a short TTL; never let the client supply or replay them.
- Allow **multiple passkeys per user**; provide a revocation UI.
- Passkeys are an enhancement — always provide a **non-passkey fallback**.
- Use `rpID` = bare domain (no scheme, no port), `origin` = full URL including scheme.
