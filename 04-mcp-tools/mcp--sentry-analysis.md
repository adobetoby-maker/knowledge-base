# Sentry MCP — Error Investigation Workflows

## Core Capabilities

The Sentry MCP lets you query recent errors, retrieve full event details with stack traces, update issue status (resolve, ignore, assign), and search issues by query string. The workflow is: surface → triage → investigate → act.

## Querying Recent Errors

Start with `list_issues` filtered to your organization and project to surface what is actively burning.

```
list_issues(
  organization_slug: "your-org",
  project_slug: "your-project",
  query: "is:unresolved",
  sort: "date",
  limit: 25
)
```

Refine with Sentry's query syntax:
- `is:unresolved level:error` — unresolved errors only (no warnings)
- `is:unresolved !has:assignee` — unresolved and unowned
- `times_seen:>10` — errors that have occurred more than 10 times
- `firstSeen:>2026-05-17` — new errors since yesterday
- `user.email:customer@example.com` — errors affecting a specific user

## Getting Error Details with Stack Traces

Once you have an issue ID from the list, fetch the latest event to see the full stack trace, request context, breadcrumbs, and user info.

```
// Get the issue overview
get_issue(
  organization_slug: "your-org",
  issue_id: "12345678"
)

// Get the latest event with full stack trace
get_latest_event(
  organization_slug: "your-org",
  issue_id: "12345678"
)
```

The event response includes: `exception.values[].stacktrace.frames` (frames are listed innermost-last; the error origin is the last frame), `request` (URL, method, headers, body), `user`, `tags`, `contexts` (OS, runtime, device), and `breadcrumbs` (sequence of events leading to the error).

Read frames bottom-to-top: the last frame is where the exception was thrown; work upward through your own code until you find the root cause (frames from `node_modules` are usually noise).

## Investigating a Production Error Report

When a user reports something is broken:

1. `list_issues(query: "is:unresolved url:*path-they-mentioned*")` — find issues matching the affected route.
2. `get_latest_event(issue_id)` — get the stack trace and request context.
3. Check `event.request.data` — if available, the exact payload that triggered the error.
4. Check `event.breadcrumbs` — the sequence of UI interactions or API calls before the crash.
5. Check `event.user.id` — correlate with your database to see the account's state.
6. Cross-reference the `event.timestamp` with deployment history — did this start after a recent deploy?

## Updating Issue Status

After investigating:

```
// Mark resolved (with optional commit reference)
update_issue(
  organization_slug: "your-org",
  issue_id: "12345678",
  status: "resolved"
)

// Ignore for 24 hours (known fluke, not worth fixing now)
update_issue(
  organization_slug: "your-org",
  issue_id: "12345678",
  status: "ignored",
  ignoreDuration: 1440  // minutes
)

// Assign to a team member
update_issue(
  organization_slug: "your-org",
  issue_id: "12345678",
  assignedTo: "username"
)
```

## Spotting Regressions

Compare `firstSeen` vs recent deploy timestamps. An issue with `firstSeen` matching your last deploy time is almost certainly a regression introduced in that deploy. Check `event.tags.release` — Sentry tracks which release version each event occurred in.

## Common Mistakes

- Resolving issues without fixing the underlying code — they will reopen on next occurrence.
- Ignoring issues indefinitely instead of tracking them as tech debt in Linear/GitHub.
- Reading only the exception message without examining the stack trace — the message is often generic; the frame is specific.
- Not checking breadcrumbs — they frequently reveal the user action sequence that only fails in a specific order.

## Key Rules

- **Always fetch `get_latest_event`**, not just `get_issue` — the issue summary lacks the stack trace you need for diagnosis.
- **Read stack frames bottom-to-top** — the last frame is the crash site; your code frames above it are the call path.
- **Check `firstSeen` against deploy times** before assuming an error is old and low-priority — it may be a new regression.
- Do not mark an issue resolved unless there is a code fix — "resolved" in Sentry implies the code changed, not that you acknowledged the error.
- When assigning issues, include a comment with your investigation notes — the next person to look at it should not have to repeat your work.
