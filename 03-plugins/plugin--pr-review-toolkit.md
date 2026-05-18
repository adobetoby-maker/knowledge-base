# Plugin: pr-review-toolkit

**What it provides:** A suite of specialized review agents. Each covers one dimension of code quality. More granular and targeted than a general review.
**Agents:** `code-reviewer`, `code-simplifier`, `comment-analyzer`, `pr-test-analyzer`, `silent-failure-hunter`, `type-design-analyzer`

## The Six Agents and When to Use Them

### code-reviewer
General quality, style, bugs, project convention adherence.
```typescript
Agent({ subagent_type: "pr-review-toolkit:code-reviewer", prompt: "Review unstaged changes..." })
```
Trigger: After writing a feature. Before opening a PR.

### code-simplifier
Refactors finished code for clarity without changing behavior.
```typescript
Agent({ subagent_type: "pr-review-toolkit:code-simplifier", prompt: "Simplify recent changes in..." })
```
Trigger: After code is working correctly. Cleanup pass before merging.

### comment-analyzer
Checks if comments are accurate, not stale, not misleading.
```typescript
Agent({ subagent_type: "pr-review-toolkit:comment-analyzer", prompt: "Check comments in..." })
```
Trigger: When adding or reviewing documentation comments.

### pr-test-analyzer
Reviews test coverage completeness — are the important cases tested?
```typescript
Agent({ subagent_type: "pr-review-toolkit:pr-test-analyzer", prompt: "Review test coverage for..." })
```
Trigger: Before merging any feature with tests.

### silent-failure-hunter
Hunts for catch blocks that silently swallow errors, fallbacks that hide bugs.
```typescript
Agent({ subagent_type: "pr-review-toolkit:silent-failure-hunter", prompt: "Hunt silent failures in..." })
```
Trigger: Any code with try-catch, fallback values, optional chaining chains.

### type-design-analyzer
Reviews TypeScript type design — are types expressive? Do they enforce invariants?
```typescript
Agent({ subagent_type: "pr-review-toolkit:type-design-analyzer", prompt: "Analyze type design in..." })
```
Trigger: After defining new interfaces or complex types.

## Full PR Review — All Agents
For a comprehensive pre-merge review, run all six:
```typescript
// Single message — all run in parallel
Agent({ subagent_type: "pr-review-toolkit:code-reviewer", prompt: "..." })
Agent({ subagent_type: "pr-review-toolkit:silent-failure-hunter", prompt: "..." })
Agent({ subagent_type: "pr-review-toolkit:pr-test-analyzer", prompt: "..." })
Agent({ subagent_type: "pr-review-toolkit:type-design-analyzer", prompt: "..." })
```
Don't run code-simplifier and code-reviewer at the same time — simplifier runs after reviewer.

## Most Used for This Stack
For Next.js/Supabase projects:
1. `code-reviewer` — catches convention issues
2. `silent-failure-hunter` — Supabase error handling is frequently silent
3. `pr-test-analyzer` — Vitest coverage in jrs-auto-repair

## When to Skip These
- Quick config changes → no review needed
- Content-only changes (articles, copy) → no code review needed
- Prototype code clearly marked as temporary → review when it becomes permanent
