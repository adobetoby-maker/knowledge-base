# Skill: Content Security Policy (CSP)

## Overview
CSP is the most effective browser-side defense against XSS. It tells the browser which sources are allowed to load scripts, styles, images, and frames. The hard part: getting it strict enough to block attacks without breaking legitimate functionality. The path: deploy in report-only mode first, fix violations, then enforce.

## Implementation

### CSP Header in Next.js (`next.config.ts`)
```
default-src 'self';
script-src 'self' 'nonce-GENERATED_NONCE' 'strict-dynamic';
style-src 'self' 'nonce-GENERATED_NONCE';
img-src 'self' https: data:;
font-src 'self' https://fonts.gstatic.com;
connect-src 'self' https://api.example.com wss://api.example.com;
frame-src 'none';
object-src 'none';
base-uri 'self';
form-action 'self';
upgrade-insecure-requests;
report-uri https://ingest.sentry.io/api/csp/?key=abc;
```

### Nonce Generation Per Request
CSP blocks all inline scripts by default. Nonces allow specific inline scripts without allowing `unsafe-inline`. Generate a new cryptographically random nonce for every HTTP request:
```typescript
// middleware.ts
import crypto from "crypto";
const nonce = crypto.randomBytes(16).toString("base64");
response.headers.set("Content-Security-Policy", buildCSP(nonce));
response.headers.set("x-nonce", nonce); // forward to layout
```

Then attach the nonce to any inline script tag via the `nonce` attribute. The browser checks that the nonce in the tag matches the header before executing.

### Strict-Dynamic
`'strict-dynamic'` allows scripts loaded by already-trusted (nonce-bearing) scripts — this is how bundlers load chunks without needing to allowlist every chunk URL:
```
script-src 'nonce-GENERATED_NONCE' 'strict-dynamic';
```

### Start with Report-Only
Deploy `Content-Security-Policy-Report-Only` first — same syntax, but the browser reports violations instead of blocking them. Monitor the report-uri endpoint for violations, fix each one (usually a missing `connect-src` or a third-party script domain). Switch to enforcing `Content-Security-Policy` after a week of clean reports.

### Common Directives Reference
| Directive | What it controls |
|---|---|
| `default-src` | Fallback for unspecified directives |
| `script-src` | JavaScript |
| `style-src` | CSS |
| `img-src` | Images |
| `connect-src` | fetch(), XHR, WebSocket |
| `frame-src` | iframe sources |
| `object-src 'none'` | Disables plugin embeds |
| `base-uri 'self'` | Prevents base-tag injection |
| `form-action 'self'` | Restricts form submission targets |

## Key Rules
- Never use `unsafe-inline` for scripts — it defeats CSP entirely; use nonces instead
- Never use `unsafe-eval` unless a specific third-party library requires it — it allows execution of dynamically constructed code strings, which is the XSS attack surface CSP is meant to close
- Start with `Content-Security-Policy-Report-Only` and fix violations before enforcing
- Set `object-src 'none'` and `base-uri 'self'` always — these block entire classes of injection attacks
- Nonces must be cryptographically random and unique per request — reusing nonces makes them predictable and defeats the protection
- The `Vary: Content-Security-Policy` header is needed when nonces differ per request — ensure CDN passes it through correctly
- Monitor the `report-uri` endpoint for violations in production even after enforcement — attackers probe CSP to find gaps
