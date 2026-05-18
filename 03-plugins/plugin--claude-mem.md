# Plugin: claude-mem@thedotmack

**What it provides:** Session memory, semantic search across history, observation logging, timeline reports.
**When to reach for it:** Remembering what was done in past sessions, finding prior decisions, storing important facts for future sessions.

## Key Skills

| Skill | When to Use |
|-------|-------------|
| `claude-mem:mem-search` | Search past session history. Most common memory operation. |
| `claude-mem:make-plan` | Create a plan stored in memory for multi-session work |
| `claude-mem:do` | Execute a stored plan step |
| `claude-mem:timeline-report` | Generate a chronological report of past work |
| `claude-mem:learn-codebase` | Analyze and memorize a codebase structure |
| `claude-mem:smart-explore` | Explore + memorize a codebase intelligently |
| `claude-mem:babysit` | Monitor a long-running process, logging observations |
| `claude-mem:how-it-works` | Explain the memory system itself |
| `claude-mem:knowledge-agent` | Agent that queries knowledge base for you |
| `claude-mem:pathfinder` | Find connections between topics across memory |
| `claude-mem:wowerpoint` | Generate a summary presentation from memory |

## Key MCP Tools

```javascript
// Load schemas
ToolSearch("select:mcp__plugin_claude-mem_mcp-search__search,mcp__plugin_claude-mem_mcp-search__observation_add")

// Search history
mcp__plugin_claude-mem_mcp-search__search({ query: "how did we fix X", limit: 5 })

// Store a named memory
mcp__plugin_claude-mem_mcp-search__memory_add({ key: "jrs-supabase-url", value: "https://xxx.supabase.co" })

// Retrieve a named memory  
mcp__plugin_claude-mem_mcp-search__memory_search({ query: "jrs-supabase-url" })

// Log an observation (searchable)
mcp__plugin_claude-mem_mcp-search__observation_add({ content: "Fixed Supabase build crash — used lazy init at lib/supabase/admin.ts:3" })

// Get recent context (run at session start)
mcp__plugin_claude-mem_mcp-search__memory_context({})

// Smart search (slower but comprehensive)
mcp__plugin_claude-mem_mcp-search__smart_search({ query: "blueprint store data model" })

// Timeline
mcp__plugin_claude-mem_mcp-search__timeline({ days: 7 })
```

## Overnight Batch Pattern
At the start of every autonomous session:
```
1. mcp__plugin_claude-mem_mcp-search__memory_context({}) → load recent context
2. mcp__plugin_claude-mem_mcp-search__search({ query: "[task topic]" }) → find relevant prior work
3. [do the work]
4. mcp__plugin_claude-mem_mcp-search__observation_add({ content: "What was accomplished and any decisions made" })
```
This creates a trail that the next session can pick up.

## What to Store vs Not Store
**Store:**
- Deploy URLs (keyed by project)
- Important decisions with their reasons
- Credentials/keys (use memory_add with clear key names)
- "We solved X by doing Y" observations
- Anything you'd otherwise google again

**Don't store:**
- Code (store file paths instead)
- Temporary values
- Things already in CLAUDE.md

## Memory Decay
Memories don't expire but search quality degrades with volume.
Run `mcp__plugin_claude-mem_mcp-search__smart_search` for deep topics.
Use exact key names with `memory_search` for precise retrieval.
