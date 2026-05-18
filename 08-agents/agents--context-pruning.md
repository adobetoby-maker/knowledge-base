# Agent Pattern: Context Pruning

## Overview
Context quality determines output quality more than context quantity. Providing an entire codebase when only 5 files are relevant wastes tokens, inflates cost, and — more importantly — dilutes the signal with noise. Agents performing well on a focused 20K-token context consistently outperform the same agent on a bloated 100K-token context. Pruning is a pre-task discipline.

## Implementation

### What to Prune (Remove Before the Task)

**Always remove:**
- Lock files (`package-lock.json`, `yarn.lock`) — never needed for code generation
- Generated files (`dist/`, `build/`, `.next/`) — derivatives of the source
- Verbose API response examples that aren't directly relevant
- Boilerplate configuration files that aren't involved in the task
- Test fixtures and mock data unless the task is about tests
- Changelog and README files unless the task is documentation

**Usually remove:**
- Files in directories not referenced by the task description
- Complete type definition files when only 2-3 types are needed (inline the relevant types instead)
- Commented-out code blocks
- Duplicate implementations (keep the canonical one, note the duplicate exists)

**Keep:**
- Type definitions for all types the new code will produce or consume
- The error message or failing test output that describes the problem
- The file being changed AND the files it imports from / is imported by
- Any configuration file that affects the behavior being changed

### Pruning Strategy by Task Type

**Bug fix:**
- Keep: the failing file, the error message, the test that fails
- Remove: everything else — often just 1-3 files are sufficient

**New feature:**
- Keep: the route file, the DB schema file, the auth middleware, the type file
- Remove: unrelated routes, other feature domains

**Refactor:**
- Keep: the files being refactored + their direct dependencies
- Remove: files that import from the refactored code (they'll be updated after)

### Measuring Effectiveness
Before pruning: note total context tokens and file count
After pruning: note reduced counts

A 50% token reduction is achievable on most tasks. A 70% reduction is common for bug fixes. If you can't reduce by at least 30%, reconsider what "relevant" means for the task.

### Inline Extraction
Instead of including an entire 500-line type definitions file, extract only the relevant types:
```
// From src/types/invoice.ts — relevant types only:
type Invoice = { id: string; status: "draft" | "pending" | "paid"; total: number; }
type CreateInvoiceInput = { customerId: string; lineItems: LineItem[]; }
// (Full file has 40+ types — only these two are needed for this task)
```

## Key Rules
- Prune before starting the task, not after — the benefit is in reducing context size before the agent processes it
- Never remove error messages or stack traces — they're the highest-signal content for debugging tasks
- When uncertain what to prune, ask: "If this file were missing, would the agent produce a different output?" If no, remove it
- Pruning 50% of context typically produces 50% faster + cheaper + more focused results — the math is direct
- Always keep type definitions for the interfaces the new code must implement — missing types cause hallucinated APIs
- Document what was pruned so the agent can ask for more context if needed: "Note: auth middleware context pruned — ask if auth integration questions arise"
