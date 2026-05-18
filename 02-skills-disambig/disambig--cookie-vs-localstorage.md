# Disambig: Cookie vs localStorage

## Overview
Cookies and localStorage both store data in the browser, but they have fundamentally different security models and access patterns. Cookies can be made inaccessible to JavaScript (HttpOnly), automatically sent with every request, and expired server-side. localStorage is always accessible to JavaScript, never sent automatically, and persists indefinitely. These differences make the choice deterministic for auth tokens: always cookies. For everything else, the right choice depends on whether server access is needed.

## Comparison

| Property | Cookie | localStorage |
|---|---|---|
| Accessible to JS | Only if NOT HttpOnly | Always |
| Sent with requests | Yes — automatically on every request | Never automatically |
| HttpOnly flag | Yes — JS cannot read/set | Not available |
| Secure flag | Yes — HTTPS only | HTTPS is browser-level, not storage-level |
| SameSite flag | Yes — CSRF protection | Not available |
| Size limit | ~4 KB | 5–10 MB (varies by browser) |
| Persistence | Controlled by `Max-Age`/`Expires` | Until explicitly cleared |
| Server can set | Yes (`Set-Cookie` header) | No |
| Server can clear | Yes (set expired cookie) | No |
| XSS risk | Low (if HttpOnly) | High — XSS can steal all values |
| CSRF risk | Moderate (mitigated by SameSite) | None (not sent automatically) |
| Cross-tab | Yes (same origin) | Yes (same origin) |
| Cross-subdomain | Configurable (`Domain=.example.com`) | No |

## The Rule: Auth Tokens Always in HttpOnly Cookies

```
// WRONG — access token in localStorage
localStorage.setItem('access_token', token);
// → XSS attack reads it: document.cookie... no wait, localStorage.getItem('access_token')
// → One injected script = all tokens stolen

// CORRECT — auth token in HttpOnly cookie (set by server)
// Server response:
Set-Cookie: session_id=abc123; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=604800

// JavaScript cannot read this cookie at all:
document.cookie  // → "" (HttpOnly cookies excluded)
// Attacker's injected JS also cannot read it
```

## Cookie Flags Explained

```
HttpOnly    → JS cannot read or set; only HTTP requests carry it
             → Prevents XSS from stealing the token

Secure      → Only sent over HTTPS, never HTTP
             → Always set in production; prevents network interception

SameSite=Strict  → Only sent on same-site requests (not cross-site)
                  → Maximum CSRF protection; breaks some OAuth flows

SameSite=Lax     → Sent on same-site + top-level navigation GET requests
                  → Good default; allows OAuth redirects

SameSite=None    → Sent on all requests including cross-site
                  → Requires Secure; needed for embeds and third-party widgets

Max-Age / Expires → How long before browser deletes the cookie
                  → Session cookies (no expiry) deleted when browser closes
```

## When localStorage Is Appropriate

```
User preferences (theme, language, sidebar state)
→ localStorage: server doesn't need to know; JS reads it; fine if stolen (no PII)

Non-sensitive app state (last visited tab, draft form data)
→ localStorage: convenience; no auth risk

Feature flags or experiments (non-sensitive)
→ localStorage: quick read without a server round-trip

PWA offline data (non-sensitive)
→ localStorage or IndexedDB: offline access required; no server to set cookie

API tokens for DEVELOPMENT/DEMO ONLY
→ localStorage: acceptable for demos; never for production auth
```

## Setting and Reading Cookies Correctly

```ts
// Server (Next.js Route Handler / API Route)
import { cookies } from 'next/headers';

// Set auth cookie (server-side only)
cookies().set('session_token', token, {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax',
  maxAge: 60 * 60 * 24 * 7, // 7 days in seconds
  path: '/',
});

// Read auth cookie in server component or route handler
const sessionToken = cookies().get('session_token')?.value;

// Clear on logout
cookies().set('session_token', '', { maxAge: 0 });
```

```ts
// localStorage — client-side only, for non-sensitive data
// Save user preference
localStorage.setItem('theme', 'dark');
localStorage.setItem('sidebar-collapsed', 'true');

// Read preference
const theme = localStorage.getItem('theme') ?? 'light';

// Clear on explicit user action
localStorage.removeItem('theme');
```

## Key Rules
- **Auth tokens → HttpOnly cookie, always** — this is not a preference; it's a security requirement.
- **localStorage for preferences, not secrets** — treat everything in localStorage as potentially readable by attackers.
- **`SameSite=Lax` is the safe default** — `Strict` breaks OAuth; `None` requires cross-site use justification.
- **`Secure` flag in production** — cookies without Secure can be sent over HTTP and intercepted.
- **Server clears cookies on logout** — `Max-Age: 0` cookie from server invalidates the cookie on all clients; localStorage clear is client-only.
- **4 KB cookie size limit** — don't put large objects in cookies; store an ID and look up the data server-side.
- **Session tokens in memory for SPAs** — the most secure pattern is: refresh token in HttpOnly cookie, access token in JS memory (React state), never localStorage.
