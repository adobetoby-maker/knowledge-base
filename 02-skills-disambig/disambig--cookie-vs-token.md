# Cookie-Based Sessions vs JWT Tokens

## The Core Trade-off

Both mechanisms prove "this user authenticated." The difference is where the proof lives and what threat it is vulnerable to.

**Cookie-based sessions** store a session ID in a cookie. The server holds the actual session data (in a database or memory). Every request the browser sends the cookie; the server looks up the session.

**JWT (JSON Web Token)** encodes the user's identity and claims directly in the token. The server issues it; the client stores it (localStorage or a cookie); the server validates the signature without a database lookup.

## The Attack Surface Difference

**localStorage tokens are vulnerable to XSS.** Any injected JavaScript can read `localStorage` and exfiltrate the token. Once stolen, an attacker has full session access until the token expires. JWTs are typically long-lived (hours to days) to avoid frequent re-auth — this compounds the damage window.

**Cookies are vulnerable to CSRF.** Browsers automatically attach cookies to every request to the matching domain, including cross-origin form submissions. A malicious site can trick a logged-in user's browser into making authenticated requests. CSRF is mitigated with `SameSite=Lax` (blocks cross-origin form POSTs) or CSRF tokens.

**The recommended default:** httpOnly cookies with `SameSite=Lax`. httpOnly prevents JavaScript from reading the cookie — XSS cannot steal it. `SameSite=Lax` blocks CSRF for form-based attacks. You get the best of both: JavaScript cannot access the credential, and cross-site requests do not automatically carry it.

## When to Use JWT

**Stateless microservices.** If Service A issues a JWT and Service B needs to verify the user's identity, Service B can validate the signature without calling Service A or a shared database. Session cookies require all services to share a session store or a lookup API.

**Mobile and native clients.** Mobile apps do not have a "browser cookie jar" managed by the OS. Storing a token in the device's secure keychain and sending it as a `Bearer` header is the standard mobile auth pattern.

**Third-party API access (OAuth scopes).** JWTs naturally encode scopes and expiry, making them well-suited for authorizing specific operations with a limited-lifetime token.

## When to Use Cookie Sessions

**Traditional web apps where the server controls all interactions.** SSR apps (Next.js Server Actions, Remix actions) naturally use cookies because the server sets and reads them without client-side involvement.

**When you need instant revocation.** JWTs are stateless — a revoked JWT is still cryptographically valid until it expires. Session IDs stored in a database can be deleted immediately. If "log out all devices" or "suspend this account immediately" is a requirement, session cookies win.

**Simpler security posture.** Cookie sessions do not require implementing token refresh logic, managing expiry on the client, or handling the window between token expiration and refresh. The server is the single source of truth.

## Supabase Context

Supabase uses JWTs, but the official client libraries store them in httpOnly cookies (in Next.js SSR contexts via `@supabase/ssr`). This is the hybrid: JWT's stateless verification capability with httpOnly cookie's XSS protection. The refresh token handles re-auth; the server rotates it.

## Key Rules

- **Never store JWTs in `localStorage`** on a web app — it is exposed to every script on the page, including third-party analytics.
- **Always use `httpOnly; Secure; SameSite=Lax`** when setting auth cookies — these three flags together cover the primary cookie attack vectors.
- **Set short JWT expiry** (15 minutes) with a refresh token pattern — long-lived JWTs negate the benefit of statelessness by turning every token into a long-window attack surface.
- If using JWTs for API-to-API auth, validate the `aud` (audience) and `iss` (issuer) claims — a valid JWT issued for a different service is not valid for yours.
- Do not roll your own JWT parsing — use a vetted library (`jose`, `jsonwebtoken`) and always verify the signature, not just decode the payload.
