# Failure: JWT Algorithm Confusion Attack

## Overview
JWT algorithm confusion (also called "alg:none" or "RS256→HS256 confusion") is a critical authentication bypass. If a server accepts tokens signed with any algorithm and trusts the `alg` claim in the token header, an attacker can forge tokens by switching the expected algorithm and using publicly available key material as the signing secret. The server validates the signature correctly — against the wrong key material — and accepts a forged token.

## How the Attack Works

**Scenario: Server uses RS256 (asymmetric, private/public key pair)**

The server's public key is often publicly available at `/.well-known/jwks.json` or retrievable from OAuth discovery endpoints.

```
Attacker steps:
1. Get the server's public key (often publicly available)
2. Craft a token payload with elevated privileges: { "userId": "admin", "role": "superuser" }
3. Sign the token using HMAC-SHA256 (HS256), using the public key bytes as the HMAC secret
4. Set the header: { "alg": "HS256", "typ": "JWT" }
5. Send the forged token to the server

Server's vulnerable verify code:
const algorithm = token.header.alg; // reads "HS256" from attacker-controlled header
jwt.verify(token, publicKey, { algorithms: [algorithm] }); // verifies with HS256 using public key
// ← PASSES because attacker also signed with HS256 + public key

Server's correct verify code:
jwt.verify(token, publicKey, { algorithms: ["RS256"] }); // explicitly expects RS256
// ← FAILS — HS256 token cannot be verified with RS256 + public key
```

## The "alg:none" Variant

Some libraries historically accepted `alg: "none"` with an empty signature, bypassing verification entirely:
```
Header: { "alg": "none" }
Payload: { "userId": "admin" }
Signature: (empty)
```

Any library version that accepts this is critically vulnerable. Always verify the library explicitly rejects `alg: none`.

## Correct Implementation

```typescript
import jwt from "jsonwebtoken";

// Wrong: reads algorithm from token header
function verifyToken(token: string, key: string | Buffer) {
  const decoded = jwt.decode(token, { complete: true });
  return jwt.verify(token, key, { 
    algorithms: [decoded!.header.alg as jwt.Algorithm] // ← NEVER do this
  });
}

// Right: algorithm is a server-side constant, never from the token
const EXPECTED_ALGORITHM: jwt.Algorithm = "RS256"; // or "HS256" for symmetric
const PUBLIC_KEY = fs.readFileSync("keys/public.pem");

function verifyToken(token: string): JwtPayload {
  return jwt.verify(token, PUBLIC_KEY, {
    algorithms: [EXPECTED_ALGORITHM], // ← hard-coded, not from token
  }) as JwtPayload;
}
```

## Algorithm Selection Rules

**Use RS256 (asymmetric) when:**
- Multiple services verify tokens (each service gets the public key, only auth service has private key)
- Tokens are issued by a third party (OAuth provider, identity provider)

**Use HS256 (symmetric) when:**
- Only one service both issues and verifies tokens
- The secret is kept strictly server-side and never shared

**Never use:**
- `alg: none` — disables signature verification entirely
- HS256 with a short/guessable secret — HMAC secrets should be 256+ bits of entropy
- Algorithm negotiation where the client can influence algorithm selection

## Verification Checklist

```typescript
// Complete secure verification
const payload = jwt.verify(token, PUBLIC_KEY, {
  algorithms: ["RS256"],       // explicit algorithm allowlist
  issuer: "https://auth.myapp.com",  // validate issuer
  audience: "https://api.myapp.com", // validate audience
  clockTolerance: 30,          // 30 seconds for clock skew
});
```

Always validate `iss` (issuer) and `aud` (audience) claims to prevent tokens issued for one service from being accepted by another.

## Key Rules
- Algorithm is a server-side constant in source code, never read from the token header
- Use an allowlist of one algorithm: `algorithms: ["RS256"]`
- Test that `alg: "none"` tokens are rejected
- Test that HS256 tokens are rejected when server expects RS256 (and vice versa)
- Validate `iss`, `aud`, and `exp` claims on every verification
- Public keys retrieved from discovery endpoints should be cached with a short TTL and pinned
- Libraries that default to accepting any algorithm are dangerous — check the default behavior
