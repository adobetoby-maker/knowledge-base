# MCP: GitHub PR Workflow (via gh CLI)

## Overview
The `gh` CLI provides machine-readable GitHub operations that compose cleanly in automated workflows. The core pattern—push branch, create PR, wait for CI, merge—becomes a reliable pipeline when you use `--json` flags for structured output and `gh pr checks` for CI status. This avoids polling the GitHub web UI and allows the entire review cycle to happen in one session.

## Full PR Lifecycle

### 1. Push and Create
```bash
# Push branch (will set upstream on first push)
git push -u origin feature/my-feature

# Create PR with structured body
gh pr create \
  --title "Add user phone verification" \
  --body "$(cat <<'EOF'
## Summary
- Adds phone column to users table
- Verification flow with Twilio SMS

## Test plan
- [ ] Unit tests pass
- [ ] Manual test: verify SMS sent on signup
EOF
)" \
  --base main \
  --label "enhancement" \
  --assignee "@me"
```

### 2. Check CI Status
```bash
# Machine-readable CI status
gh pr checks 123 --json name,state,conclusion

# Wait until all checks complete (poll loop)
until gh pr checks 123 --json state --jq '.[].state' | grep -qv 'PENDING'; do
  sleep 30
done

# Check if all passed
gh pr checks 123 --json conclusion --jq '.[].conclusion' | sort | uniq
# → all "SUCCESS" = safe to merge
```

### 3. Get PR Status and Reviews
```bash
# Full PR status in JSON
gh pr view 123 --json title,state,mergeable,reviewDecision,statusCheckRollup

# Check if approvals are sufficient
gh pr view 123 --json reviewDecision --jq '.reviewDecision'
# → "APPROVED" = has required approvals
# → "REVIEW_REQUIRED" = needs more reviews
```

### 4. Merge
```bash
# Squash merge (clean history)
gh pr merge 123 --squash --delete-branch

# Or regular merge
gh pr merge 123 --merge --delete-branch
```

## Useful Inspection Commands
```bash
# List recent PRs for a repo
gh pr list --state open --json number,title,author,createdAt --limit 20

# Find PRs by label
gh pr list --label "bug" --state open

# Get PR comments (for code review context)
gh api repos/{owner}/{repo}/pulls/123/comments

# Get PR diff
gh pr diff 123

# Search for PRs mentioning a function name
gh pr list --search "useAuthContext"
```

## Reading CI Logs for Failures
```bash
# Get the failed check run
gh pr checks 123 --json name,conclusion,detailsUrl | jq '.[] | select(.conclusion == "FAILURE")'

# Fetch the actual log output
gh run view <run-id> --log-failed
# or
gh run view <run-id> --log | grep -A 20 "ERROR\|FAIL\|error"
```

## Issue Integration
```bash
# Create issue from code context
gh issue create \
  --title "Fix: null dereference in payment handler" \
  --body "Found in lib/payments.ts:47 — user.address can be null after discount coupon applied" \
  --label "bug" \
  --assignee "@me"

# Link PR to issue (auto-closes on merge with "Closes" keyword)
gh pr edit 123 --body "Fixes #456

$(gh pr view 123 --json body --jq '.body')"
```

## Key Rules
- **`--json` for machine-readable output** — parse with `--jq` to extract specific fields rather than screen-scraping text output.
- **`gh pr checks` not `gh pr status`** — `checks` gives CI state; `status` gives review state; they're different.
- **Check `mergeable` before merge** — a PR can be approved but have merge conflicts; `mergeable: CONFLICTING` blocks the merge.
- **`--delete-branch` on merge** — keeps the remote clean; recreate from main if you need it again.
- **Use "Fixes #N" in PR body** — automatically closes the linked issue on merge without manual action.
- **Never `gh pr merge` without CI passing** — check `conclusion === "SUCCESS"` on all required checks first.
