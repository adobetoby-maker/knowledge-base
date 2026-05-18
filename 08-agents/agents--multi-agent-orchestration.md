# Multi-Agent Orchestration Patterns

## When to Use Multiple Agents

A single agent context window has a cost and quality ceiling. Multi-agent orchestration becomes valuable when:
- The task can be parallelized (5 independent tasks run 5× faster as parallel agents)
- Sub-tasks require deep exploration that would pollute the primary context
- Different sub-tasks need different expertise or constraints
- Total work exceeds one context window

Don't multi-agent reflexively. A single agent with clear instructions outperforms a poorly-orchestrated multi-agent system.

## Pattern 1: Parallel Fan-Out

The orchestrator spawns N independent agents simultaneously. Each handles one portion of the work. Results are collected and synthesized.

```
Orchestrator
├── Agent A: Process site 1
├── Agent B: Process site 2
├── Agent C: Process site 3
└── Agent D: Process site 4 (all start simultaneously)

Orchestrator waits for all → merges results
```

Best for: generating content for multiple sites, running the same analysis on multiple files, deploying multiple independent services.

## Pattern 2: Sequential Pipeline

Each agent's output becomes the next agent's input.

```
Agent 1: Research → findings document
Agent 2: Plan (using findings) → implementation plan
Agent 3: Implement (using plan) → code
Agent 4: Review (using code + plan) → review report
```

Best for: tasks where each stage depends on the previous stage's output. The GateGuard pattern enforces quality gates between stages.

## Pattern 3: Specialist Routing

An orchestrator classifies the incoming task and routes to the most appropriate specialist agent.

```
Orchestrator (receives task)
├── Is this a frontend task? → Frontend Specialist Agent
├── Is this a database task? → Database Specialist Agent
├── Is this an SEO task? → SEO Specialist Agent
└── Is this a deploy task? → DevOps Agent
```

Best for: large autonomous sessions where many different types of work arrive and each type needs different constraints and expertise.

## Pattern 4: Supervisor + Workers

A supervisor agent manages a pool of worker agents, assigning tasks and checking output quality.

```
Supervisor
├── Assigns Task 1 to Worker A
├── Receives Worker A output → validates → if bad: re-assigns
├── Assigns Task 2 to Worker B
└── Maintains task queue and progress state
```

Best for: batch processing with quality requirements (e.g., 50 articles that must all meet quality standards).

## Prompt Isolation

Sub-agents should NOT receive the full orchestrator context. Give each sub-agent only what it needs:

**Include:**
- The specific task
- Project path and relevant constraints
- The corrections-log rules for this domain
- Output format requirements

**Exclude:**
- Other agents' tasks or outputs (unless this agent needs them)
- General session context
- Completed work from other agents

Tight context = cheaper + faster + less noise influencing the output.

## Model Selection in Agent Trees

Orchestrator: Sonnet (handles routing logic, synthesis)
Parallel workers for mechanical tasks: Haiku (10× cheaper)
Review/critic agents: Sonnet (quality matters)
High-stakes decisions: Opus (rare; worth the cost)

An orchestrated system of 5 Haiku agents can be cheaper than 1 Sonnet agent while producing equivalent output for the right tasks.

## Result Collection and Validation

After spawning parallel agents, validate results before using them:

```typescript
const results = await Promise.allSettled([
  agent1.run(),
  agent2.run(),
  agent3.run(),
])

const successful = results
  .filter(r => r.status === 'fulfilled')
  .map(r => r.value)

const failed = results
  .filter(r => r.status === 'rejected')
  .map(r => r.reason)

if (failed.length > 0) {
  await logFailures(failed)  // don't silently discard
}
```

`Promise.allSettled` is safer than `Promise.all` — one agent failure doesn't cancel the others.

## Context Pass-Down Anti-Pattern

The most common multi-agent mistake: passing too much context down the tree.

Wrong:
```
"Here is the full context of our session: [20,000 tokens of conversation]
Now write the footer component."
```

Right:
```
"Write a footer component for jrs-auto-repair.
Stack: Next.js 16 + Tailwind.
Business info: 417 Main Ave E, Twin Falls ID, (208) 595-2101, Mon-Sat 9AM-5PM.
Output: a single TypeScript React component file."
```

The sub-agent needs the task + constraints, not the history of how you arrived at the task.
