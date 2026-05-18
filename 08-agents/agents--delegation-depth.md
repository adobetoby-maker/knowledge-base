# Agents: Delegation Depth

## Overview
Multi-agent systems achieve parallelism and specialization by delegating tasks from an orchestrator to sub-agents. But delegation depth — the number of layers in the agent hierarchy — has compounding costs: each layer adds latency, cost, error surface, and context loss. Systems that go too deep become fragile, opaque, and expensive. The ceiling is around 3 levels for most practical systems.

## Why Depth Is Dangerous

**Context loss at each layer**
When an orchestrator delegates to a sub-agent, it passes a subset of its context. The sub-agent then delegates to a tool or another agent with a further-reduced subset. By layer 4, the executing agent may have lost critical constraints or background that existed at layer 1.

**Error propagation**
Errors at layer N require propagating error context back through N layers to the orchestrator that can decide what to do. Each hop adds latency and risks losing the original error detail. A timeout at layer 3 may surface as a vague "subagent failed" at layer 1.

**Cost explosion**
Each layer adds at least one LLM call. A 3-level hierarchy with 5 workers at each level = potentially 25+ LLM calls per task. Add parallel spawning and the cost multiplies further.

**Debugging opacity**
Tracing an incorrect output requires following the call chain through every delegation layer. With 4+ levels, this becomes extremely difficult without specialized observability tooling.

## Maximum Useful Depth

**Level 1: Orchestrator**
- Receives the user request
- Plans the decomposition
- Manages overall state and result assembly
- Does not execute low-level tasks directly

**Level 2: Worker agents**
- Execute a specific sub-task
- Call tools (search, database, code execution, file I/O)
- Return structured results to the orchestrator
- May call tools in parallel

**Level 3: Tools (leaf nodes)**
- Pure functions: take input, return output
- No further delegation
- Examples: web search, SQL query, API call, file read

This is the canonical 3-level structure. Level 2 agents are leaf nodes in terms of LLM calls — they call tools, but tools are not agents.

## When 4 Levels Seems Necessary

If a task seems to require a 4th level, the design usually has one of these problems:

1. **The orchestrator is doing too little** — promote some orchestration logic to level 2
2. **A worker is too broad** — split into two parallel level-2 workers
3. **The task itself is too large** — break it into multiple top-level orchestrations, not deeper nesting
4. **Tools are being wrapped unnecessarily** — a "file agent" that calls a file tool is not better than calling the file tool directly

## Sub-Agent as Leaf Node

Sub-agents should terminate the delegation chain — they call tools, receive results, and return structured output to their parent. A sub-agent that spawns further sub-agents is a depth violation unless the design has been explicitly justified.

## Context Handoff

When an orchestrator spawns a worker, it must provide sufficient context for the worker to complete the task without asking questions:
- Task specification (what to do)
- Constraints (what not to do)
- Relevant background (subset of orchestrator's context)
- Expected output format

Over-providing context wastes tokens; under-providing causes failures or hallucinated results.

## Key Rules

- Maximum 3 levels: orchestrator → worker → tool
- Workers are leaf nodes — they call tools, not other agents
- If 4 levels seems necessary, restructure before building
- Error handling must traverse the full depth — design the error path before the happy path
- Log delegation decisions with context at each level for debugging
- Cost is multiplicative with depth — estimate before building deep hierarchies
