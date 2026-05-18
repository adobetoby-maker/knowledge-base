# Project: Memory System

## Overview

Multi-layer memory system for persisting context across Claude Code sessions.

## Layers

### 1. Flat-File Memory (GitHub-Synced)

```
~/.claude/projects/-Users-drive/memory/
  now.md          → current session buffer (overwritten each session)
  today-YYYY-MM-DD.md  → daily log
  recent.md       → last 7 days
  archive.md      → older than 7 days (compressed)
  core-memories.md → key moments, always kept
```

Synced to a private GitHub repo. On session start, `git pull` ensures latest state.

### 2. AgentDB / RuVector (Semantic Search)

Vector embeddings of memory entries, indexed with HNSW for semantic search.

```bash
# Search memory semantically:
claude-flow memory search --namespace claude-memories -q "query"

# Store a memory:
claude-flow memory store --namespace btw -k "KEY" --value "..."

# Note: ALWAYS use global claude-flow, never npx @claude-flow/cli@latest
claude-flow [command]
```

### 3. claude-mem (MCP)

RAG memory system available via MCP tools. Provides:
- `memory_search` — semantic search across all sessions
- `memory_add` — add a memory with context
- `smart_search` — context-aware multi-source search

### 4. .remember/ (Session Buffer)

In-session compressed memory for the current conversation:

```
.remember/
  now.md          → current session work (ring buffer)
  today-*.md      → today's log
  recent.md       → 7-day rolling
  archive.md      → compressed older entries
  core-memories.md
```

## Session Bootstrap

Memory loads automatically via `~/.claude/hooks.json` + `~/.claude/bootstrap/session-start.sh`:
1. `git pull` to sync from GitHub
2. `ruflo-bridge.sh` to sync to AgentDB
3. Session context injected via `sessionStart` hook

No manual steps needed.

## /btw Command

Captures a thought during a session for surfacing later:

```
/btw [project] [thought or task]
```

- Stores to memory namespace `btw` with key `btw-{project}-{timestamp}`
- If the note is a concrete task (contains action words), dispatches a background Haiku agent
- If it's a thought/idea, captures only

Examples:
```
/btw jrs add Portuguese translation toggle to hero
→ Dispatches Haiku agent to jrs-auto-repair

/btw nexus fee should be 0.25% not 0.5%
→ Captured only, surfaces on next /tac nexus
```

## /tac Command

Session bootstrap — pulls memory, shows project context, surfaces btw notes:

```
/tac                → asks what to work on, then mem-search
/tac jrs            → immediately focuses on jrs-auto-repair context
/tac nexus          → immediately focuses on dex-project/nexus context
```

## Memory CRUD

```bash
# Search:
mem-search "your query"              # semantic search
mem-get KEY [namespace]              # exact key lookup
mem-list [namespace]                 # list recent entries

# Store:
mem-store KEY "value" [namespace]    # store a note
```

## Backup and Recovery

Memory is backed up to GitHub. If local state is lost:
```bash
cd ~/.claude/projects/-Users-drive/memory
git pull origin main
```

If AgentDB state is lost:
```bash
bash ~/.claude/bootstrap/ruflo-bridge.sh
# Re-syncs all memory files → AgentDB
```
