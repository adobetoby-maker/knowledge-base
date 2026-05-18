# Linear MCP — Project Management Workflows

## Core Capabilities

The Linear MCP covers the full issue lifecycle: create issues, update status, query by team/cycle/project/assignee, add comments, and link issues to external resources. Issues are the primary unit; projects and cycles are organizational containers.

## Creating Issues

Minimum required fields: `teamId` and `title`. Everything else is optional but useful.

```
create_issue(
  teamId: "TEAM-ID",
  title: "Clicking 'Save' on the invoice form throws a 500 error",
  description: "Steps to reproduce:\n1. Go to /admin/invoices/new\n2. Fill all fields\n3. Click Save\n\nExpected: invoice saves\nActual: 500 response, check Sentry event ID abc123",
  priority: 2,           // 1=urgent, 2=high, 3=medium, 4=low
  labelIds: ["bug-label-id"],
  assigneeId: "user-id",
  cycleId: "current-cycle-id"   // assigns to active sprint
)
```

To get the current cycle ID: `list_cycles(teamId: "TEAM-ID")` and pick the one with `isActive: true`.

## Updating Issue Status

Linear workflows vary by team but typically progress through states like Todo → In Progress → In Review → Done. Use `update_issue` with the `stateId` for the target state.

```
// First: get available states for the team
list_workflow_states(teamId: "TEAM-ID")

// Then update
update_issue(
  issueId: "ENG-142",
  stateId: "state-id-for-in-review"
)
```

## Querying Issues

Use structured filters rather than full-text search for precision.

```
// Open bugs in current cycle, assigned to me
list_issues(
  filter: {
    team: { id: { eq: "TEAM-ID" } },
    state: { type: { in: ["unstarted", "started"] } },
    cycle: { isActive: { eq: true } },
    assignee: { id: { eq: "MY-USER-ID" } },
    labels: { name: { in: ["bug"] } }
  },
  orderBy: "priority"
)
```

## Workflow: Create Bug Report and Assign to Current Cycle

1. `list_cycles(teamId)` → find `isActive: true` cycle → get `cycleId`.
2. `list_users(teamId)` → find the right assignee → get `userId`.
3. `list_labels(teamId)` → find "Bug" label → get `labelId`.
4. `create_issue(teamId, title, description, priority: 2, cycleId, assigneeId, labelIds: [labelId])`.
5. Reply with the created issue's `identifier` (e.g., "ENG-247") and URL for reference.

## Linking Issues to PRs

When creating a PR for work tracked in Linear, include the issue identifier in the PR title or branch name (`eng-247-fix-invoice-500`). Linear's GitHub integration auto-links when it detects the pattern. If using the MCP directly, add a comment to the issue with the PR URL:

```
create_comment(
  issueId: "ENG-247",
  body: "PR: https://github.com/org/repo/pull/89"
)
```

## Querying by Project

Projects are multi-cycle initiatives. To find all open issues in a project:

```
list_issues(filter: {
  project: { id: { eq: "PROJECT-ID" } },
  state: { type: { notIn: ["completed", "cancelled"] } }
})
```

## Common Mistakes

- Using `list_issues` without filters and getting hundreds of results — always filter by team at minimum.
- Hardcoding cycle IDs — cycles rotate; always query for the active one.
- Updating status with a state name string instead of a state ID — Linear requires the UUID.
- Creating issues without checking for duplicates — search first with a title keyword filter.

## Key Rules

- **Always query for the current cycle ID dynamically** — never hardcode sprint IDs in automations.
- **Filter `list_issues` at minimum by team** — unfiltered queries return noise across all teams.
- **Use priority levels consistently**: 1=urgent (page-level), 2=high (blocking), 3=medium (normal), 4=low (nice-to-have).
- When assigning to a cycle, confirm the cycle is active — assigning to a completed cycle silently succeeds but the issue will not appear in the current sprint view.
- Include reproduction steps and Sentry/log links in bug descriptions — issues without context get deprioritized.
