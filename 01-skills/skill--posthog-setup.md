# Skill: PostHog Product Analytics

## Overview
PostHog combines event analytics, feature flags, session recording, and A/B testing in one SDK. Misconfigured PostHog captures too much (PII in event properties, recording everything) or too little (no identity stitching after login). Getting the init options right prevents GDPR problems and ensures events are actually useful.

## Implementation

### SDK Init (React / Next.js)
```typescript
// lib/analytics.ts
import posthog from "posthog-js";

export function initPostHog() {
  if (typeof window === "undefined") return; // SSR guard
  if (posthog.__loaded) return;             // idempotent

  posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY!, {
    api_host: process.env.NEXT_PUBLIC_POSTHOG_HOST ?? "https://app.posthog.com",
    // Privacy
    capture_pageview: false,                // handle manually for SPA
    capture_pageleave: true,
    autocapture: false,                     // too noisy; capture intentional events only
    mask_all_text: false,                   // set true if session recording is enabled
    ip: false,                              // don't capture IP (GDPR)
    property_blacklist: ["$current_url"],   // strip query strings that may contain tokens

    // Session recording — off by default, opt-in only
    disable_session_recording: true,

    // Persistence
    persistence: "localStorage+cookie",    // survives page reload, respects browser limits
    cookie_expiration: 365,
    secure_cookie: true,
  });
}
```

### Identity After Login
```typescript
// After successful auth response
posthog.identify(user.id, {
  email: user.email,         // only if user consented to analytics
  plan: user.plan,
  created_at: user.createdAt,
});
```
Call `posthog.identify()` once per session after login. Before login, events are tracked anonymously — PostHog stitches the anonymous session to the identified user automatically.

Call `posthog.reset()` on logout to clear the identity.

### Event Capture Pattern
```typescript
// Capture on meaningful user actions, not on every render
posthog.capture("invoice_created", {
  invoice_id: invoice.id,
  line_items_count: invoice.lineItems.length,
  total_usd: invoice.total,                  // numbers, not strings
});

// Page views in SPA — call on each route change
posthog.capture("$pageview", { $current_url: window.location.pathname });
```

### Feature Flags
```typescript
// Server-side evaluation (consistent, no flicker)
import { PostHog } from "posthog-node";
const phServer = new PostHog(process.env.POSTHOG_KEY!);
const flagEnabled = await phServer.isFeatureEnabled("new-dashboard", userId);

// Client-side (fast, may have brief flash)
const flagEnabled = posthog.isFeatureEnabled("new-dashboard");
```

## Key Rules
- Disable `autocapture` in production — it captures everything including sensitive input values
- Set `ip: false` and mask sensitive query params to comply with GDPR without a cookie banner just for analytics
- Always call `posthog.identify()` after auth, `posthog.reset()` after logout — anonymous and identified sessions won't merge otherwise
- Prefer server-side feature flag evaluation for gating behavior that affects data or billing; use client-side only for UI polish
- Session recording should be opt-in: add a consent gate before calling `posthog.startSessionRecording()`
- Keep event names in `snake_case` and use consistent naming convention across the codebase — PostHog is difficult to rename once data accumulates
- Never capture passwords, tokens, or form field values as event properties
