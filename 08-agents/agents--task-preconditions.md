# Agent Pattern: Task Preconditions

## Overview
An agent that starts a task before verifying its preconditions produces output that fails at runtime in ways that look like implementation bugs but are actually environmental issues. Checking preconditions explicitly — and failing fast with a clear message if they're not met — prevents 30-minute debugging sessions that conclude "oh, the database wasn't running."

## Implementation

### Precondition Checklist Format
At the start of any task, list and verify preconditions:

```
## Precondition Check

Verifying before starting:

[ ] Required files exist
    ✓ lib/db.ts — found
    ✓ lib/auth.ts — found
    ✗ lib/email.ts — NOT FOUND
      → Task requires email sending. Cannot proceed without this file.
      → Options: (1) Create lib/email.ts first, (2) Stub the email call, (3) Clarify if email is actually required

[ ] Required environment variables
    ✓ DATABASE_URL — present in .env.local
    ✓ SUPABASE_SERVICE_ROLE_KEY — present
    ? SENDGRID_API_KEY — not found (required if email is enabled)

[ ] Required services running
    ✓ Postgres — responding on port 5432
    ✗ Redis — connection refused on port 6379
      → Rate limiting depends on Redis. Will it fail silently or throw?

[ ] Required permissions
    ✓ Can write to src/ directory
    ✓ Can run npm install
```

### Preconditions by Task Type

**Database migration:**
- DB is accessible and responding
- No pending migrations blocking this one
- Backup exists (or task explicitly scoped to dev-only)

**New API endpoint:**
- Auth middleware file exists at expected path
- DB client is initialized and exported correctly
- Route file location follows project convention

**Third-party integration:**
- API credentials are present in environment
- Network access to the third-party API (not behind a firewall in dev)
- Rate limits won't be exceeded by development testing

**Deploy:**
- Build passes locally
- Environment variables are set in the target environment
- Previous deploy is not still in progress

### Surfacing Precondition Failures

When a precondition fails:
```
PRECONDITION FAILED: lib/email.ts not found

This task cannot proceed because the email sending module doesn't exist yet.

Options:
1. Create a stub at lib/email.ts that logs instead of sends (recommended for now)
2. Skip the email notification feature in this implementation
3. Build lib/email.ts first (add ~30 min)

Please choose an option or provide the missing file.
```

Do NOT proceed and silently fail later. Surface the issue immediately.

## Key Rules
- List preconditions before starting the implementation, not after discovering a missing one mid-task
- Verify preconditions that can be verified (file existence, env var presence) — don't just list them
- Fail fast with a clear, actionable error message when a precondition is unmet — silent failures waste time
- For blocking preconditions (task cannot proceed), stop and surface options before taking any implementation steps
- For non-blocking preconditions (task can proceed with a workaround), note the workaround and proceed
- Don't over-specify trivial preconditions — "Node.js is installed" doesn't need to be in the list
- Environment variable checks should verify presence, not value — don't log or expose secret values
