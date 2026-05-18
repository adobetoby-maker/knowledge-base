# Agent Pattern: Few-Shot Examples in Prompts

## Overview
Few-shot examples demonstrate the expected output format, tone, and edge case handling better than any prose description. Two or three well-chosen examples before the actual task consistently outperform detailed instruction paragraphs. The key: examples must match the real task format exactly, cover at least one non-obvious edge case, and be removed once the task is stable (they consume tokens on every call).

## Implementation

### Structure: Input → Output
Every example must show both the input and the desired output in the exact format the real task will use:

```
Here are examples of the invoice line item description format we use:

Input: { service: "Oil change", quantity: 1, unitPrice: 4999 }
Output: "Full synthetic oil change — 1 unit @ $49.99 = $49.99"

Input: { service: "Brake pad replacement", quantity: 2, unitPrice: 8500 }
Output: "Brake pad replacement — 2 units @ $85.00 = $170.00"

Input: { service: "Diagnostic fee", quantity: 1, unitPrice: 0 }
Output: "Diagnostic fee — No charge"

Now format this line item:
Input: { service: "Tire rotation", quantity: 4, unitPrice: 1500 }
```

### What Makes a Good Example Set
- **2-3 examples** — more than 3 is usually redundant; fewer than 2 may not establish the pattern
- **Covers an edge case** — the third example above shows the zero-price case, which is non-obvious from the happy path alone
- **Same structure** — the Input/Output format is identical for every example and for the real task
- **Realistic data** — contrived examples (foo/bar) don't transfer as well as domain-realistic data

### When to Use Few-Shot

Use few-shot for:
- **Formatting tasks**: generating structured text in a specific style (descriptions, emails, messages)
- **Classification tasks**: labeling items into categories your system defines
- **Transformation tasks**: converting from one format to another (CSV → JSON, one schema → another)
- **Code generation with style conventions**: showing how your codebase writes certain patterns

Skip few-shot for:
- **Well-known formats**: JSON, SQL, standard library calls — the model already knows these
- **Tasks described by a schema**: if you have a Zod schema, the schema is more precise than examples
- **Long computation tasks**: examples help with format, not reasoning

### Anti-Patterns

**Examples that only show the happy path:**
```
# Bad — doesn't teach the edge case
Input: { name: "Alice", age: 30 }
Output: "Alice (age 30)"

Input: { name: "Bob", age: 25 }
Output: "Bob (age 25)"
# What about age: null? The agent will guess.
```

**Examples that don't match the real task format:**
```
# Bad — uses a different schema in examples than in the real task
# Example uses snake_case; real task uses camelCase
```

## Key Rules
- Examples must be in the exact same format as the real task — structural inconsistencies cause the agent to blend formats
- Include at least one edge case example — the happy path alone teaches the pattern but not the boundaries
- Remove examples once you've validated the output is stable — they add tokens on every call with no benefit after the task is tuned
- Bad few-shot examples are worse than no examples — an example that shows incorrect output trains the wrong behavior
- For classification tasks, include examples of every category you want the agent to output, not just the most common
- Keep examples realistic but anonymized — use realistic-sounding fake names and amounts, not obviously fake data like "foo" or "123"
