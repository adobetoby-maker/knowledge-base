# MCP: Memory Operations (claude-mem)

## Overview
The `claude-mem` memory MCP allows facts, decisions, and events to persist across sessions. Without it, every conversation starts from zero context. The core discipline is storing immediately after significant decisions or discoveries—not at the end of a session when details blur. Namespacing memories by project prevents cross-contamination and enables scoped recall.

## Core Tools

| Tool | Purpose |
|---|---|
| `memory_add` | Store a persistent fact or knowledge item |
| `memory_search` | Retrieve memories by semantic similarity to a query |
| `memory_context` | Get full context for a memory item |
| `observation_add` | Record a time-stamped event or decision |
| `observation_search` | Find events by description |
| `observation_record_event` | Record structured events with metadata |
| `timeline` | View chronological history of observations |

## What to Store

### Store After Architecture Decisions
```
memory_add:
  content: "manage-worker-bee uses a single service-role Supabase client (lib/supabase.ts).
            No SSR cookie variants — auth is disabled for this internal tool."
  namespace: "manage-worker-bee"
  tags: ["architecture", "supabase", "auth"]
```

### Store After Discovering a Non-obvious Pattern
```
memory_add:
  content: "jrs-auto-repair has TWO auth systems. Admin: cookie 'admin_session',
            users in data/admins.json, logic in lib/adminAuth.ts.
            Portal: Supabase JWT. NEVER mix them."
  namespace: "jrs-auto-repair"
  tags: ["auth", "architecture", "critical"]
```

### Record Decisions as Observations
```
observation_add:
  content: "Decided to use RS256 over HS256 for JWT signing in silver-creek-logistics.
            Reason: Cloudflare Worker needs to verify tokens without sharing secret with Vercel."
  namespace: "silver-creek-logistics"
  category: "decision"
```

### Record Bugs Found and Fixed
```
observation_add:
  content: "Fixed: language-lens-elite KanaPad was creating new debounced function on every
            render. Moved debounce into useMemo. File: src/components/kana/KanaPad.tsx"
  namespace: "language-lens-elite"
  category: "bug-fix"
```

## Retrieving Context at Session Start
```
// Load project context before starting work
memory_search:
  query: "jrs-auto-repair architecture auth database"
  namespace: "jrs-auto-repair"
  limit: 10
→ returns most relevant stored facts

// Load recent decisions
observation_search:
  query: "decisions made this week"
  namespace: "silver-creek-logistics"
  since: "2026-05-11"
```

## Namespacing Strategy
```
Namespaces by project:
  "jrs-auto-repair"          → all facts about that project
  "manage-worker-bee"        → manage-worker-bee specific
  "language-lens-elite"      → LinguaLens specific
  "silver-creek-logistics"   → logistics project

Cross-project knowledge:
  "architecture-patterns"    → general patterns that apply everywhere
  "tools-and-plugins"        → library-specific knowledge
  "decisions"                → significant cross-project decisions
```

## Timeline for Session Replay
```
// Review what happened in last session
timeline:
  namespace: "language-lens-elite"
  since: "2026-05-17"
→ chronological list of observations

// Useful for: picking up where you left off, debugging "what changed"
```

## Key Rules
- **Store immediately, not at session end** — details degrade fast; store right after a decision or discovery.
- **Namespace by project** — cross-namespace searches are noisier; scoped searches are precise.
- **`observation_add` for events, `memory_add` for facts** — events have timestamps and categories; facts are static knowledge.
- **Include file paths in bug fix observations** — makes the observation actionable in a future session.
- **`memory_search` at session start for new projects** — don't rediscover architecture decisions already made.
- **Tag critical memories** — use `tags: ["critical", "arch"]` for facts that must always come up in searches.
- **Be specific in content** — "auth is disabled" is useless; "auth is disabled in proxy.ts — it's an internal tool" is actionable.
