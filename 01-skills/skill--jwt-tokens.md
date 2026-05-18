# Skill: JWT Implementation Best Practices

## What This Covers

JWTs as an authentication mechanism: choosing the right signing algorithm, managing short-lived access tokens with refresh token rotation, token revocation via `jti` claim, what not to put in the payload, and using the `nbf` claim correctly.

## RS256 vs HS256: Which to Use

**HS256** (HMAC-SHA256) uses a single symmetric secret shared between the issuer and all verifiers. If any service with verify capability is compromised, an attacker can forge tokens. Acceptable only when a single service both issues and verifies tokens.

**RS256** (RSA-SHA256) uses a private key to sign and a public key to verify. Services only need the public key to verify; only the auth service holds the private key. Compromise of a consumer service does not allow token forgery.

Use RS256 (or ES256, which is faster) when:
- Multiple services verify tokens (microservices, third-party integrations)
- You publish a JWKS endpoint for external token verification
- The auth service is a separate deployment from consumers

Use HS256 only for single-service monoliths where the issuer and verifier are the same process.

Expose public keys via a JWKS URI (`/.well-known/jwks.json`) so consumers can auto-rotate keys without configuration changes.

## Short Expiry + Refresh Token Rotation

Access tokens should expire in 15 minutes. This limits the damage window if a token is intercepted — the window is bounded by the expiry, not by the user's session length.

Refresh tokens are long-lived (7–30 days) and stored in an `httpOnly` `Secure` cookie (not `localStorage`). When the access token expires, the client exchanges the refresh token for a new access token + a new refresh token (rotation).

```ts
// Issue token pair
function issueTokens(userId: string) {
  const accessToken = jwt.sign(
    { sub: userId, type: 'access' },
    privateKey,
    { algorithm: 'RS256', expiresIn: '15m', jwtid: crypto.randomUUID() }
  )
  
  const refreshToken = jwt.sign(
    { sub: userId, type: 'refresh', family: crypto.randomUUID() },
    privateKey,
    { algorithm: 'RS256', expiresIn: '30d', jwtid: crypto.randomUUID() }
  )
  
  return { accessToken, refreshToken }
}
```

**Rotation with reuse detection**: store the refresh token's `jti` in the database. When a refresh token is used, invalidate it and issue a new one. If a `jti` that was already invalidated is presented, invalidate the entire token family (all refresh tokens for that user session) — this detects stolen refresh tokens being replayed.

```ts
async function rotateRefreshToken(incomingToken: string) {
  const decoded = jwt.verify(incomingToken, publicKey, { algorithms: ['RS256'] })
  const jti = decoded.jti
  
  const stored = await db.query('SELECT * FROM refresh_tokens WHERE jti = $1', [jti])
  
  if (!stored.rows[0]) {
    // This jti was already used — detect token reuse
    await db.query('DELETE FROM refresh_tokens WHERE family = $1', [decoded.family])
    throw new Error('Refresh token reuse detected — session revoked')
  }
  
  await db.query('DELETE FROM refresh_tokens WHERE jti = $1', [jti])
  
  const { accessToken, refreshToken } = issueTokens(decoded.sub)
  // Store new refresh token jti with same family
  await storeRefreshToken(refreshToken, decoded.family)
  
  return { accessToken, refreshToken }
}
```

## `jti` Claim for Revocation

JWTs are stateless by default — you cannot invalidate them after issuance without a blocklist. The `jti` (JWT ID) is a unique identifier per token that enables revocation.

Maintain a `revoked_tokens` table with `(jti, expires_at)`. On logout, insert the access token's `jti`. In the verification middleware, reject tokens whose `jti` is in the blocklist.

```ts
async function verifyAccessToken(token: string) {
  const decoded = jwt.verify(token, publicKey, { algorithms: ['RS256'] })
  
  // Check revocation list
  const revoked = await redis.get(`revoked:${decoded.jti}`)
  if (revoked) throw new Error('Token has been revoked')
  
  return decoded
}

async function revokeToken(jti: string, expiresAt: Date) {
  // Store in Redis with TTL = remaining token lifetime
  const ttl = Math.floor((expiresAt.getTime() - Date.now()) / 1000)
  if (ttl > 0) await redis.setex(`revoked:${jti}`, ttl, '1')
}
```

Redis is ideal for this — the key auto-expires when the token would have expired anyway, keeping the blocklist small.

## What Not to Store in the JWT Payload

JWT payloads are base64-encoded, not encrypted. Anyone with the token can decode and read the payload without knowing the signing key. `base64url.decode(token.split('.')[1])` reveals all claims.

**Never include:**
- Passwords or password hashes
- PII (email, phone, address) — unless required by the protocol (OIDC `id_token`)
- Payment or financial data
- API secrets or internal keys
- Detailed role/permission lists (read from DB on each request instead)

**Include only:**
- `sub` (user ID)
- `jti` (token ID for revocation)
- `iat`, `exp` (issued at, expiry)
- Broad role (`user`, `admin`) — fine-grained permissions should be fetched from DB

The JWT should be enough to identify who the user is, not enough to act as a complete user profile.

## `nbf` Claim (Not Before)

`nbf` (not before) specifies the earliest time the token is valid. Use it when issuing tokens for scheduled future actions — for example, a token embedded in an email link that should not be usable until the link is clicked (but you issued it when the email was sent). Verifiers reject tokens presented before the `nbf` timestamp.

```ts
jwt.sign({ sub: userId, action: 'email-verify' }, privateKey, {
  algorithm: 'RS256',
  notBefore: '0s',   // valid immediately
  expiresIn: '24h',
  jwtid: crypto.randomUUID(),
})
```

Most auth middleware verifies `nbf` automatically — do not skip this check.

## Key Rules

- Use RS256 for any multi-service architecture; HS256 only in single-service monoliths
- Access token TTL: 15 minutes maximum. Refresh token TTL: 7–30 days
- Store refresh tokens in `httpOnly Secure` cookies, never in `localStorage`
- Rotate refresh tokens on every use and detect reuse by tracking `jti` in the database
- JWT payloads are readable by anyone — treat them as public data, not secrets
- Use `jti` + a Redis blocklist for revocation; TTL the blocklist entry to match token expiry
- Publish public keys at a JWKS URI so consumers don't hardcode key material
