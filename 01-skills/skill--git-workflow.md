# Skill: git-workflow

**Trigger:** Creating commits, managing branches, resolving conflicts, or understanding git history.
**Returns:** Commit conventions, branch strategy, conflict resolution, and safe git operations.

## Commit Message Convention

Format: `type: brief description (imperative, present tense)`

Types:
- `feat:` — new feature
- `fix:` — bug fix
- `chore:` — build, deps, config (no production code change)
- `refactor:` — code restructure without behavior change
- `style:` — formatting, no logic change
- `docs:` — documentation only
- `test:` — adding or fixing tests
- `perf:` — performance improvement

Examples:
```
feat: add invoice PDF download endpoint
fix: portal redirect loop when session expires
chore: update next.js to 15.2.0
refactor: extract invoice calculation to pure function
```

Keep messages under 72 characters. Use the body for WHY if needed.

## Branch Strategy

```
main           → production, always deployable
feature/name   → new features (branch from main)
fix/bug-name   → bug fixes (branch from main)
chore/name     → maintenance (branch from main)
```

Branch naming: `kebab-case`, descriptive enough to understand without opening it.

Never commit directly to `main`. Even solo projects benefit from branch protection — it allows previewing before merging.

## Safe Daily Workflow

```bash
# Start work on a new feature
git checkout main
git pull origin main
git checkout -b feature/invoice-pdf

# Work... make commits
git add lib/invoices/pdf.ts app/api/invoices/pdf/route.ts
git commit -m "feat: add invoice PDF generation"

# Push branch (creates preview deploy on Vercel/CF)
git push origin feature/invoice-pdf

# After review/testing: merge to main
git checkout main
git merge --no-ff feature/invoice-pdf
git push origin main
```

## Staging Partial Changes

```bash
# Add specific files (preferred — avoids accidentally staging .env or large files)
git add app/api/invoices/route.ts lib/invoices/calculate.ts

# Add by hunk (interactive — choose which changes within a file to stage)
git add -p

# Verify what will be committed
git diff --staged
```

Never use `git add .` or `git add -A` without reviewing what it stages — easy to accidentally commit `.env.local`, build artifacts, or temporary debug files.

## Resolving Merge Conflicts

```bash
# During merge, conflicts show in files as:
<<<<<<< HEAD
  your code
=======
  incoming code
>>>>>>> feature/branch

# Edit to keep the correct version, then:
git add conflicted-file.ts
git commit  # completes the merge
```

For complex conflicts, use a visual diff tool:
```bash
git mergetool  # opens configured visual merge tool
```

When in doubt about which version to keep: check what each version does and what the PR description says the goal is. Don't just pick one arbitrarily.

## Undoing Things

```bash
# Undo last commit, keep changes staged
git reset --soft HEAD~1

# Undo last commit, keep changes unstaged
git reset HEAD~1

# Discard changes in a specific file (DESTRUCTIVE)
git checkout -- filename.ts

# Revert a pushed commit (creates new commit that undoes it — safe for shared branches)
git revert abc123
```

`git reset --hard` discards ALL uncommitted changes with no recovery — use only when you're certain.

## Viewing History

```bash
git log --oneline -10                    # last 10 commits
git log --oneline --graph --all          # visual branch graph
git show abc123                          # see a specific commit
git diff main...feature/branch           # what changed since branching
git blame app/api/invoices/route.ts      # who changed each line
```

## Cherry-Pick

Apply a specific commit from one branch to another:

```bash
git checkout main
git cherry-pick abc123  # applies commit abc123 to current branch
```

Useful for: pulling a critical bug fix from a feature branch to main without merging the whole feature.
