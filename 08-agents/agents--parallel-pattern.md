# Agent Pattern: Parallel Execution

**When:** Multiple independent research tasks, multiple files to write with no dependencies, or multiple audits to run simultaneously.
**Rule:** Single message = parallel execution. Multiple messages = sequential execution. Always batch independent work into one message.

## How Parallel Agents Work
When you put multiple Agent tool calls in a single response message, they ALL start simultaneously. The orchestrator receives all results before composing the final response.

```
Single message with 3 agents:
  → Agent A starts  (t=0)
  → Agent B starts  (t=0)  ← all at once
  → Agent C starts  (t=0)
  ← Agent C returns (t=15s)
  ← Agent A returns (t=22s)
  ← Agent B returns (t=30s)
  Total: 30s (not 67s sequential)
```

## Pattern 1 — Parallel Research
```
Task: "Research 3 things about this project"
Send in ONE message:
  Agent(research competitor analysis)
  Agent(research user interview themes)
  Agent(research tech stack options)
```

## Pattern 2 — Parallel File Generation
```
Task: "Create service pages for 5 cities"
Send in ONE message:
  Agent(write Twin Falls page)
  Agent(write Boise page)
  Agent(write Pocatello page)
  Agent(write Idaho Falls page)
  Agent(write Nampa page)
```

## Pattern 3 — Parallel Audit
```
Task: "Audit 4 projects"
Send in ONE message:
  Agent(audit jrs-auto-repair)
  Agent(audit manage-worker-bee)
  Agent(audit language-lens-elite)
  Agent(audit silver-creek-logistics)
```

## Critical: Independent vs Dependent
```
PARALLEL (independent — no B needs A):
  A: "Check the auth system"
  B: "Check the database schema"
  C: "Check the API routes"

SEQUENTIAL (dependent — each needs previous):
  A: "Read the codebase and summarize architecture"
  B: [after A] "Given the architecture, design the feature"
  C: [after B] "Implement the design"
```

## Prompt Isolation for Parallel Agents
Each agent has NO context from other agents in the same batch. Each agent prompt must be self-contained:
```
WRONG (agent B doesn't have A's output):
  Agent A: "Analyze the auth system. Write your findings to auth-analysis.md"
  Agent B: "Based on the auth analysis, redesign the login flow"
  ← B fails because it can't see A's analysis

RIGHT:
  Both run independently, orchestrator synthesizes
  OR: run A first, get results, then send B with A's output included in prompt
```

## Model Selection in Parallel
Assign the right model per task — don't default everything to expensive models:
```typescript
Agent({ model: "haiku", description: "rename files", prompt: "..." })
Agent({ model: "haiku", description: "format JSON", prompt: "..." })
Agent({ model: "sonnet", description: "design architecture", prompt: "..." })
```

## When Parallel Fails
- Context window: 20+ parallel agents in one message can exceed limits
- Shared file writes: two agents writing to the same file = corruption
- Dependency violations: agent B needs agent A's output (can't be parallel)
- Rate limits: too many simultaneous model calls may throttle
