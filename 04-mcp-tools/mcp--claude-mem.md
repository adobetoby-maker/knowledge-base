# MCP: claude-mem — Memory and Search

## What It Does

claude-mem provides semantic memory storage and search for Claude Code sessions. It maintains a corpus of project observations and enables vector search across past work.

## Tool Reference

```
mcp__plugin_claude-mem_mcp-search__memory_add(content)
mcp__plugin_claude-mem_mcp-search__memory_search(query)
mcp__plugin_claude-mem_mcp-search__memory_context(query, limit?)
mcp__plugin_claude-mem_mcp-search__smart_search(query)
mcp__plugin_claude-mem_mcp-search__observation_add(entity, observation_type, content)
mcp__plugin_claude-mem_mcp-search__observation_search(query)
mcp__plugin_claude-mem_mcp-search__get_observations(entity_name)
mcp__plugin_claude-mem_mcp-search__timeline(limit?)
mcp__plugin_claude-mem_mcp-search__smart_outline(topic)
mcp__plugin_claude-mem_mcp-search__search(query, corpus_id?)
mcp__plugin_claude-mem_mcp-search__build_corpus(name, description)
mcp__plugin_claude-mem_mcp-search__prime_corpus(corpus_id)
```

## Memory Storage

```
memory_add("jrs-auto-repair admin auth uses cookie not Supabase JWT. verifyAdmin() in lib/adminAuth.ts")
memory_add("language-lens-elite is TanStack Start not Next.js. No 'use client' directive, no getServerSideProps")
memory_add("manage-worker-bee vault uses AES-256-GCM with master password in vault_session cookie")
```

Store structured facts about projects, patterns, and decisions. Each memory becomes searchable by semantic similarity.

## Memory Search

```
memory_search("auth system jrs auto repair")
→ Returns memories about auth in jrs-auto-repair

memory_search("which projects use Supabase")
→ Returns memories about Supabase usage across projects

memory_context("Next.js params promise", limit=5)
→ Returns top 5 most relevant memories with context
```

## Smart Search (Recommended for General Use)

```
smart_search("how does the blueprint canvas work")
→ Combines memory search + observation search + timeline for best results
```

Use `smart_search` when you need broad context. Use `memory_search` when you have a specific question.

## Observation System

Observations are structured notes attached to named entities:

```
observation_add(
  entity="jrs-auto-repair",
  observation_type="architecture",
  content="Two auth systems: admin cookie for /admin, Supabase JWT for /portal. Never mix."
)

observation_add(
  entity="manage-worker-bee",
  observation_type="api",
  content="Blueprint update API: POST /api/blueprints/update with x-api-key header"
)
```

Retrieve entity observations:
```
get_observations("jrs-auto-repair")
→ All stored observations about this project
```

## Corpus Management

Corpora are curated collections for specific purposes:

```
build_corpus("project-knowledge", "Project architecture and patterns")
prime_corpus(corpus_id)  ← Indexes all current memories into the corpus
```

Then search within a specific corpus:
```
search("auth pattern", corpus_id=project_knowledge_id)
```

## What to Store in Memory

Good candidates:
- Project-specific rules and gotchas discovered during work
- Decisions made with rationale
- Non-obvious relationships between files/systems
- Recurring patterns that took investigation to discover

Not worth storing:
- Things already in CLAUDE.md (already in context)
- General web development knowledge (already in model training)
- Temporary debugging notes

## Timeline View

```
timeline(limit=20)
→ Chronological list of recent memory additions and observations
```

Use to understand what was recently added and find patterns in what's being learned.

## Integration with Session Bootstrap

The session bootstrap calls `smart_search` with the current project name to pull in recent relevant context before work begins. This auto-loads the project's accumulated knowledge without manual retrieval.
