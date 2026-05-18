# Plugin: ruflo-core

**What it provides:** Three specialist agents: coder (implements), researcher (explores), reviewer (audits).
**Agents:** `ruflo-core:coder`, `ruflo-core:researcher`, `ruflo-core:reviewer`

## When to Use Each Agent

### ruflo-core:researcher
**Use for:** Deep codebase exploration, tracing execution paths, understanding architecture, finding where things are defined.
```typescript
Agent({
  subagent_type: "ruflo-core:researcher",
  prompt: "Trace the full execution path when a user submits the contact form in jrs-auto-repair. 
           Start from the form submission, through the server action, to the database. 
           Map every file touched and every external call made."
})
```
Returns: Architecture map, dependency graph, execution trace — no code written.

### ruflo-core:coder
**Use for:** Implementing a specific feature with a known design. Works best after researcher has mapped the codebase.
```typescript
Agent({
  subagent_type: "ruflo-core:coder",
  prompt: "Implement the promo banner component.
           Design: src/components/PromoBanner.tsx — blue banner, dismiss button (localStorage).
           Add to app/layout.tsx below the Navbar component.
           Follow the pattern in src/components/Card.tsx for style conventions."
})
```
Returns: Written/edited files.

### ruflo-core:reviewer
**Use for:** Quality audit of completed code. Checks bugs, logic errors, security issues, project convention adherence.
```typescript
Agent({
  subagent_type: "ruflo-core:reviewer",
  prompt: "Review the changes in src/components/PromoBanner.tsx and app/layout.tsx.
           Check for: (1) security issues, (2) proper TypeScript types, (3) correct Tailwind classes,
           (4) localStorage usage on server (should be client-only).
           Report issues with file:line references and severity."
})
```
Returns: Numbered list of findings, no code written.

## Ideal Workflow Pattern
```
1. researcher: "Map the auth system"
   ↓ returns: architecture understanding
2. coder: "Given the architecture, implement X"
   ↓ returns: code changes
3. reviewer: "Review the code changes"
   ↓ returns: issues list
4. coder: "Fix issue 1 and issue 3" (skip P2s)
```

## vs Other Code Agents
```
feature-dev:code-explorer   → broader codebase exploration (good for unfamiliar projects)
feature-dev:code-architect  → designs implementation plan (no code written)
feature-dev:code-reviewer   → review with project convention focus
ruflo-core:researcher       → deeper execution trace, dependency mapping, RuVector integration
ruflo-core:coder            → implementation with memory of prior research
ruflo-core:reviewer         → review with security focus + confidence filtering
```

## When to Use ruflo-core vs feature-dev
```
New to a codebase → feature-dev:code-explorer (better for orientation)
Deep debugging    → ruflo-core:researcher (better execution tracing)
Security focus    → ruflo-core:reviewer (specifically checks security)
Standard review   → feature-dev:code-reviewer (faster for code quality)
```
