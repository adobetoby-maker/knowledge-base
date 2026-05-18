# Skill: multi-agent-patterns

**Trigger:** Designing a system where multiple AI agents work together. Need to decide how to split work, how agents communicate, when to use orchestrator vs peer patterns.
**Invoke:** `/multi-agent-patterns`
**Returns:** Agent topology patterns, communication designs, context budget strategies, handoff contracts.

## When to Invoke
- A task is large enough that it benefits from specialization
- Need parallel research + implementation
- Building a pipeline where output of one feeds next
- Need isolation — one agent's large context shouldn't pollute another
- Designing overnight batch systems

## Core Topologies

### Orchestrator → Worker (most common)
One agent manages task breakdown and delegates.
```
Orchestrator (Sonnet)
  ├── Worker A: Research competitor features (Haiku)
  ├── Worker B: Research SEO keywords (Haiku)
  └── Worker C: Research technical stack (Haiku)
      ↓
Orchestrator: Synthesizes results, writes implementation plan
      ↓
  ├── Coder A: Implements feature X (Haiku)
  └── Coder B: Implements feature Y (Haiku)
```

### Peer Pipeline (sequential specialists)
Each agent adds to a structured artifact and hands it off.
```
Explorer: "Read codebase, summarize architecture"
    ↓ artifact: architecture summary
Architect: "Given architecture, design the feature"
    ↓ artifact: implementation plan
Coder: "Implement the plan"
    ↓ artifact: code changes
Reviewer: "Review the code changes"
    ↓ artifact: review report
```

### Scatter-Gather (pure parallel)
All agents get same task, different angles. Orchestrator merges.
```
Prompt: "Write 3 different hero sections for this landing page"
Agent A → option 1
Agent B → option 2
Agent C → option 3
Orchestrator: Picks best or merges strongest elements
```

## Parallel Execution
All agents in a single message run simultaneously:
```typescript
// In a single message — all three start at once
Agent({ description: "Research A", prompt: "..." })
Agent({ description: "Research B", prompt: "..." })
Agent({ description: "Research C", prompt: "..." })
```

## Handoff Contract — What Each Agent Gets
Every agent prompt must include:
1. What they're building and why
2. What they should NOT do (boundaries)
3. Where to find what they need (exact file paths)
4. What to produce and in what format
5. How to surface blockers

```
BAD: "Review this code"
GOOD: "Review src/components/CheckoutForm.tsx for: (1) security issues with payment data, 
(2) form validation completeness, (3) error states. DO NOT refactor — only flag issues. 
Return: numbered list of findings with line numbers and severity."
```

## Context Budget Rules
- Orchestrator: keep lean — reads summaries, not full files
- Workers: load only what they need for their specific task
- Haiku agents: under 4k tokens of context for best performance
- Don't pass large files between agents — pass summaries + references

## When NOT to Use Multiple Agents
- Simple file edits with known location → just edit inline
- Sequential tasks with high interdependency → single agent is more coherent
- Low-stakes mechanical work → Haiku inline is faster than orchestrating

## What Skill Returns
Detailed topology designs, agent communication contracts, context management patterns, cost optimization strategies, and failure handling for multi-agent systems.
