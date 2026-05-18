# Principle: Ownership Model

## Overview
Ownerless code becomes technical debt nobody touches. When a service, module, or feature has no clear owner, it suffers from diffusion of responsibility: everyone assumes someone else is handling the oncall alert, the dependency upgrade, the performance regression. Explicit code ownership — codified in tooling, not just in shared understanding — creates accountability, speeds up code review, and provides a clear escalation path when something breaks.

## CODEOWNERS File

GitHub and GitLab support a `CODEOWNERS` file that auto-assigns reviewers to PRs based on which files were changed:

```
# .github/CODEOWNERS

# Default owner for everything not explicitly listed
*                           @platform-team

# Payments domain
/src/payments/              @alice @payments-team
/src/billing/               @alice @payments-team

# Auth service
/src/auth/                  @bob @security-team

# Infrastructure and CI
/.github/                   @devops-team
/terraform/                 @devops-team
/docker-compose*.yml        @devops-team

# Shared components — require two reviewers
/src/components/core/       @alice @bob @carol
```

Every PR that touches a file automatically requests a review from its owner. The PR cannot be merged without owner approval (enforced via branch protection rules).

## What Ownership Covers

Owning a service or module means:
- You are the first oncall responder for alerts from that service
- You review and approve PRs that change that code
- You own the roadmap for that service's technical evolution
- You make the call on architectural decisions within the service
- You update dependencies when critical CVEs drop
- You write and maintain runbooks for common failure modes

Ownership is not about being the only person who can change the code — it is about accountability. Anyone can contribute a PR; the owner reviews it.

## Team Ownership vs Individual Ownership

Individual ownership creates bus-factor risk (one person leaves, knowledge is gone). Team ownership with a designated lead is better:

```
# CODEOWNERS
/src/payments/              @payments-team
```

`@payments-team` is a GitHub team with 3-4 members. Any of them can approve. The team has a lead who is accountable for the service's health.

Individual ownership is acceptable for small codebases or for components that truly require specialized knowledge — document the bus factor risk explicitly.

## Ownership Registry

For large organizations, maintain a human-readable ownership registry beyond CODEOWNERS:

```yaml
# services/ownership.yml
services:
  - name: payment-service
    owner: payments-team
    lead: alice@company.com
    oncall: https://pagerduty.com/service/payment-service
    runbook: https://docs.internal/payments/runbook
    dependencies: [stripe-api, postgres, redis]
    
  - name: auth-service
    owner: security-team
    lead: bob@company.com
    oncall: https://pagerduty.com/service/auth-service
    runbook: https://docs.internal/auth/runbook
```

## Orphaned Code

When a team is restructured or a person leaves, code can become orphaned. Quarterly ownership audits:

```bash
# Find directories not listed in CODEOWNERS
git ls-files | xargs dirname | sort -u | while read dir; do
  grep -q "^/$dir" .github/CODEOWNERS || echo "UNOWNED: $dir"
done
```

Unowned code gets temporarily assigned to the platform team until a proper owner is designated.

## Key Rules
- `.github/CODEOWNERS` is a required file in every repository
- Every file has an owner — no unowned code
- Owners are teams, not individuals (unless team is 1 person)
- PR auto-assignment from CODEOWNERS is enforced (branch protection: require code owner review)
- Ownership includes oncall, not just code review
- Quarterly audits for orphaned code
- Ownership changes require a PR to `CODEOWNERS` — treated as a significant change
- New services start with ownership defined before the first commit
