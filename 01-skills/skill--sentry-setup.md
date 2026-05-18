# Skill: Sentry Integration

## Overview
Sentry captures runtime exceptions, performance traces, and session replays. Without proper configuration, it leaks PII in error payloads, floods dashboards with noise, and produces unreadable minified stack traces. The environment and release tags are the minimum required for any production-grade setup.

## Implementation

### SDK Initialization (Node.js / Next.js)
```typescript
// sentry.server.config.ts — imported before app code
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,         // "production" | "staging" | "development"
  release: process.env.SENTRY_RELEASE,       // git SHA injected at build time
  tracesSampleRate: process.env.NODE_ENV === "production" ? 0.1 : 1.0,
  replaysSessionSampleRate: 0,               // disabled — GDPR risk
  replaysOnErrorSampleRate: 0,               // disabled — GDPR risk

  beforeSend(event) {
    // Scrub PII before the event leaves the process
    if (event.user) {
      delete event.user.email;
      delete event.user.ip_address;
    }
    if (event.request?.headers) {
      delete event.request.headers["authorization"];
      delete event.request.headers["cookie"];
    }
    return event;
  },

  beforeSendTransaction(event) {
    // Drop transactions for health-check routes to reduce noise
    if (event.transaction === "GET /healthz") return null;
    return event;
  },
});
```

### Source Maps
Source maps make minified stack traces readable. Upload during CI build:
```bash
# In CI after build
npx @sentry/cli releases new "$SENTRY_RELEASE"
npx @sentry/cli releases files "$SENTRY_RELEASE" upload-sourcemaps ./dist \
  --rewrite --strip-common-prefix
npx @sentry/cli releases finalize "$SENTRY_RELEASE"
```
Set `SENTRY_RELEASE` to the git SHA: `SENTRY_RELEASE=$(git rev-parse --short HEAD)`.
Never ship source maps to the browser — upload to Sentry, then delete from the build output.

### Alert Rules
Configure in Sentry UI (or via API):
- **New issue**: notify immediately (Slack + PagerDuty for P1 projects)
- **Regression**: issue previously resolved reappears — always alert
- **High volume**: >100 occurrences in 1 hour for the same issue → alert
- **First seen in release**: catch regressions introduced by a deploy

## Key Rules
- Always set `environment` and `release` — without them, regression detection and release-scoped alerts don't work
- Set `tracesSampleRate` to 0.1 or lower in production; 1.0 only in dev/staging
- Never enable session replay in production unless users explicitly opt in (GDPR Article 5)
- Use `beforeSend` to scrub PII — relying on Sentry's server-side scrubbing is not sufficient for GDPR
- Delete source maps from the public build directory after uploading to Sentry
- Group errors by fingerprint when Sentry's default grouping produces false duplicates: `event.fingerprint = ["{{ default }}", request.url]`
- Set `ignoreErrors` for known-harmless browser errors (ResizeObserver loop, Script error)
