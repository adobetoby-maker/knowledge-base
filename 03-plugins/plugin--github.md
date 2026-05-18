# Plugin: github@claude-plugins-official

**What it provides:** GitHub repository management — issues, PRs, branches, releases, workflows.
**When to reach for it:** Creating PRs, managing issues, checking CI status, reviewing code, automating GitHub workflows.

## Key Skills
- `github` — general GitHub operations
- `github-automation` — automate GitHub workflows
- `github-actions-templates` — CI/CD workflow templates
- `github-workflow-automation` — advanced workflow automation
- `gh-review-requests` — manage review requests
- `git-pr-workflows-git-workflow` — git + PR workflow patterns
- `git-pr-workflows-pr-enhance` — enhance PR descriptions
- `git-pr-review` — review a PR
- `git-pr-workflows-onboard` — onboard to a git workflow
- `create-pr` — create a pull request
- `create-branch` — create and setup a branch
- `address-github-comments` — respond to PR review comments

## CLI via `gh` (Bash tool)
The `gh` CLI is the fastest path for most GitHub operations:

```bash
# Create a PR
gh pr create --title "feat: add feedback form" --body "..."

# List PRs
gh pr list

# Check PR status
gh pr status

# View PR
gh pr view <number>

# Merge PR
gh pr merge <number> --squash

# Create issue
gh issue create --title "..." --body "..."

# List issues
gh issue list --label "bug"

# Check workflow runs
gh run list

# View specific run
gh run view <run-id>

# Watch a running workflow
gh run watch <run-id>
```

## Common Workflows

**Safe PR creation flow:**
```bash
# Ensure branch is up to date
git pull origin main
git checkout -b feature/my-feature
# make changes
npm run build && npx tsc --noEmit  # verify before pushing
git add [files]
git commit -m "feat: ..."
git push origin feature/my-feature
gh pr create --title "feat: ..." --body "$(cat <<'EOF'
## Summary
- What changed
- Why it changed

## Test Plan
- [ ] Build passes
- [ ] Manually tested on preview URL
EOF
)"
```

**Check if CI passes before merging:**
```bash
gh pr checks <number>
# Wait for checks to pass, then:
gh pr merge <number> --squash
```

## GitHub Actions for Auto-Deploy
Most projects use Vercel's GitHub integration — push to main automatically deploys.
For custom CI needs:
```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm run build
      - run: npx tsc --noEmit
      - run: npm run lint
```
