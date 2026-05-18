# Model Routing Principle — Cost-Efficient Agent Selection

## Core Rule

The most capable model is not the best model for every task. The best model is the cheapest model that can reliably complete the task.

Routing rule: "Do X" tasks → Haiku. "Design X" tasks → Sonnet. "High-stakes strategic X" tasks → Opus.

## Model Characteristics

**Haiku 4.5** (claude-haiku-4-5)
- ~1/10th the cost of Sonnet
- 200k context window
- Speed: fast
- Ideal for: mechanical operations, simple transformations, classification, lookup

**Sonnet 4.6** (claude-sonnet-4-6)
- Default model
- 200k context window
- Speed: moderate
- Ideal for: architecture decisions, multi-file reasoning, component design, content writing with nuance

**Opus 4.7** (claude-opus-4-7)
- ~10× the cost of Sonnet
- 200k context window
- Speed: slower
- Ideal for: high-stakes product decisions, complex strategic reasoning, security architecture

## Haiku-Appropriate Tasks

Route to Haiku (model="haiku") for:
```
✓ curl / wget / HTTP requests
✓ File copy/rename/move operations
✓ String replacements across files
✓ Image download, resize, format convert
✓ git add / commit / push
✓ npm install / build / lint checks
✓ Generating TypeScript types from a schema
✓ Writing repetitive content (similar articles across variants)
✓ Classification tasks (is this spam? which category?)
✓ JSON transformation / data normalization
✓ "Just do X to Y files" mechanical tasks
```

## Sonnet-Appropriate Tasks

Use Sonnet (default) for:
```
✓ TypeScript architecture and new component design
✓ Multi-file debugging and cross-file reasoning
✓ Novel blog/route content writing (nuanced voice)
✓ Agent orchestration decisions
✓ Code review and refactoring with pattern analysis
✓ Auth or security logic implementation
✓ Database schema design
✓ Solving bugs that require understanding system state
```

## Opus-Appropriate Tasks

Reserve Opus for:
```
✓ Should we rebuild this feature vs extend it? (major direction decisions)
✓ What's the right architecture for this entire product category?
✓ Security threat modeling for a new auth system
✓ Evaluating two fundamentally different technical approaches
✓ CEO-level product strategy questions
```

Opus is expensive. If the question could be answered adequately by Sonnet, use Sonnet. If you're using Opus more than 2-3 times per week, you're over-routing.

## Routing in Multi-Agent Systems

When spawning sub-agents with the Agent tool:

```
// Mechanical task — Haiku
Agent(model="haiku", description="rename all .tsx to .ts", prompt="...")

// Reasoning task — Sonnet (default, no model param needed)
Agent(description="analyze auth pattern and find the bug", prompt="...")

// High-stakes decision — Opus
Agent(model="opus", description="architectural review of auth system", prompt="...")
```

## The Override Rule

If a task seems mechanical but has high blast radius, upgrade to Sonnet. A Haiku agent modifying auth code might be cheap but introduce a security vulnerability. The savings are not worth the risk.

Routing guidance is about cost optimization within safe parameters — it never overrides the blast radius principle.
