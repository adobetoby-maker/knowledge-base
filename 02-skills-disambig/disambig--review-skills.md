# Disambiguation — Review Skills

**Problem:** 9+ review-related skills exist. Most models pick the wrong one.

## The Options and When to Use Each

| Skill | Use When |
|-------|----------|
| `/review` | Quick quality check on code you just wrote. General staff-engineer review. |
| `feature-dev:code-reviewer` | Reviewing a specific feature branch before merge. Checks bugs, logic errors, security, project conventions. |
| `coderabbit:code-review` | Deep automated review with inline comments. Use before creating a PR, not after. |
| `/production-code-audit` | Deep scan of an entire codebase. Use when onboarding to a new project or auditing for tech debt. Slow — don't use for single files. |
| `/code-review-excellence` | When review quality itself is the goal — teaches review patterns. |
| `/differential-review` | Comparing before/after a refactor. Shows what changed and why it matters. |
| `/vibers-code-review` | Fast vibes-based sanity check. Use when you just want "does this look right?" |
| `pr-review-toolkit:review-pr` | Full PR review including test coverage, type design, error handling. Use before merging a PR. |
| `/comprehensive-review-full-review` | Nuclear option — every angle, every file. Use for security-sensitive code or before major releases. |

## Quick Decision Tree
```
Just wrote code and want sanity check → /review
About to open a PR → coderabbit:code-review or pr-review-toolkit:review-pr
Auditing an unfamiliar codebase → /production-code-audit
Specific bug suspicion → /investigate
Security concern → /cso or /comprehensive-review-full-review
Want to understand what changed → /differential-review
```

## What Each Returns
- `/review` — prose feedback, usually 200-500 words
- `feature-dev:code-reviewer` — structured list of issues with file:line references
- `coderabbit:code-review` — PR-style inline comments
- `/production-code-audit` — full report, takes 5-10 minutes
- `pr-review-toolkit:review-pr` — structured report across multiple review dimensions

## Invoke Syntax
```
Skill("review")
Skill("feature-dev:code-reviewer")
Skill("coderabbit:code-review")
Agent({ subagent_type: "feature-dev:code-reviewer", ... })
Agent({ subagent_type: "coderabbit:code-reviewer", ... })
```
