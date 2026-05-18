# Disambig: JWT vs Session-Based Auth

## Overview
JWT (stateless tokens) and server-side sessions (stateful cookies + DB) are both valid auth mechanisms, but they solve different problems. The widespread adoption of JWT for web apps has led to JWT being used in contexts where sessions work better—particularly anywhere you need instant revocation (logout, ban, password change). Understanding the tradeoffs prevents picking the wrong mechanism and then struggling to work around its limitations.

## Comparison

| Property | JWT | Session (cookie + DB) |
|---|---|---|
| Server state | None (stateless) | DB row per session |
| Revocation | Hard — needs a blocklist | Easy — delete the row |
| Payload visibility | Visible (base64, not encrypted) | Opaque to client |
| Payload size | Large (all claims in token) | Small (just session ID) |
| DB lookup per request | No | Yes (by default) |
| Works across services | Yes (verify with public key) | No (session DB must be shared) |
| Mobile clients | Natural (Authorization header) | Awkward (cookie handling) |
| Refresh required | Yes (short expiry) | Sessions auto-extend on activity |

## When Sessions Win

```
Traditional web app (server-rendered or Next.js)
→ Sessions: cookies work naturally, revocation is trivial

Instant logout / account ban required
→ Sessions: delete the row, all devices are logged out immediately
→ JWT: requires a blocklist (now stateful — you've lost the main JWT benefit)

User roles change frequently
→ Sessions: DB lookup on every request means current roles always
→ JWT: stale claims until token expires (15 min minimum)

Sensitive data (financial, medical, admin tools)
→ Sessions: HttpOnly cookie + DB row = two factors to compromise

Simple single-server app
→ Sessions: no key management complexity
```

## When JWT Wins

```
Microservices or distributed systems
→ JWT: each service verifies token independently; no shared session DB

Mobile and native apps
→ JWT: Bearer token in Authorization header is cleaner than cookie handling

Machine-to-machine auth (API keys, service tokens)
→ JWT: stateless, self-contained, expiry built in

Read-only API with many consumers
→ JWT: verify-only (public key), no DB dependency for auth

Short-lived single-use tokens (email verification, password reset)
→ JWT: self-contained expiry + claim, no DB row needed
```

## Common JWT Mistakes to Avoid

```ts
// MISTAKE: Long-lived access tokens for web apps
jwt.sign({ sub: userId }, secret, { expiresIn: '30d' })
// → if token leaks, attacker has 30 days of access with no revocation path

// CORRECT: Short access token + refresh rotation
const accessToken  = jwt.sign({ sub: userId }, secret, { expiresIn: '15m' });
const refreshToken = jwt.sign({ sub: userId }, refreshSecret, { expiresIn: '7d' });
// Store refreshToken in HttpOnly cookie (JS-inaccessible)
// Store accessToken in memory (not localStorage — XSS risk)

// MISTAKE: Using JWT for sessions in a monolith
// → you get no benefits; you only get the downsides (revocation is hard, stale claims)
```

## The Blocklist Problem

```
If you need to revoke a JWT before it expires, you need a blocklist:
  - Store revoked token JTI claims in Redis
  - Check blocklist on every verify() call
  - Now your "stateless" JWT requires a DB/Redis lookup per request
  → You've re-invented sessions with extra steps
  → Switch to sessions; it's simpler
```

## Practical Recommendation for Most Apps

```
Next.js / server-rendered app, single service:
→ Use sessions (next-auth, lucia, better-auth)

Next.js app with Supabase:
→ Use Supabase JWT (they handle rotation; you verify in middleware)

Internal API consumed by mobile + web:
→ Short JWT (15 min) + refresh token in HttpOnly cookie

Multi-service backend, internal auth:
→ JWT with RS256 (shared public key, no shared DB)
```

## Key Rules
- **Sessions for web apps by default** — simpler revocation, smaller cookies, no key management.
- **JWT for cross-service auth** — stateless verification is the genuine advantage of JWT.
- **Never long-lived access tokens** — 15-minute expiry + refresh rotation limits blast radius.
- **Refresh tokens in HttpOnly cookies** — not in localStorage (XSS steals them), not in sessionStorage (doesn't survive tab close).
- **If you need revocation, you need a blocklist or sessions** — there's no third option with JWT.
- **JWT payload is not encrypted** — sensitive claims belong in the DB, not the token.
