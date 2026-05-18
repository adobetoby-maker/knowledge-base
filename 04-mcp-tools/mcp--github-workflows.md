# GitHub MCP Workflows

## Authentication

GitHub MCP uses OAuth or PAT authentication:
```
mcp__plugin_github_github__authenticate({})
mcp__plugin_github_github__complete_authentication({ code: "..." })
```

Or use the `gh` CLI directly (already authenticated in this workspace):
```bash
gh auth status    # check auth
gh auth login     # re-authenticate if needed
```

## Pull Request Workflows

### Creating a PR

```bash
# Ensure branch is pushed
git push -u origin feature/add-invoice-pdf

# Create PR with full body
gh pr create \
  --title "Add PDF download for invoices" \
  --body "## Summary
- Adds GET /api/invoices/[id]/pdf endpoint
- Returns PDF blob with Content-Disposition: attachment header
- Accessible from invoice detail page

## Test plan
- [ ] PDF downloads on desktop Chrome
- [ ] PDF downloads on mobile Safari
- [ ] 404 returned for non-existent invoice
- [ ] 403 returned for invoice belonging to another user

🤖 Generated with Claude Code" \
  --base main
```

### Reviewing a PR

```bash
# View PR details
gh pr view 123

# Check PR status (CI, reviews)
gh pr status

# View PR diff
gh pr diff 123

# Approve and merge
gh pr review 123 --approve
gh pr merge 123 --squash --delete-branch
```

### Common PR Operations

```bash
# List open PRs
gh pr list

# Check out a PR locally (for testing)
gh pr checkout 123

# Add reviewers
gh pr edit 123 --add-reviewer username

# Convert draft to ready for review
gh pr ready 123

# Close without merging
gh pr close 123
```

## Issue Workflows

```bash
# Create an issue
gh issue create \
  --title "Invoice PDF fails on Safari iOS" \
  --body "Safari iOS 17 blocks the blob download..." \
  --label "bug"

# List issues
gh issue list --label "bug" --state open

# Close an issue
gh issue close 123 --comment "Fixed in PR #456"
```

## Repository Operations

```bash
# Clone a repo
gh repo clone owner/repo-name

# View recent actions workflow runs
gh run list --limit 10

# View specific run logs
gh run view 12345678 --log

# Re-run failed jobs
gh run rerun 12345678 --failed
```

## Actions / CI Workflows

```bash
# List workflow files
gh workflow list

# Trigger a workflow manually
gh workflow run deploy.yml --ref main

# Watch a running workflow
gh run watch
```

## GitHub API (for complex operations)

```bash
# Get PR comments
gh api repos/owner/repo/pulls/123/comments

# Add a comment to an issue
gh api repos/owner/repo/issues/123/comments \
  --method POST \
  --field body="Investigated and found root cause in lib/invoice-pdf.ts"

# Get commit status
gh api repos/owner/repo/commits/SHA/status
```

## Branch Protection

Typical branch protection for main branch:
- Require PR before merging
- Require 1 review approval
- Require status checks to pass (CI)
- No force pushes

To check what's configured:
```bash
gh api repos/owner/repo/branches/main/protection
```

## Integration with Linear

When the Linear+GitHub integration is set up, include the issue ID in commit messages and branch names:
```bash
# Branch naming
git checkout -b ENG-123-add-invoice-pdf

# Commit message
git commit -m "feat: add PDF download for invoices [ENG-123]"
```

Linear will automatically link commits and PRs to the issue.
