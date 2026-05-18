# Plugin: ruflo-rag-memory

**What it provides:** Persistent vector-based memory using HNSW indexing. Semantic search across everything stored — finds relevant context even when you don't know the exact words.
**Key agent:** `ruflo-rag-memory:memory-specialist`
**Invoke skill:** `/ruflo-rag-memory:ruflo-memory`

## When to Use
- Searching for past decisions, patterns, or solutions by meaning (not exact words)
- Storing key facts that need to survive across sessions
- Building a searchable knowledge graph from project history
- Overnight batch sessions that need to recall prior work

## vs Other Memory Systems
```
memory_context / memory_search    → session-level key-value store (claude-mem plugin)
                                    Best for: exact key lookup, recent session data

ruflo-rag-memory                  → cross-session semantic vector search
                                    Best for: "find anything related to auth issues"
                                    More powerful but heavier

smart_search (claude-mem)         → comprehensive search across all corpora
                                    Best for: deep dive when ruflo not configured
```

## Core Operations

### Store a Memory
```typescript
// Via agent
Agent({
  subagent_type: "ruflo-rag-memory:memory-specialist",
  prompt: "Store this fact in the knowledge base: The JRS auto repair admin auth uses HMAC-SHA256 signed cookies, not JWT. Users are in data/admins.json."
})
```

### Semantic Search
```typescript
// Find relevant memories by meaning
Agent({
  subagent_type: "ruflo-rag-memory:memory-specialist",
  prompt: "Search for everything related to authentication issues or login problems in the JRS project"
})
```

### Graph RAG (multi-hop)
Finds context that's connected through multiple relationships:
```typescript
Agent({
  subagent_type: "ruflo-rag-memory:memory-specialist",
  prompt: "Starting from 'Supabase auth', traverse related concepts and find all connected decisions about session management"
})
```

## Session Start Pattern
```typescript
// Always search for relevant context at session start
Agent({
  subagent_type: "ruflo-rag-memory:memory-specialist",
  prompt: "Search for: recent work on [project name], any open issues, decisions made in last 3 sessions. Return structured summary."
})
```

## Memory Format for Storage
When storing memories, use structured format for better search:
```
PROJECT: [project name]
DATE: [date]
CONTEXT: [what was happening]
DECISION: [what was decided and why]
OUTCOME: [result]
TAGS: [auth, supabase, refactor, etc.]
```

## Hybrid Search Strategy
RAG memory does hybrid search (dense + sparse vectors) by default:
- Dense vectors: semantic similarity — finds "cookie-based auth" when you search "session management"
- Sparse vectors: keyword matching — finds exact technical terms
Result: better recall than either alone.

## When to NOT Use ruflo-rag-memory
- Simple session-to-session notes → use `memory_add` (claude-mem, lighter)
- Exact key lookup → use `memory_get` (faster, no vectorization)
- One-shot research that won't be referenced again → don't store it
