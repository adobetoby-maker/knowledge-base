# MCP: GitLab Patterns

## Overview

GitLab MCP provides access to repositories, merge requests, issues, CI pipelines, and project management. Use it for code review automation, pipeline monitoring, and release management.

## Authentication

```
Tool: gitlab.authenticate → returns login URL
Tool: gitlab.complete_authentication (code from redirect)
```

GitLab uses OAuth. Personal Access Tokens are an alternative for long-lived automation — use tokens with minimum required scopes (`api` for full access, `read_api` for read-only).

## Core Workflows

### 1. Merge Request Review Automation

Before a human reviews, run automated checks:

```
1. List MR files changed → identify which are high-risk
2. Read changed files from the repository
3. Check for: missing tests, security patterns, breaking API changes
4. Post a review comment with findings
```

```
Tool: gitlab.list_merge_request_changes
  project_id: "namespace/repo"
  merge_request_iid: 42

Tool: gitlab.create_merge_request_note
  project_id: "namespace/repo"
  merge_request_iid: 42
  body: "Automated review found: ..."
```

Always note "automated review" in comments — humans need to know.

### 2. Pipeline Status Monitoring

Poll pipeline status for deploy verification:

```
Tool: gitlab.get_pipeline
  project_id: "namespace/repo"
  pipeline_id: 12345

→ status: "running" | "success" | "failed" | "canceled"
```

Wait for `success` before proceeding. On `failed`, pull job logs:

```
Tool: gitlab.get_job_log
  project_id: "namespace/repo"
  job_id: <from pipeline jobs list>
```

Tail the last 100 lines — failure reason is almost always at the bottom.

### 3. Issue Creation from Alerts

When monitoring detects a problem, create an issue:

```
Tool: gitlab.create_issue
  project_id: "namespace/repo"
  title: "[AUTOMATED] Payment processor timeout 2026-05-18"
  description: "Detected by monitoring...\n\n**Steps to reproduce:**\n..."
  labels: ["bug", "automated"]
  assignee_id: <on-call user ID>
```

Labels allow filtering auto-created issues from human-created ones.

### 4. Release Tag Creation

After successful deploy, create a release tag:

```
Tool: gitlab.create_tag
  project_id: "namespace/repo"
  tag_name: "v2.4.1"
  ref: "main"
  message: "Release v2.4.1"

Tool: gitlab.create_release
  project_id: "namespace/repo"
  tag_name: "v2.4.1"
  description: "## Changes\n- Feature X\n- Bug fix Y"
```

## Project ID Format

GitLab accepts either numeric ID (`12345`) or URL-encoded namespace path (`namespace%2Frepo`). Use numeric IDs in automation — namespace paths change when projects are renamed or transferred.

## Pagination

GitLab paginates list results. Default 20 items, max 100 per page:

```
Tool: gitlab.list_merge_requests
  project_id: "namespace/repo"
  per_page: 100
  page: 1
  state: "opened"
```

For large projects, always paginate. Check `X-Total-Pages` header to know when to stop.

## Protected Branches

Automated tools cannot push directly to protected branches. Use merge requests:

1. Create branch from protected branch
2. Commit changes to that branch
3. Create merge request

Trying to push directly to `main` will fail with 403.

## CI/CD Variable Management

```
Tool: gitlab.create_project_variable
  project_id: "namespace/repo"
  key: "DEPLOY_TOKEN"
  value: "<secret>"
  masked: true
  protected: true
```

`masked: true` = value hidden in logs. `protected: true` = only available on protected branches/tags.

## Anti-Patterns

- Don't create issues on every alert — deduplicate first (check if open issue for same error exists)
- Don't use `sudo` API calls in automation — requires admin tokens, violates least-privilege
- Don't hard-code project IDs — resolve by path at startup and cache
- Don't poll pipelines faster than every 10 seconds — wastes rate limit
