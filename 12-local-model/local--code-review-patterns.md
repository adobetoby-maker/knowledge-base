# Local Model: Code Review Patterns

## Overview

Running automated code review via a local model enables: reviewing code without sending proprietary source to cloud APIs, running checks on every commit in CI without per-token cost, and applying team-specific standards consistently.

## When Local Model Code Review Makes Sense

Use local models for code review when:
- Codebase contains business logic you don't want in cloud API logs
- Running in CI where per-token API cost adds up across hundreds of commits
- Applying a fixed rubric (style guide, security patterns) where model size matters less
- Review is an automated filter, not a final approval

Use cloud models (larger, smarter) for:
- Architecture review requiring broad reasoning
- Novel code where context from across the codebase matters
- Final review before merging to production

## Prompt Structure for Code Review

```ts
const CODE_REVIEW_PROMPT = `You are a senior TypeScript/React engineer reviewing code for a production web app.

Review the following diff for:
1. Security vulnerabilities (XSS, SQL injection, auth bypasses, exposed secrets)
2. Logic errors and edge cases (null handling, off-by-one, race conditions)
3. Performance issues (N+1 queries, unnecessary re-renders, memory leaks)
4. Type safety issues (any casts, type assertions without guards)

For each issue found, output:
ISSUE: [severity: CRITICAL/HIGH/MEDIUM/LOW]
FILE: [filename]
LINE: [line number or range]
PROBLEM: [one sentence describing the issue]
FIX: [one sentence describing the fix]

If no issues are found, output: NO_ISSUES

Do not comment on style, formatting, or naming conventions.
Do not suggest refactors unless they fix a concrete issue.

Diff to review:
`
```

Restricting the scope (security, logic, performance, types only) reduces hallucinated style complaints that slow down review. Local models are more prone to inventing issues — a narrow scope produces more actionable output.

## Parsing Review Output

```ts
interface ReviewIssue {
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW'
  file: string
  line: string
  problem: string
  fix: string
}

function parseReviewOutput(output: string): ReviewIssue[] {
  if (output.includes('NO_ISSUES')) return []

  const issueBlocks = output.split(/(?=ISSUE:)/g).filter((b) => b.trim().startsWith('ISSUE:'))

  return issueBlocks.map((block) => {
    const severity = block.match(/ISSUE:\s*(CRITICAL|HIGH|MEDIUM|LOW)/)?.[1] as ReviewIssue['severity']
    const file = block.match(/FILE:\s*(.+)/)?.[1]?.trim() ?? 'unknown'
    const line = block.match(/LINE:\s*(.+)/)?.[1]?.trim() ?? 'unknown'
    const problem = block.match(/PROBLEM:\s*(.+)/)?.[1]?.trim() ?? ''
    const fix = block.match(/FIX:\s*(.+)/)?.[1]?.trim() ?? ''

    return { severity, file, line, problem, fix }
  }).filter((i) => i.severity && i.problem)
}
```

## CI Integration

```ts
// scripts/ai-review.ts
// Get diff from environment (set by CI from: git diff origin/main...HEAD -- "*.ts" "*.tsx")
const diff = process.env.GIT_DIFF ?? ''

if (!diff.trim()) {
  console.log('No TypeScript changes to review')
  process.exit(0)
}

// Chunk large diffs (local models have smaller context windows)
const MAX_DIFF_CHARS = 8000
const truncatedDiff = diff.length > MAX_DIFF_CHARS
  ? diff.slice(0, MAX_DIFF_CHARS) + '\n... (diff truncated for local model)'
  : diff

const output = await callOllama({
  model: 'codellama:13b',
  prompt: CODE_REVIEW_PROMPT + truncatedDiff,
  options: { temperature: 0.1, num_predict: 2048 },
})

const issues = parseReviewOutput(output)
const criticalOrHigh = issues.filter((i) => i.severity === 'CRITICAL' || i.severity === 'HIGH')

if (criticalOrHigh.length > 0) {
  console.error('CRITICAL/HIGH issues found:')
  criticalOrHigh.forEach((i) => {
    console.error(`  ${i.severity}: ${i.file}:${i.line} — ${i.problem}`)
    console.error(`    Fix: ${i.fix}`)
  })
  process.exit(1)
}
```

```yaml
# .github/workflows/ai-review.yml
- name: Get diff
  id: diff
  run: echo "GIT_DIFF=$(git diff origin/main...HEAD -- '*.ts' '*.tsx' | head -c 8000)" >> $GITHUB_ENV
- name: AI review
  run: npx tsx scripts/ai-review.ts
  env:
    GIT_DIFF: ${{ env.GIT_DIFF }}
```

Pass the diff via environment variable to avoid shell injection risks from running arbitrary git output in a script context.

## Model Selection for Code Review

| Model | Context | Speed | Quality |
|-------|---------|-------|---------|
| `codellama:7b` | 16k tokens | Fast | Good for syntax/security |
| `codellama:13b` | 16k tokens | Medium | Better reasoning |
| `deepseek-coder:6.7b` | 16k tokens | Fast | Strong for TypeScript/React |
| `qwen2.5-coder:7b` | 32k tokens | Medium | Best for large diffs |

Prefer code-specific fine-tuned models over general models. They produce fewer false positives on code patterns.

## Diff Size Limits

Local models have 8k–32k token context windows. A large PR diff (3,000+ lines) will exceed this. Strategies:
- Review per-file, not the entire diff
- Filter to only changed TypeScript/TSX files — skip lockfiles, generated types
- Prioritize files with the most changes
- Use a cloud model for large diffs, local model for small ones

```ts
// Split diff by file and review highest-risk files first
function splitDiffByFile(diff: string): Map<string, string> {
  const files = new Map<string, string>()
  const segments = diff.split(/^diff --git a\/.+ b\/(.+)$/m)
  // ... parse segments
  return files
}
```

## Calibration

Run the reviewer against known-buggy code to measure false negative rate, and against clean code to measure false positive rate. A reviewer that fails 30% of clean PRs destroys developer trust. Tune the prompt and severity thresholds until false positive rate is under 10%.

Log all issues found vs issues confirmed by human reviewers. Track model accuracy per issue type to identify where the model is unreliable.
