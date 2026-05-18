# Few-Shot Prompting with Local Models

Few-shot examples do more work with local models than with large cloud models. A 7B or 13B model hasn't internalized as many implicit conventions, so examples are the primary mechanism for communicating output format, tone, and edge-case behavior. Treat them as a lightweight specification, not a hint.

## Example Selection

Pick examples that collectively cover the space of inputs you'll encounter. One fluent example is useless if all real inputs are idiomatic or malformed. Curate for:

- **Diversity**: different input lengths, different vocabulary, different edge cases
- **Edge coverage**: at least one example should represent a failure mode you care about (ambiguous input, missing data, unusual format) so the model learns how to handle it gracefully
- **Representative distribution**: if 30% of real inputs are short fragments, include short-fragment examples at roughly that ratio

Avoid cherry-picking your three "cleanest" examples — those teach the model the happy path only.

## Format Consistency

The format between examples and the expected real output must be byte-for-byte consistent on structural elements. If your examples use `Answer:` as a prefix, every example must use exactly `Answer:` — not `A:`, not `Answer :`, not a blank line before it. Local models are pattern-matchers; subtle format drift in examples produces format drift in outputs.

Use a delimiter that cannot appear naturally in the content (e.g., `###`, `---`, XML tags) to separate the input from the output in each example. This prevents the model from confusing where one ends and the other begins.

## Dynamic Example Selection

For a general-purpose task bank, statically embedding 5 examples wastes context on irrelevant cases. Instead:

1. Store a bank of (input, ideal_output) pairs with embeddings
2. At query time, embed the incoming input and retrieve the top-k most similar examples by cosine similarity
3. Inject those k examples into the prompt

This keeps examples relevant to the actual query, which matters more for local models because their in-context learning is shallower — proximity to the specific domain helps significantly.

## Anti-Patterns

**Too many examples exhaust context.** Local models typically run with 4K–8K context windows. If your 10 examples consume 3,000 tokens, you've left little room for the actual input and output. 3–5 examples is usually optimal. Beyond that, quality and relevance matter more than quantity.

**Inconsistent examples teach inconsistency.** If two examples handle the same edge case differently, the model learns to be uncertain, and outputs become unpredictable. Audit your example bank for contradictions before deployment.

**Using examples as a substitute for a clear task description.** Examples illustrate; they don't replace an explicit instruction in the system prompt. Write the instruction, then add examples as reinforcement.

## Key Rules

- Select examples that cover edge cases, not just clean inputs
- Keep format identical across all examples (delimiters, prefixes, whitespace)
- Use dynamic retrieval for large task banks to keep examples relevant
- Cap at 3–5 examples; beyond that, relevance beats quantity
- Never let examples contradict each other
- Write an explicit system instruction first; examples reinforce, not replace it
