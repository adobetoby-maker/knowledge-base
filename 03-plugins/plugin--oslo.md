# plugin--oslo — Cryptography Utilities

## What It Is
Oslo is a TypeScript cryptography library that provides ergonomic wrappers around common security primitives: random string generation, HMAC, SHA-256, base64 encoding, and more. It's used heavily by Lucia Auth and Arctic (OAuth) as an internal dependency, but it's usable standalone.

The core value proposition: WebCrypto is powerful but verbose. Generating a random URL-safe token with WebCrypto requires 5 lines; Oslo collapses it to one.

## Random String Generation

```ts
import { generateRandomString, alphabet } from 'oslo/crypto';

// 32-char URL-safe token
const token = generateRandomString(32, alphabet('a-z', 'A-Z', '0-9'));

// Numeric OTP
const otp = generateRandomString(6, alphabet('0-9'));

// Hex string (for IDs, nonces)
const nonce = generateRandomString(16, alphabet('0-9', 'a-f'));
```

Use this for: email verification tokens, password reset tokens, API keys, OAuth state params, CSRF tokens. **Never use `Math.random()` for security-sensitive values** — it is not cryptographically secure.

The `alphabet()` helper accepts ranges like `'a-z'`, `'A-Z'`, `'0-9'`, or explicit char strings like `'!@#$'`.

## HMAC for Token Signing

```ts
import { HMAC } from 'oslo/crypto';

const hmac = new HMAC('SHA-256');
const key = await hmac.generateKey();

// Sign
const signature = await hmac.sign(key, new TextEncoder().encode(payload));

// Verify (constant-time comparison — don't use === on signatures)
const valid = await hmac.verify(key, signature, new TextEncoder().encode(payload));
```

HMAC is for verifying that a value was issued by someone who holds the key — good for signed cookies, webhook validation (Stripe, GitHub), and stateless tokens. It does not encrypt; it authenticates.

**Always use `hmac.verify()` rather than re-signing and comparing.** `verify()` uses a constant-time comparison internally, preventing timing attacks.

## SHA-256 for Hashing

```ts
import { sha256 } from 'oslo/crypto';

// Hash a token before storing it in the database
// So a DB leak doesn't expose valid tokens
const hashedToken = await sha256(token);
await db.insert(tokenTable).values({ hash: hashedToken, userId });
```

**Hash tokens at rest.** Store the hash, compare the hash. This is the same principle as password hashing but SHA-256 is appropriate here because tokens are already random (high entropy) — they don't need bcrypt's slow hash.

## Base64 Encoding

```ts
import { encodeBase64, decodeBase64, encodeBase64url, decodeBase64url } from 'oslo/encoding';

const encoded = encodeBase64(bytes);       // standard base64 with + and /
const urlSafe = encodeBase64url(bytes);    // URL-safe, no padding — use for tokens in URLs
```

Use `encodeBase64url` for anything that will appear in a URL or HTTP header. Standard base64 has `+` and `/` which require percent-encoding in URLs.

## Comparison with Built-in WebCrypto

| Task | WebCrypto | Oslo |
|---|---|---|
| Random token | `crypto.getRandomValues` → Uint8Array → manual encoding | `generateRandomString(32, alphabet(...))` |
| HMAC sign | Import key → call sign → convert ArrayBuffer | `new HMAC('SHA-256').sign(key, data)` |
| SHA-256 | `crypto.subtle.digest` → ArrayBuffer → manual hex | `sha256(input)` |
| Base64url | No built-in | `encodeBase64url(bytes)` |

Oslo is not replacing WebCrypto — it calls WebCrypto under the hood. It's a convenience wrapper that removes boilerplate and reduces the chance of subtle encoding mistakes (like forgetting to use base64url vs base64).

## When to Use Oslo vs Other Libraries

- **oslo**: token generation, simple HMAC, SHA-256, encoding utilities. Good for auth flows.
- **jose**: JWT creation and verification. Oslo doesn't handle JWTs.
- **bcrypt/argon2**: password hashing. Oslo does not slow-hash.
- **WebCrypto directly**: AES encryption, RSA operations, key derivation (PBKDF2). Oslo doesn't expose these.

## Key Rules
- Use `generateRandomString` with `alphabet()` for all security tokens — never `Math.random()` or UUIDs for secrets.
- Use `encodeBase64url` (not standard base64) for tokens that appear in URLs or headers.
- Hash stored tokens with `sha256` — store the hash, not the raw token.
- Use `hmac.verify()` for signature comparison — never re-sign and compare with `===`.
- Oslo wraps WebCrypto — it works in Node.js 18+, Cloudflare Workers, and browsers without polyfills.
- Install oslo as a direct dependency even if Lucia is present — don't rely on it being a transitive dep.
