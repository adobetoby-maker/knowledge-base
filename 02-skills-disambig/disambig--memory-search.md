# Disambiguation — Memory and Search Tools

**Problem:** 4 overlapping memory/search systems. Each has different scope and latency.

## The Systems

| Tool | Scope | Speed | Best For |
|------|-------|-------|---------|
| `/mem-search` skill | All session history, indexed observations | Fast | "What did we work on last Tuesday?" "How did we fix X?" |
| `mcp__plugin_claude-mem_mcp-search__search` | Same as above — direct MCP call | Fast | When you need raw results, not skill-formatted output |
| `mcp__plugin_claude-mem_mcp-search__memory_search` | Named memories (stored with `memory_add`) | Fast | Key-value style lookups: "What is the deploy URL for X?" |
| `ruflo-rag-memory:recall` skill | AgentDB HNSW vector search | Medium | Semantic similarity: "anything related to authentication patterns" |
| `mcp__plugin_claude-mem_mcp-search__smart_search` | Multi-step: searches, unfolds, summarizes | Slow | Deep dives: "Everything we know about the manage-worker-bee blueprint system" |

## Decision Branch
- IF "what did we do recently on X?" → `/mem-search` or `mcp__plugin_claude-mem_mcp-search__search`
- IF "what is the value of [specific thing]?" → `mcp__plugin_claude-mem_mcp-search__memory_search`
- IF "find anything conceptually related to X" → `ruflo-rag-memory:recall`
- IF "give me comprehensive context on X" → `mcp__plugin_claude-mem_mcp-search__smart_search`
- IF searching the web, not memory → use Firecrawl, WebSearch, or Tavily (different system)

## Invoke Syntax
```
# Skill invocation
Skill("mem-search", "query here")

# Direct MCP
mcp__plugin_claude-mem_mcp-search__search({ query: "supabase auth", limit: 5 })
mcp__plugin_claude-mem_mcp-search__memory_search({ query: "jrs-auto-repair deploy url" })

# Ruflo RAG
Skill("ruflo-rag-memory:recall", "authentication patterns")
```

## For Overnight Batch Sessions
Load memory at the start of every session:
```
mcp__plugin_claude-mem_mcp-search__memory_context({})
```
This surfaces the most recent session context automatically.
Then use targeted search for task-specific history.

## Storage (Adding to Memory)
```
mcp__plugin_claude-mem_mcp-search__memory_add({ key: "jrs-url", value: "https://jrsautorepair.worker-bee.app" })
mcp__plugin_claude-mem_mcp-search__observation_add({ content: "Fixed the Supabase build crash using lazy init pattern" })
```
Observations are searchable. Named memories are retrievable by exact key.
