# Agents: Tool Chaining Patterns

## Overview
Tool chaining — using the output of one tool as the input of the next — is how agents accomplish complex tasks from simple primitives. The patterns look simple but produce subtle bugs when dependencies are unclear, when intermediate results are assumed valid without verification, or when the chain loops without a termination condition. Mapping the chain explicitly before implementing prevents most of these issues.

## Four Chain Patterns

**Sequential chain**
Output of tool A is required input for tool B. One depends on the other.
- Example: search(query) → fetch_page(url from search) → extract_data(page content)
- Requirement: each step must complete before the next begins
- Error handling: if any step fails, the chain must stop or use a fallback

**Parallel chain**
Independent tools run simultaneously. Results are combined at the end.
- Example: search_web(query) + search_database(query) + search_cache(query) → merge_results()
- Requirement: independence — no step should modify state that another parallel step reads
- Result: aggregation strategy must be defined upfront

**Conditional chain**
Tool B runs only if tool A's result meets a condition.
- Example: check_cache(key) → if miss → fetch_from_api(key) → write_cache(key, result)
- Requirement: condition must be deterministic and tested
- Error: if the condition check itself fails, what happens?

**Loop chain**
Tool runs repeatedly until a termination condition is met.
- Example: search(query) → evaluate_quality() → if insufficient → refine_query() → search(new_query) → ...
- Requirement: must have a hard maximum iteration count — unbounded loops are a reliability and cost hazard
- Termination: define exit conditions explicitly (quality threshold, max iterations, found required item)

## Chain Mapping (Before Implementing)

Draw the chain as a directed graph before writing code:
1. List every tool in the chain
2. Draw an arrow from each tool to the tools that depend on its output
3. Check for cycles (cycles = infinite loops if not broken by termination condition)
4. Label each arrow with the data type passed
5. Identify branch points (conditional chains) and their conditions

If the graph is too complex to draw in 5 minutes, the chain is too complex — simplify.

## Intermediate Result Validation

Do not assume a tool's output is valid before passing it to the next tool:
- Validate schema/type before use
- Check for empty/null results (search returning 0 results is valid but should be handled)
- If a required field is missing from a tool result, fail early with a clear error — not silently downstream with a confusing error

## Termination Guards

Any loop chain requires:
- `max_iterations` counter (hard ceiling — not just "keep trying")
- Explicit exit condition checked at the start of each iteration
- Logging of iteration count and exit reason

A loop that runs 100 iterations costs 100x more than expected. Set `max_iterations = 5` or `= 10` and log loudly when hitting the ceiling.

## Detecting Circular Dependencies

Before building a chain, verify it is a DAG (directed acyclic graph):
- A → B → A is a cycle — A's input depends on its own output
- Cycles are always bugs in sequential chains
- In loop chains, the cycle is intentional but must be bounded

## Key Rules

- Map the chain as a directed graph before implementing — discover cycles and missing dependencies upfront
- Every loop chain must have a hard `max_iterations` guard
- Validate intermediate results before passing to the next tool — don't propagate bad data silently
- Parallel chains require independence verification — tools that share state cannot run in parallel safely
- Define aggregation strategy for parallel chains before building them
- Termination condition must be checked at the start of each loop iteration, not at the end
