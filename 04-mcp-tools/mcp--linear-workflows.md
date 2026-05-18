# Linear MCP Workflows

## Authentication

Linear MCP requires OAuth authentication:
```
mcp__plugin_linear_linear__authenticate({})
→ Returns auth URL
mcp__plugin_linear_linear__complete_authentication({ code: "..." })
→ Establishes session
```

## Issue Management

### Creating Issues

Linear issues have a required team. Get team ID first if unknown:

```
// Find teams
Use Bash: gh api graphql -f query='{ viewer { teams { nodes { id name } } } }' --hostname linear.app

// Or ask Linear MCP for the team (after auth)
// Note: Linear MCP tools may vary — authenticate first, then explore available tools
```

Issues need:
- `title` — descriptive, starts with verb for tasks (Fix, Add, Update, Investigate)
- `teamId` — required
- `description` — markdown supported
- `priority` — 0=No priority, 1=Urgent, 2=High, 3=Medium, 4=Low
- `stateId` — Triage, Todo, In Progress, Done (varies by team)

### Issue Lifecycle

Standard workflow state progression:
```
Triage → Todo → In Progress → In Review → Done
```

When picking up a task:
1. Move to "In Progress"
2. Link the relevant branch name in the description

When completing:
1. Move to "In Review" (if PR opened) or "Done" (if complete)
2. Link PR URL in issue description

## Common Workflows

### Daily Standup Prep

Query your in-progress issues to prep for standup:
```
List all issues assigned to current user with status "In Progress"
Sort by updated date (most recent first)
For each: title, URL, last comment
```

### Bug Triage

When a bug is reported:
1. Create issue with label "Bug"
2. Set priority based on impact (production blocker = Urgent)
3. Add reproduction steps in description
4. Link to relevant error logs or Sentry event
5. Assign to responsible team member

Template:
```markdown
## Description
[What's broken]

## Steps to Reproduce
1. [Step 1]
2. [Step 2]

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happens]

## Environment
- Project: [jrs-auto-repair / manage-worker-bee / etc]
- Browser/platform: [if relevant]
- URL: [if applicable]
```

### Feature Sprint Planning

Creating a batch of issues for a sprint:
```
For each planned feature:
- Create parent issue (Epic or top-level)
- Create sub-issues for each component (Frontend, Backend, Tests, Docs)
- Link sub-issues to parent
- Assign to sprint cycle
```

## Labels

Standard label conventions:
- `bug` — something is broken
- `feature` — new functionality
- `improvement` — enhancement to existing feature
- `tech-debt` — cleanup, refactor, no user-visible change
- `chore` — maintenance, dependency updates
- `blocked` — waiting on external factor

## Integration with Git

When creating a branch for a Linear issue:
```bash
# Linear auto-generates branch names from issue IDs
# Format: team/issue-id-short-description
# Example: drive/ENG-123-add-invoice-pdf

git checkout -b drive/ENG-123-add-invoice-pdf
```

Including the issue ID in branch name links the commit to the issue automatically in Linear (git integration must be set up).

## Priority Guide for This Workspace

| Priority | Use for |
|----------|---------|
| Urgent | Production down, data loss, security issue |
| High | Feature complete but broken, blocking a customer |
| Medium | Important feature work, significant bug |
| Low | Nice-to-have improvements, minor bugs |
| No priority | Ideas, backlog, "maybe someday" |
