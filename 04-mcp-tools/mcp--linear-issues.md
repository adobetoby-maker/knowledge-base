# MCP: Linear Issues

## Overview
Linear MCP integration allows issue creation, status transitions, and PR linking to happen automatically as code changes move through the pipeline. The value is bidirectional: developers see code context in Linear (which branch, which PR), and product/PM teams see real progress without Slack pings. The pattern of creating sub-tasks from large features during code review is especially useful—discoveries in code map directly to trackable units of work.

## Core Operations

### Create Issue from Code Context
```
linear authenticate (first time only)

// Create bug found during review
linear create issue:
  title: "Fix: null dereference in PaymentService.charge()"
  description: "lib/payments/charge.ts:47 — user.billingAddress can be null after
                applying a coupon that removes shipping. Found in PR #234 review."
  team: "Engineering"
  priority: 1 (urgent)
  labels: ["bug", "payments"]
```

### Link PR to Issue
```
// When creating a PR, include the Linear issue ID in the branch name or PR body
// Linear auto-detects: "LIN-123" → links PR to issue

Branch naming convention: feat/LIN-123-add-phone-verification
PR body: "Resolves LIN-123"
```

### Update Issue Status
```
// Transition issue when starting work
linear update issue LIN-123 status: "In Progress"

// Transition on PR merge
linear update issue LIN-123 status: "Done"

// Standard status flow:
// Backlog → Todo → In Progress → In Review → Done
```

### Create Sub-tasks from Large Features
```
// Parent: "Implement billing module" (LIN-100)
// Break into sub-tasks discovered during implementation:

linear create issue:
  title: "Add billing_addresses table migration"
  parent: LIN-100
  team: "Engineering"

linear create issue:
  title: "Stripe webhook handler for subscription events"
  parent: LIN-100
  team: "Engineering"

linear create issue:
  title: "Email receipts via Resend on successful charge"
  parent: LIN-100
  team: "Engineering"
```

## Sync Deploy Status to Linear
```
// After production deploy, mark issues in the deployed commit range as deployed
// Get commit range:
git log --oneline v1.2.0..v1.3.0 | grep "LIN-" | grep -oP "LIN-\d+"

// Update each issue:
linear update issue LIN-123 status: "Done"
linear comment issue LIN-123 body: "Deployed to production in v1.3.0 (2026-05-18)"
```

## Useful Queries
```
// Find all in-progress issues for current sprint
linear list issues filter: { state: "In Progress", assignee: "@me" }

// Find issues blocking a release
linear list issues filter: { label: "blocking", milestone: "v1.3.0" }

// Get issue details for context when fixing a bug
linear get issue LIN-123
→ title, description, comments, linked PRs, priority
```

## Key Rules
- **`LIN-NNN` in branch name** — Linear auto-links PRs to issues without manual steps.
- **Create sub-tasks during code review** — when review reveals unexpected complexity, create Linear sub-tasks immediately rather than leaving mental notes.
- **"In Progress" on branch push** — use a git hook or CI step to automate status transitions rather than doing it manually.
- **"Done" on PR merge, not deploy** — use a separate "Released" status for deploy confirmation if you need that distinction.
- **Include file:line in bug issue descriptions** — makes the issue self-contained; anyone can jump straight to the problem.
- **Link to parent issues** — sub-tasks without parent links get lost in the backlog; always set the parent.
