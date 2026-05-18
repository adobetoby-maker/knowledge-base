# Agent Memory Patterns

## The Memory Problem

AI agents have no native memory across sessions. Every session starts blank. Without externalized memory:
- The same mistakes get made repeatedly
- Context from past sessions must be reconstructed from scratch
- Decisions made in previous sessions are unknown

The solution: externalize memory into files and databases that persist across sessions.

## Memory Tiers

**Tier 1 — Active context:** What's in the current conversation window. Fast, temporary, limited (200k tokens). Evicted when session ends.

**Tier 2 — Session file memory:** Markdown files on disk. Persist across sessions. Loaded by the session bootstrap. Structured (corrections-log, trajectory, project files).

**Tier 3 — Semantic search memory:** Vector database (AgentDB via claude-flow). Indexed by meaning, not exact key. Retrieved by query similarity, not exact match.

**Tier 4 — Structured database:** Supabase tables. Queryable by any column. Persistent, relational. High retrieval precision.

## Tier 2: Structured File Memory

### corrections-log.md
Living document of project-specific rules learned from mistakes.

```markdown
## [Project] Rules

**A1:** Use `verifyAdmin` from lib/adminAuth.ts, not `verifyAdminSession` (doesn't exist)
**P1:** Blog lives at /blog, not /articles
**N3:** params is a Promise in Next.js 15+: const { slug } = await params
```

Read this file at the start of any session touching the related project.

### session-trajectory.md
Chronological log of what happened in past sessions.

```markdown
## 2026-05-17 | jrs-auto-repair | Auth debugging
COMPLETED: Fixed portal auth redirect loop → app/portal/layout.tsx:23
FAILED: Attempted to add D1 transactions → Supabase doesn't support this
LEARNED: Portal uses Supabase JWT, admin uses cookie — never mix
```

Read when starting work on a project that had recent activity.

## Tier 3: Semantic Search

claude-flow memory system:

```bash
# Store a note
claude-flow memory store --namespace btw -k "btw-nexus-20260517" --value "[BTW] nexus: fee should be 0.25%"

# Semantic search
claude-flow memory search --namespace claude-memories -q "nexus fee configuration"

# List recent
claude-flow memory list --namespace btw
```

Use semantic search when you need to find related past work by concept rather than exact key.

## AgentDB (Ruflo Memory)

For vector search with HNSW indexing:

```
mcp__plugin_claude-mem_mcp-search__memory_search(query)
mcp__plugin_claude-mem_mcp-search__memory_add(content)
mcp__plugin_claude-mem_mcp-search__smart_search(query)
```

`smart_search` uses multiple retrieval strategies — use it for general queries. `memory_search` is faster for focused queries where the query term is known.

## Memory Write Triggers

Write to memory when:
- A mistake was made and corrected → corrections-log.md
- A decision was made with rationale → session-trajectory.md
- A project fact is discovered → project file or corrections-log
- A task completed successfully → session-trajectory COMPLETED
- A task failed → session-trajectory FAILED + corrections-log if pattern applies

## Memory Read Triggers

Read memory before:
- Starting work on a project (session-trajectory + corrections-log)
- Making an architectural decision (search for similar past decisions)
- Encountering a failure (search for past failures with similar symptoms)
- Running overnight batch (load all relevant constraints as hard rules)

## Preventing Memory Drift

Memory that contradicts itself is worse than no memory. Rules:
1. When a rule in corrections-log is superseded, strike through the old rule and add the new one (don't just add)
2. Session trajectory entries are append-only — never edit past entries
3. Semantic memory (AgentDB) accumulates — periodically consolidate to remove redundant entries

## The Bootstrap Contract

The session bootstrap (from TAC or equivalent) is responsible for:
1. Pulling latest memory from GitHub
2. Loading corrections-log into active context
3. Searching trajectory for recent project work
4. Presenting that context before any task begins

This contract means: if the bootstrap is skipped, memory doesn't auto-load. Verify the bootstrap ran when starting autonomous sessions.
