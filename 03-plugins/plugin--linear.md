# Plugin: linear

**What it provides:** Access to Linear project management — issues, projects, cycles, teams, comments.
**Key MCPs:** `mcp__plugin_linear_linear__authenticate`, requires auth flow first.
**When to use:** Tracking development work, creating issues from code review findings, updating issue status as work progresses.

## Setup (First Use)
```javascript
// Authenticate first
mcp__plugin_linear_linear__authenticate({})
// Follow the OAuth flow, then:
mcp__plugin_linear_linear__complete_authentication({ code: "..." })
```

## When to Use Linear Integration
- After a code review — create issues for P0/P1 findings automatically
- After a production incident — create a bug report linked to the affected code
- During planning — pull current sprint issues for context before starting work
- Status updates — mark issues done as features are completed

## Common Patterns

### Create Issue from Code Review Finding
```javascript
// After coderabbit/code-reviewer returns findings:
// "P0: Missing auth check on /api/admin route — line 23"
linearCreateIssue({
  title: "Missing auth check on /api/admin route",
  description: "File: app/api/admin/route.ts:23\nNo session verification before returning admin data.\nFix: Add verifyAdmin() check at start of handler.",
  priority: 1,  // urgent
  teamId: "..."
})
```

### Update Issue Status
```javascript
linearUpdateIssue({
  id: "ISSUE-123",
  stateId: "done-state-id"
})
```

## Relationship to Other Tools
- Linear is for tracking/planning — not a replacement for git commits or PR descriptions
- When PRs are merged, update corresponding Linear issues
- Use Linear for: bugs, features, tech debt items
- Use `memory/corrections-log.md` for immediate coding rules — not Linear

## Notes on Auth
Linear uses OAuth — session persists across Claude Code sessions until token expires.
If authentication fails, re-run the authenticate flow.
