# Analytics Events

Tracking analytics events consistently so product and business teams can answer questions six months from now without archaeology.

## The Core Problem

Analytics data is write-once and append-only in practice. Events tracked with inconsistent names, missing properties, or unclear semantics accumulate into a pile of data that can't be joined or trusted. Fixing it requires re-deploying and accepting a gap in historical data. Prevention is the only affordable option.

## Naming Convention

Use `noun_verb` snake_case. The noun is the entity being acted on; the verb is what happened to it.

Good: `user_signed_up`, `subscription_upgraded`, `invoice_paid`, `file_uploaded`
Bad: `signup`, `upgraded_subscription`, `payInvoice`, `FileUpload`

Why noun first: when you scan an event list alphabetically, all events about a given entity cluster together. `user_signed_up`, `user_deactivated`, `user_invited` are adjacent. `signed_up`, `deactivated`, `invited` are scattered.

Verbs should be past tense. Events describe things that happened, not things that are happening. `page_viewed` not `page_view`, `button_clicked` not `button_click`.

## Properties on Every Event

Every single event must carry these base properties — wire them into the tracking client at the layer that calls the analytics SDK, not in individual call sites:

- `user_id` — nullable (guests get null, not a fake ID). Never send a fake or placeholder.
- `session_id` — UUID generated at session start, rotated on login/logout. Allows funnel analysis without login.
- `timestamp` — ISO 8601 UTC, set client-side at the moment of the action. Server receipt time differs by network latency and is wrong for ordering user actions.
- `platform` — `web`, `ios`, `android`, `server`. Critical for segmentation.
- `env` — `production`, `staging`, `development`. Filter dev events on ingestion, not ad hoc.

Properties are additive per event on top of the base set. Never put event-specific data in a generic `metadata` blob — it prevents querying.

## PostHog vs Mixpanel vs Custom

**PostHog**: self-hostable, open source, strong product analytics (funnels, session replay, feature flags). Best when privacy matters or you want to own the data. Autocapture is a trap — it creates unmaintainable event sprawl. Turn it off and track explicitly.

**Mixpanel**: best-in-class funnel and cohort analysis UI, expensive at scale, no self-host. Worth it if the business is actively doing growth analysis and willing to pay.

**Custom (Postgres + BigQuery)**: viable for simple reporting but you re-implement everything Mixpanel/PostHog already built. Only makes sense if you're piping data to a warehouse you already own for other reasons.

Regardless of tool, track the event in one place — an analytics service module — and let it forward to whatever backend is configured. Calling `posthog.capture()` directly in 40 components is how naming drift starts.

## Event Registry

Maintain a central registry file (e.g., `lib/analytics/events.ts`) that exports typed event definitions:

```ts
export const EVENTS = {
  USER_SIGNED_UP: 'user_signed_up',
  SUBSCRIPTION_UPGRADED: 'subscription_upgraded',
} as const;
```

All tracking calls reference `EVENTS.USER_SIGNED_UP`, never the string literal. When a name needs to change, it's one edit. New events must be added here first — PR review catches undocumented events before they ship.

Document each event with a comment: what triggers it, what properties it carries beyond the base set, and why it exists. "Obvious" events become confusing once the person who added them has left.

## Key Rules

- `noun_verb` past tense snake_case — no exceptions
- Base properties (user_id, session_id, timestamp, platform, env) on every event via the client wrapper, not call sites
- Central event registry — no inline string literals in component code
- Turn off autocapture; track explicitly
- Filter `env != 'production'` at ingestion, not at query time
- Null `user_id` for unauthenticated users; never generate fake IDs
- Document each event: trigger, extra properties, purpose
