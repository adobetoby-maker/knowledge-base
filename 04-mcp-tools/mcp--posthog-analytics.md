# PostHog MCP — Analytics Queries and Workflows

## What PostHog MCP Provides

The PostHog MCP server connects to a PostHog project and exposes analytics operations: querying events and properties, running funnel analyses, checking feature flag configurations, creating deployment annotations, and surfacing user journey data. All queries run against the PostHog API using the project API key configured in the MCP server.

## Querying Events

Event queries answer "how many times did X happen, and when?" Use HogQL (PostHog's SQL dialect) or the insight query tools to retrieve event counts, unique user counts, and event properties.

**Workflow — weekly event volume:**
1. Use `query` or equivalent tool with a HogQL `SELECT` against the `events` table
2. Filter by `timestamp` for the desired range: `WHERE timestamp >= now() - INTERVAL 7 DAY`
3. Group by `event` to see breakdown across event types, or by `person_id` for unique user counts
4. Return the count columns and inspect for anomalies

HogQL supports standard SQL aggregation: `COUNT()`, `COUNT(DISTINCT person_id)`, `AVG()`, `percentile`. The `events` table has columns: `event`, `timestamp`, `person_id`, `properties` (JSON), `distinct_id`.

## Funnel Analysis

Funnels answer "what percentage of users who did A also did B, then C?" This is the primary tool for measuring conversion and diagnosing drop-off.

**Workflow — onboarding funnel:**
1. Define the funnel steps as an ordered list of event names (e.g., `signup_completed → email_verified → profile_created → first_action`)
2. Use the funnel insight tool, passing the steps array and a date range
3. The result returns conversion rate at each step and the absolute number of users who reached each step
4. Drop-off between specific steps identifies where to focus optimization work

Funnels require a conversion window (e.g., users must complete all steps within 7 days). Set this explicitly — the default may be longer than the expected user journey.

## Feature Flag Status

Feature flags gate functionality behind a percentage rollout, user property conditions, or named cohorts. Use the MCP to check current flag configuration without navigating the UI.

**Workflow — verify flag is enabled for user:**
1. Use the feature flags tool to list all flags and their rollout conditions
2. Check if the target flag is active and what rollout percentage or conditions apply
3. To verify a specific user's flag evaluation, query events for `$feature_flag_called` with `properties.$feature_flag = 'flag-name'` and `properties.$feature_flag_response = true`

Never deploy code that depends on a feature flag without confirming the flag exists and is configured correctly in PostHog. The event-based verification step confirms the flag is actually being evaluated in production.

## Deployment Annotations

Annotations mark a timestamp in PostHog charts with a label (e.g., "Deployed v2.3.1 — new checkout"). This makes it immediately visible in trend charts whether a deploy correlated with a metric change.

**Workflow — annotate a deploy:**
1. After a production deploy, use the annotation creation tool
2. Pass the current timestamp (or exact deploy time), the annotation text, and optionally a dashboard ID
3. The annotation appears as a vertical line in all trend charts for the project

Create annotations for every production deploy, schema migration, marketing campaign launch, or pricing change. Without annotations, diagnosing cause-and-effect in metric charts requires guesswork.

## Onboarding Completion Workflow

**"How many users completed onboarding this week?"**
1. Identify the event that fires when onboarding completes (e.g., `onboarding_completed`)
2. Query: `SELECT COUNT(DISTINCT person_id) FROM events WHERE event = 'onboarding_completed' AND timestamp >= now() - INTERVAL 7 DAY`
3. For context, also query the entry event (e.g., `signup_started`) in the same period
4. Divide completed by started to get the completion rate
5. If the rate changed week-over-week, check annotations for deploys or configuration changes in the same window

## Key Rules

- Always specify a `timestamp` range in event queries — unscoped queries over large datasets are slow and may time out
- Use `COUNT(DISTINCT person_id)` for unique user counts, not `COUNT(*)` which counts events (one user can trigger many events)
- Funnel steps must be ordered by the expected user journey — out-of-order steps return meaningless conversion rates
- Create an annotation immediately after every production deploy, not retroactively — exact timing matters for correlation analysis
- Feature flag queries via MCP read configuration, not evaluation state — always verify evaluation via `$feature_flag_called` events
- HogQL `properties` column is JSON — access fields with `properties.field_name` or `JSONExtractString(properties, 'field_name')`
