# Agents: Shared Memory Across Agents

## Overview
Individual agents have working memory (their context window). Multi-agent systems need shared memory so that knowledge discovered by one agent is available to others without re-discovery. Without shared memory, agents duplicate work, make inconsistent decisions, and lose information when they terminate. With poorly designed shared memory, they corrupt each other's state. The design of shared memory is often the most important architectural decision in a multi-agent system.

## Memory Layer Types

**Vector store (semantic memory)**
- Stores embeddings of text chunks
- Retrieval by semantic similarity: "what do we know about X?"
- Best for: research findings, unstructured knowledge, retrieved documents
- Writes: any agent can write (with write isolation to prevent conflicts)
- Reads: any agent can read
- Tool: Pinecone, Weaviate, pgvector, Chroma

**Key-value store (structured facts)**
- Stores specific, named facts: `user_name`, `task_status`, `confirmed_budget`
- Retrieval by exact key: fast, deterministic
- Best for: task state, configuration, confirmed decisions, entity attributes
- Writes: typically only the orchestrator writes task state; workers write their own findings
- Reads: all agents

**Event bus / activity log**
- Append-only record of what happened: "Agent A completed web search", "Agent B found 3 results", "Orchestrator assigned task 2"
- Enables agents to understand the current state of the system without asking other agents
- Never delete events — append only
- Best for: coordination, audit trail, replay

**Agent-specific working memory**
- Private to each agent for the duration of its execution
- The agent's context window + any scratchpad state
- Discarded when the agent completes
- Not shared — prevents interference between agents on parallel tasks

## Memory Handoff on Spawn

When the orchestrator spawns a sub-agent, it passes relevant context explicitly. This is not automatic — the orchestrator must decide what to pass.

Pass to the spawned agent:
- Task specification
- Relevant facts from K-V store (pre-fetched, not live access during spawn)
- Pointers to relevant vector store documents (queries the agent should run)
- Constraints discovered during orchestration
- Expected output schema

Do not pass:
- Full conversation history (give the agent only what it needs)
- Facts unrelated to its task (increases cost, dilutes attention)

## Write Isolation

When multiple agents write to the same memory store simultaneously:
- K-V store: use atomic operations (compare-and-swap) for shared keys to prevent last-write-wins conflicts
- Vector store: partition by agent or task to prevent one agent's writes from contaminating another's search results
- Never allow two agents to write to the same vector namespace concurrently without coordination

## Memory Lifecycle

- **During task**: vector store and K-V store are read/write active
- **After task completion**: important findings are persisted; ephemeral state is cleaned up
- **Between sessions**: only genuinely persistent knowledge is retained; task-specific state is expired
- **TTL on K-V entries**: set expiration for task-specific keys to prevent stale state accumulation

## Key Rules

- Choose memory type by access pattern: semantic search → vector store; exact lookup → K-V store; coordination → event log
- Write isolation is mandatory for concurrent agents — last-write-wins produces silent data corruption
- Sub-agents get a curated context packet on spawn, not access to the full shared memory
- Event log is append-only — never delete events during execution
- Expire task-specific K-V keys after task completion — stale state in shared memory causes future task contamination
- Vector stores should be partitioned by domain or task to prevent cross-contamination of search results
