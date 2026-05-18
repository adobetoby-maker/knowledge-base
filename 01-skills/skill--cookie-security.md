# Skill: Secure Cookie Configuration

## Overview
Session cookies are the most attacked vector after auth tokens — XSS steals them, CSRF forges requests with them, network interception captures them in transit. Each cookie attribute addresses a different attack class. Getting all four attributes right (HttpOnly, Secure, SameSite, path scope) closes the common attack surface at zero application cost.

## Implementation

### Setting a Secure Session Cookie
```typescript
// lib/cookies.ts
export function setSessionCookie(response: Response, sessionId: string): void {
  const isProduction = process.env.NODE_ENV === "production";

  const cookieValue = [
    `session=${sessionId}`,
    `HttpOnly`,                                    // no JS access — blocks XSS theft
    `Secure`,                                      // HTTPS only — blocks network sniffing
    `SameSite=Lax`,                                // CSRF protection for navigations
    `Path=/`,                                      // accessible from all paths
    `Max-Age=${60 * 60 * 24 * 30}`,               // 30 days for persistent session
  ].join("; ");

  response.headers.append("Set-Cookie", cookieValue);
}

// For session cookies (expire when browser closes):
const sessionCookieValue = [
  `session=${sessionId}`,
  `HttpOnly`,
  `Secure`,
  `SameSite=Lax`,
  `Path=/`,
  // No Max-Age or Expires = session cookie
].join("; ");
```

### __Host- Prefix (Strongest Option)
```typescript
// __Host- prefix enforces: Secure, Path=/, no Domain attribute
// Browser rejects the cookie if any of these conditions aren't met
const cookieValue = [
  `__Host-session=${sessionId}`,
  `HttpOnly`,
  `Secure`,
  `SameSite=Lax`,
  `Path=/`,                   // REQUIRED for __Host- prefix
  // NO Domain= attribute    // REQUIRED for __Host- prefix
].join("; ");
```

Use `__Host-` prefix for your most critical cookies — it prevents subdomain cookie injection where `evil.example.com` sets a cookie readable by `app.example.com`.

### SameSite Attribute Comparison
| Value | Navigation | Cross-site POST | Cross-site GET | Use case |
|---|---|---|---|---|
| `Strict` | Blocked | Blocked | Blocked | Admin/high-security |
| `Lax` | Allowed | Blocked | Blocked | Standard auth (default) |
| `None` | Allowed | Allowed | Allowed | Embedded widgets, OAuth callbacks |

`SameSite=Lax` stops CSRF for state-changing requests while allowing normal navigation (clicking links, typing URLs). `SameSite=None` requires `Secure` and is only for legitimate cross-site use cases like embedded iframes or OAuth.

### Deleting Cookies
```typescript
export function clearSessionCookie(response: Response): void {
  response.headers.append("Set-Cookie", [
    `session=`,
    `HttpOnly`,
    `Secure`,
    `SameSite=Lax`,
    `Path=/`,
    `Max-Age=0`,              // tells browser to delete immediately
  ].join("; "));
}
```

### Next.js Cookie Helper
```typescript
import { cookies } from "next/headers";

// Reading (server component)
const session = (await cookies()).get("__Host-session")?.value;

// Writing (route handler or server action)
(await cookies()).set("__Host-session", sessionId, {
  httpOnly: true,
  secure: true,
  sameSite: "lax",
  path: "/",
  maxAge: 60 * 60 * 24 * 30,
});
```

## Key Rules
- `HttpOnly` is non-negotiable for session cookies — any XSS vulnerability can steal non-HttpOnly cookies
- `Secure` is non-negotiable in production — without it, session tokens transmit in plaintext over HTTP
- Default to `SameSite=Lax` — it stops CSRF for the vast majority of use cases without breaking navigation
- Use `SameSite=None; Secure` only when you genuinely need cross-site cookie access (OAuth, iframe embeds)
- Use `__Host-` prefix for your primary session cookie — it's the strongest protection with no downside for single-domain apps
- Never use `Domain=.example.com` (with leading dot) for session cookies — it allows all subdomains to read the cookie
- `Max-Age` takes precedence over `Expires` when both are set — prefer `Max-Age` (relative, survives clock skew)
- Set `Path=/` explicitly — browser defaults vary and a narrower path can cause cookies to be silently dropped on some routes
