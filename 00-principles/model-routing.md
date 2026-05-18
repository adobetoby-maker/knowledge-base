# Model Routing — Cost vs Capability

**When:** Before spawning any agent, subagent, or choosing a model for a task.
**Rule:** Match model capability to task complexity. Most tasks do not need the strongest model. Overpowered models on simple tasks waste 10x the cost for no quality gain.

## The Ladder

**Smallest/cheapest (Haiku 4.5 or local equivalent):**
- File operations: rename, copy, move, replace strings
- git: add, commit, push
- npm: install, build, lint
- Image: download, resize, convert
- JSON: transform, format, extract
- Any task where the instruction is fully explicit and unambiguous
- Invoke with: `model: "haiku"` in Agent tool

**Mid-tier (Sonnet 4.6 — default):**
- Architecture decisions for a specific file or component
- Multi-file debugging with context
- Writing TypeScript components following existing patterns
- Blog/SEO content writing
- Agent orchestration decisions
- Most coding tasks

**Strongest (Opus 4.7 — use sparingly):**
- High-stakes strategic decisions with significant tradeoffs
- Complex reasoning over large context with subtle interactions
- Security reviews where missing something is expensive
- Cases where being wrong has production consequences

## Agent Tool Usage
```
Agent({ model: "haiku", ... })   // mechanical work
Agent({ model: "sonnet", ... })  // default, architecture
Agent({ model: "opus", ... })    // high-stakes only
```

## Local Model Equivalents
- Haiku equivalent: Llama 3.2 3B, Phi-3 mini — fast, mechanical tasks
- Sonnet equivalent: Llama 3.3 70B, DeepSeek Coder 33B — architecture, coding
- Opus equivalent: DeepSeek R1 70B, Qwen 2.5 72B — reasoning-heavy tasks

## Decision Branch
- IF task is "do X to Y" with no ambiguity → haiku
- IF task requires understanding context across multiple files → sonnet
- IF task requires weighing tradeoffs with significant consequences → opus
- IF spawning multiple parallel agents → use haiku for each if the work is mechanical

## Anti-Pattern
Defaulting to the strongest model because "it's more reliable."
Reliability difference on a well-defined task is <5%.
Cost difference is 10-100x.
