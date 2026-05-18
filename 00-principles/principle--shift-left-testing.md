# Principle: Shift-Left Testing

## Overview
"Shift left" means moving quality checks earlier in the development lifecycle. A bug caught by a type checker in the IDE costs minutes to fix; the same bug caught in production after a customer files a report costs hours of investigation, a hotfix deploy, and potential data repair. The further right a defect travels, the more expensive it becomes — exponentially, not linearly.

## The Cost Curve
Each stage multiplies remediation cost roughly 10x:

| Stage caught | Relative cost |
|---|---|
| Type check / linting in IDE | 1x |
| Unit test failure | 3x |
| Pre-commit hook | 5x |
| CI pipeline | 15x |
| Staging environment | 40x |
| Production (caught by monitoring) | 100x |
| Production (reported by customer) | 300x+ |

This is why code coverage metrics misdiagnose the problem. Coverage percentage says nothing about *when* tests run — 80% coverage that only runs in CI is better than 0%, but a typed function signature that prevents a bug from ever being written is better still.

## Concrete Shift-Left Mechanisms

### Layer 1: Types in the IDE (free, always on)
TypeScript, Python type hints, Rust's type system — these run on every keystroke. A `string | null` return type forces the caller to handle `null` before the test suite even exists.

```typescript
// Bad: caller silently gets undefined at runtime
function getUser(id: string) {
  return users.find(u => u.id === id);
}

// Good: caller must handle null in the IDE, not in prod
function getUser(id: string): User | null {
  return users.find(u => u.id === id) ?? null;
}
```

### Layer 2: Linting on Save
ESLint, Biome, Ruff, Clippy — configured to run on file save, not just in CI. Unused variables, unreachable code, missing `await`, implicit `any` — caught before a commit is even staged.

### Layer 3: Unit Tests in Watch Mode
Run tests continuously during development (`vitest --watch`, `jest --watch`). The feedback loop shrinks from "push → wait 3 minutes → read CI logs" to "save file → see result in 200ms".

### Layer 4: Pre-Commit Hooks
The last gate before code leaves the developer's machine. Use `husky` or `lefthook`:
```bash
# .husky/pre-commit
npx tsc --noEmit
npx eslint --max-warnings 0
npx vitest run --reporter=verbose
```
Fail the commit if any check fails. This is not optional — CI catching what pre-commit should have caught is waste.

### Layer 5: Pre-Merge Integration Tests
Integration tests (real DB, real HTTP calls) run in CI against a dedicated test environment. Slower, but they must catch what unit tests cannot: query correctness, auth flows, third-party contract mismatches.

## What Shift-Left Is NOT
- It is not about writing 100% coverage at unit level. Integration and E2E tests have their place; shift them left by running them against ephemeral environments, not by eliminating them.
- It is not about slowing down development with bureaucracy. A 200ms watch-mode test loop is faster than a 3-minute CI cycle.
- It is not a one-time initiative. New test categories (accessibility, performance, security SAST) get added as near the left as tooling allows.

## Key Rules
- Every PR should fail locally before it fails in CI — if the developer couldn't have known without CI, the pre-commit hooks are inadequate
- Watch mode during active development, not just on-commit
- Type errors are bugs; enable strict TypeScript, never suppress with `any`
- Performance testing belongs in pre-merge CI, not post-deploy monitoring
- Shift security scanning left: `npm audit`, SAST (Semgrep) in pre-commit or CI, not a quarterly pen test
