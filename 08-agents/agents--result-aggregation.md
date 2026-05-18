# Agents: Result Aggregation from Parallel Agents

## Overview
When multiple agents execute tasks in parallel and return results to an orchestrator, the orchestrator must combine those results into a coherent output. How to merge depends entirely on the output type — lists, scores, structured data, and prose each require different strategies. Aggregation bugs are silent: the system appears to work but produces subtly wrong or inconsistent output.

## Aggregation by Output Type

### Lists
- **Deduplicate**: multiple agents may surface the same item (URL, finding, entity)
- **Preserve provenance**: track which agent found which item (useful for debugging and confidence weighting)
- **Sort**: by relevance score, frequency of mention across agents, or recency
- **Threshold**: if an item appears in only 1 of 5 agents, it may be noise — set a minimum mention threshold for high-confidence results

### Scores / Rankings
- **Average**: use when all agents have equal authority and similar methodology
- **Weighted average**: use when agents have known reliability differences (e.g., one specialized agent weighted higher)
- **Max**: use when you want the upper bound (e.g., "what's the highest severity finding?")
- **Consensus threshold**: require N-of-M agents to agree before accepting a score (reduces false positives)

### Structured Data (JSON, tables)
- **Union fields**: combine all fields found across agents (one agent may find fields another missed)
- **Conflict resolution**:
  - Same field, different values → prefer the more specific or more recent value, or flag for human review
  - Same field, same value → confirmed; high confidence
  - Same field, conflicting values → low confidence; either surface both or use a tie-breaking rule
- **Null handling**: distinguish between "not found" and "not applicable" — both may surface as null but mean different things

### Prose / Narrative
- Parallel prose generation typically produces redundancy — don't concatenate blindly
- Feed all parallel outputs to a synthesizer agent with explicit deduplication and coherence instructions
- Preserve unique insights from each agent; deduplicate overlapping content

## Timeout vs Failure

Parallel agent results may arrive at different times or not at all:
- **Timeout**: agent exceeded time limit — treat as partial result; log and proceed with what arrived
- **Error/exception**: agent failed — log error details; decide whether to retry or proceed without
- **Missing result**: should be handled explicitly, not silently dropped. If result is required → escalate. If optional → mark output as partial.

Never let a missing result silently produce a complete-looking output.

## Partial Result Handling

Define for each task type:
- Can output be produced without all agents' results? (usually yes, with quality flag)
- What's the minimum viable quorum? (e.g., at least 3 of 5 agents must return)
- Should the caller know the result is partial? (yes — include metadata)

Output metadata:
```json
{
  "result": [...],
  "meta": {
    "agents_total": 5,
    "agents_succeeded": 4,
    "agents_timed_out": 1,
    "result_completeness": "partial"
  }
}
```

## Conflict Surfacing

When agents return conflicting information on the same field, the right behavior is usually to surface the conflict rather than silently resolve it:
- Return both values with their source and confidence
- Let downstream logic (human or another agent) resolve
- Log conflicts for quality monitoring — high conflict rates indicate prompt or data problems

## Key Rules

- Define aggregation strategy per output type before building — aggregation is not a generic operation
- Timeout and error are different failure modes — handle them differently
- Never silently drop missing results — mark output as partial
- Include provenance metadata: which agent produced which result
- Deduplicate lists before returning — parallel agents routinely surface the same items
- Conflict resolution policy must be explicit — implicit tie-breaking produces silent errors
