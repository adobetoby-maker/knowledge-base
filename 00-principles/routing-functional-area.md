# Functional Area Resolver — Context Routing Without Bloat

**When:** Starting any task in the knowledge base system. As the library grows past 100 files, loading everything bloats context. This file tells you which 3-5 files to load.
**Rule:** Load the minimum set that covers the task. Three well-chosen files beat ten loosely relevant ones.

## The Dispatch Logic

Before loading ANY knowledge files, classify the task:

```
Is it a UI/Frontend task?
  → 05-patterns/nextjs--rsc-bundle-boundary.md
  → 05-patterns/react--state-management.md
  → 05-patterns/css--animation-patterns.md (if motion involved)
  → 05-patterns/performance--bundle-analysis.md (if performance)

Is it a data/backend task?
  → 05-patterns/supabase--rls-patterns.md
  → 05-patterns/nextjs--server-actions-vs-api-routes.md
  → 06-failures/failure--supabase-empty-results.md

Is it an auth task?
  → 05-patterns/auth--two-system-pattern.md
  → 06-failures/failure--supabase-auth-cookie.md
  → 00-principles/security-boundaries.md

Is it a deployment/infra task?
  → 03-plugins/plugin--vercel.md
  → 03-plugins/plugin--cloudflare.md
  → 06-failures/failure--vercel-env-vars-build.md

Is it an SEO/content task?
  → 09-seo-content/seo--article-structure.md
  → 09-seo-content/seo--keyword-research.md
  → 09-seo-content/seo--content-cluster-strategy.md
  → 07-projects/project--jrs-auto-repair.md (if for JRS)

Is it an overnight/local model task?
  → 11-overnight-batch/overnight--session-structure.md
  → 11-overnight-batch/overnight--safe-vs-unsafe-ops.md
  → 12-local-model/local--model-constraints.md
  → 12-local-model/local--ollama-setup.md

Is it an agent orchestration task?
  → 08-agents/agents--when-to-spawn.md
  → 08-agents/agents--parallel-pattern.md
  → 08-agents/agents--writing-effective-prompts.md
  → 08-agents/agents--cost-optimization.md

Is it a project-specific task?
  → 07-projects/project--[project-name].md (always load first)
  → then the functional area files above
```

## Stack Bundle Shortcut (Local Models)
For local model sessions where context is tight, use pre-merged bundles in `13-stack-bundles/`:
- `bundle--nextjs-supabase-feature.md` — frontend + DB work
- `bundle--cloudflare-workers-feature.md` — Workers + D1/KV work
- `bundle--tanstack-start-cloudflare.md` — language-lens-elite work
- `bundle--supabase-auth-feature.md` — auth-focused work

One bundle file replaces 5-8 individual files.

## Loading Order
```
1. 00-principles/blast-radius.md          (always — sets autonomy rules)
2. 07-projects/project--[name].md         (always if project-specific)
3. Functional area files (3-5 max)        (from dispatch above)
4. memory/corrections-log.md             (always — most recent mistakes)
```

## Context Budget
```
Claude (large context): load freely
Local model (8k effective): max 3-4 files, use stack bundles
Haiku agent (cheap, focused): max 2 files
```

## Growing the Resolver
When a new file type becomes frequently needed, add it to the dispatch table above. The resolver is only useful if it stays current.
