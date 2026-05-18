# Principle: Branching Strategy

## Overview
The longer a branch lives, the more it diverges from the main line — and the bigger the merge conflict when it finally integrates. GitFlow's long-lived branches (develop, release, hotfix) were designed for infrequent, scheduled releases. They create integration debt: work that was functionally complete days ago sits on a branch waiting for a release window, accumulating conflicts with parallel work. Trunk-based development shortens the feedback loop: code integrates continuously, conflicts surface early when they're small.

## Key Points

### Trunk-Based Development (Recommended)
- All developers work on short-lived branches off `main` (or `trunk`)
- Branches live < 2 days; ideally < 1 day
- Merged to main via PR after review
- `main` is always deployable — CI must pass before merge
- Deployments can happen multiple times per day

**Why this works better than GitFlow:**
- Merge conflicts are small because branches are short
- Bugs are caught in CI quickly, not discovered weeks later during integration
- Fewer "big bang" merges that block the whole team
- Easier to reason about what's deployed

### GitFlow: When It Makes Sense (Rarely)
GitFlow has `main`, `develop`, `release/*`, `hotfix/*`, and `feature/*` branches:
```
main ←── hotfix/critical-payment-bug
  ↑
develop ←── feature/user-dashboard (lived 3 weeks)
        ←── feature/billing-redesign (lived 2 weeks)
  ↓
release/v2.4.0
```
Appropriate when:
- Multiple supported versions in production simultaneously (mobile apps, libraries with SemVer)
- External audit or compliance requires a defined release artifact
- Infrequent, scheduled releases are a business requirement

Not appropriate for:
- Web applications that deploy continuously
- Teams that can merge and deploy independently

### Feature Flags Replace Feature Branches
For large features that cannot ship in one PR:
```ts
// Feature flags let code merge to main before it's "ready"
if (featureFlags.isEnabled('new-checkout', user.id)) {
  return <NewCheckout />;
}
return <OldCheckout />;
```
- Code lands in main, hidden behind a flag
- No long-lived branch that diverges
- Gradual rollout: enable for 5% → 50% → 100%
- Instant rollback: disable the flag, no revert commit needed
- Delete the flag + old code path once fully rolled out (flag cleanup is mandatory)

### Branch Naming Conventions
```
feat/user-authentication        # new feature
fix/cart-price-calculation      # bug fix
chore/update-dependencies       # non-functional
refactor/extract-payment-utils  # code change without behavior change
```

### The Merge Conflict Cost Model
```
Branch age (days) × Team velocity (PRs/day) ≈ Merge conflict risk
```
A branch that lived 7 days while 3 engineers merged 2 PRs/day = 42 upstream commits to reconcile. A branch that lived 1 day = 6 commits. The math makes short branches economically rational, not just philosophically nice.

### PR Size
- Trunk-based only works if PRs are small enough to review quickly
- Target: < 400 lines changed per PR
- Split by logical unit of work, not by arbitrary size
- "Too big to review quickly" is a signal the branch lived too long

## Key Rules
- Feature branches should merge within 2 days; create a follow-up branch if the feature is larger
- `main` must always pass CI — no "we'll fix it tomorrow" broken main branches
- Never merge a branch with > 1 week of divergence without a rebase first
- Feature flags are the escape hatch for large features — not longer-lived branches
- Delete branches after merge (GitHub can automate this)
- Hotfixes branch off main and merge back to main (and develop if using GitFlow)
- The goal of branching is isolation during development, not permanent separation
