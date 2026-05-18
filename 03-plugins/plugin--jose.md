# Plugin: jose (JWT)

## What It Is

`jose` is a JavaScript/TypeScript JWT library that works in any runtime: Node.js, Deno, Cloudflare Workers, browser. Used for: signing/verifying JWTs, creating short-lived tokens, magic links, API key hashing. Replaces `jsonwebtoken` (Node-only).

## Installation

```bash
npm install jose
```

## Sign a JWT

```ts
import { SignJWT } from 'jose'

const SECRET = new TextEncoder().encode(process.env.JWT_SECRET!)

async function createToken(payload: Record<string, unknown>, expiresIn = '1h'): Promise<string> {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .setJti(crypto.randomUUID())  // Unique token ID (for one-time-use invalidation)
    .sign(SECRET)
}

// Example: create a password reset token
const token = await createToken({ userId: user.id, type: 'password-reset' }, '30m')
```

## Verify a JWT

```ts
import { jwtVerify } from 'jose'

async function verifyToken(token: string) {
  try {
    const { payload } = await jwtVerify(token, SECRET)
    return payload
  } catch (err) {
    // JWTExpired, JWTClaimValidationFailed, JWSSignatureVerificationFailed, etc.
    return null  // Treat any failure as invalid
  }
}

// With expected claim validation
async function verifyResetToken(token: string): Promise<string | null> {
  const payload = await verifyToken(token)
  if (!payload) return null
  if (payload.type !== 'password-reset') return null
  return payload.userId as string
}
```

## Admin Session Cookie (jrs-auto-repair Pattern)

```ts
// lib/adminAuth.ts
import { SignJWT, jwtVerify } from 'jose'

const ADMIN_SECRET = new TextEncoder().encode(process.env.ADMIN_SECRET!)
const COOKIE_NAME = 'admin_session'

export async function createAdminSession(adminId: string): Promise<string> {
  return new SignJWT({ adminId, type: 'admin' })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('8h')
    .sign(ADMIN_SECRET)
}

export async function validateAdminSession(): Promise<boolean> {
  const cookieStore = await cookies()
  const sessionCookie = cookieStore.get(COOKIE_NAME)?.value
  if (!sessionCookie) return false

  try {
    const { payload } = await jwtVerify(sessionCookie, ADMIN_SECRET)
    return payload.type === 'admin'
  } catch {
    return false
  }
}
```

## Asymmetric Keys (RS256)

For public/private key pairs (useful when multiple services need to verify tokens but only one should sign):

```ts
import { SignJWT, jwtVerify, generateKeyPair, importPKCS8, importSPKI } from 'jose'

// Generate (do once — store keys as environment variables)
const { privateKey, publicKey } = await generateKeyPair('RS256')

// Sign with private key
const token = await new SignJWT({ userId })
  .setProtectedHeader({ alg: 'RS256' })
  .setIssuedAt()
  .setExpirationTime('1h')
  .sign(privateKey)

// Verify with public key (other services can verify without signing capability)
const privKey = await importPKCS8(process.env.JWT_PRIVATE_KEY!, 'RS256')
const pubKey = await importSPKI(process.env.JWT_PUBLIC_KEY!, 'RS256')
```

## Encrypt a JWT (JWE) — for Sensitive Payloads

```ts
import { EncryptJWT, jwtDecrypt } from 'jose'

const ENCRYPTION_KEY = await crypto.subtle.generateKey(
  { name: 'AES-GCM', length: 256 },
  true,
  ['encrypt', 'decrypt']
)

// Encrypt (payload is not readable without the key)
const encrypted = await new EncryptJWT({ creditCardToken: 'tok_xxx' })
  .setProtectedHeader({ alg: 'dir', enc: 'A256GCM' })
  .setIssuedAt()
  .setExpirationTime('15m')
  .encrypt(ENCRYPTION_KEY)

// Decrypt
const { payload } = await jwtDecrypt(encrypted, ENCRYPTION_KEY)
```

Use JWE (encrypted JWT) when the payload contains sensitive data. JWS (signed JWT) only guarantees integrity, not confidentiality — the payload is base64-encoded and visible to anyone.

## Comparing jose vs jsonwebtoken

| Feature | jose | jsonwebtoken |
|---------|------|-------------|
| Runtimes | Node, Edge, Browser, Deno | Node only |
| TypeScript | Native | `@types/jsonwebtoken` |
| Algorithm support | RS256, PS256, ES256, HS256, ... | HS256, RS256, ... |
| JWE encryption | Yes | No |
| Bundle size | Tree-shakeable | Full lib |

Use `jose` for all new code — `jsonwebtoken` is Node-only and won't work in Cloudflare Workers or Edge Routes.

## Env Variable for Secret

```
# Must be a strong random value — not a human-readable string
JWT_SECRET=generate-with: openssl rand -base64 32
ADMIN_SECRET=generate-with: openssl rand -base64 32
```
