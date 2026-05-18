# Principle: Trunk-Based Development

## What It Is and Why It Exists

Trunk-based development (TBD) is a branching strategy where all developers integrate their changes to a single shared branch (main/trunk) at least once per day — ideally several times. Feature branches, when used at all, are short-lived (less than 2 days) and merged before they diverge significantly.

The alternative — long-lived feature branches — feels safer because developers work in isolation. The safety is illusory. Merge debt accumulates invisibly. The longer a branch lives, the more main has diverged, and the harder the eventual merge becomes. Teams that merge infrequently spend more time resolving conflicts than writing code, and discover integration problems late — when they're expensive to fix.

## Why Long-Lived Branches Are a Liability

Every day a feature branch lives, it accumulates "merge debt" against main:
- Changes to shared utilities that your branch doesn't have
- Refactors that rename symbols your branch still uses
- New tests that your code would fail
- Schema migrations your queries need to handle

This debt doesn't appear on any burndown chart. It only surfaces at merge time — often at a deadline, often as cascading conflicts that require hours to untangle.

More critically: long-lived branches delay integration testing. Two features that conflict won't be discovered until both are "done" and merging. At that point, there's no slack to renegotiate the design.

## Feature Flags for Incomplete Work

TBD doesn't mean shipping unfinished features — it means committing unfinished code behind a flag. The code is integrated (tested, type-checked, merged) but the feature isn't visible to users until it's ready.

```ts
if (featureFlags.isEnabled('new-checkout-flow', user.id)) {
  return <NewCheckout />;
}
return <LegacyCheckout />;
```

Feature flags decouple deployment from release. Code ships continuously; features release on a schedule. This also enables:
- Gradual rollout (enable for 5% of users)
- A/B testing
- Instant rollback without a deployment (disable the flag)

The overhead of maintaining flags is real but bounded. Delete flags promptly after full rollout — flag debt is a different kind of maintenance burden.

## Short-Lived Branches

When feature branches are used in TBD, the rule is: branches merge to main within 2 days. This bound prevents merge debt from accumulating to the point where conflicts become expensive.

In practice, this means:
- Break large features into small, independently mergeable increments
- Each increment must leave the codebase in a valid (passing tests, no broken behavior) state
- Use feature flags to merge incomplete increments safely

A branch that can't be merged within 2 days is a scope problem, not a branching problem. The feature needs to be decomposed further.

## Continuous Integration as a Requirement

TBD only works with fast, reliable CI. If the test suite takes 45 minutes, developers batch their commits to reduce CI runs, which is exactly the opposite of integration discipline.

CI for TBD must:
- Run on every commit to main
- Complete in under 10 minutes for fast feedback
- Block merges on test failure — no "we'll fix it after merge"
- Run the same suite in PR and post-merge

If CI is slow, fix CI — don't abandon TBD. Slow CI causes the same integration-delay problems as long-lived branches, just slightly later.

## When to Use Review Branches

Short-lived review branches (PR branches that exist only for code review, merged within 24 hours) are compatible with TBD. They're different from feature branches — they don't accumulate changes over days, they just gate review.

The rule: if a review branch is open longer than a day, either the review process is broken or the change is too large. Decompose the change.

## Key Rules

- **Branches older than 2 days accumulate merge debt** — merge frequently or pay it back with interest at the end.
- **Feature flags decouple deployment from release** — incomplete code can be merged safely behind a disabled flag.
- **CI must be fast (under 10 min) and mandatory** — slow or optional CI destroys the feedback loop that makes TBD work.
- **Decompose large features into independently mergeable increments** — if a branch can't merge in 2 days, the unit of work is too large.
- **Delete feature flags promptly after full rollout** — flag debt is as real as technical debt.
