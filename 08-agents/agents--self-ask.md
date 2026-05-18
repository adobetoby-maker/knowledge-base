# Self-Ask Prompting Pattern

## What It Is

Self-Ask is a prompting pattern where the agent explicitly decomposes a complex question into smaller sub-questions, answers each sub-question in sequence, and integrates those answers into a final response. It externalizes the decomposition step instead of leaving it implicit in chain-of-thought reasoning.

The pattern was formalized in "Measuring and Narrowing the Compositionality Gap in Language Models" (Press et al., 2022), which showed that models fail on multi-hop questions not because they lack the component knowledge, but because they never explicitly retrieve each component. Forcing explicit sub-questions closes this gap.

## The Core Structure

```
Question: [Complex question]

Are there follow-up questions? Yes.

Follow-up question: [Sub-question 1]
Intermediate answer: [Answer to sub-question 1]

Follow-up question: [Sub-question 2]
Intermediate answer: [Answer to sub-question 2]

Follow-up question: [Sub-question 3]
Intermediate answer: [Answer to sub-question 3]

Are there follow-up questions? No.

Final answer: [Synthesized answer using intermediate answers]
```

## Why Sequential Sub-Questions Work

Multi-hop reasoning fails when answers to early steps are needed to formulate later steps correctly. Sequential sub-questions solve this: the answer to sub-question 1 informs how sub-question 2 is framed. If you ask all sub-questions upfront (as a flat list), later questions may be poorly scoped because they were written before the earlier answers were known.

Each intermediate answer also acts as a grounding checkpoint — if the intermediate answer is wrong, it surfaces early rather than silently propagating through to a wrong final answer.

## When to Use Self-Ask

Good fit:
- Multi-hop factual questions ("What is the capital of the country where X was born?")
- Dependency chains ("Will this deployment succeed if the DB migration runs first?")
- Comparative analysis requiring independent evaluation of each candidate
- Debugging where each hypothesis must be checked independently

Poor fit:
- Single-step questions that don't require decomposition
- Creative tasks where decomposition kills spontaneity
- High-latency-sensitive contexts (sub-questions multiply token usage)

## Integrating with Tool Use

Self-Ask pairs naturally with tool-calling agents. Each follow-up question becomes a potential tool invocation:

```
Follow-up question: What is the current price of ETH?
Intermediate answer: [calls price_lookup("ETH")] → $3,412

Follow-up question: What is 15% of $3,412?
Intermediate answer: [calls calculator("3412 * 0.15")] → $511.80
```

This makes the reasoning auditable — each intermediate answer traces back to a specific tool call.

## Avoiding Common Mistakes

- Do not pre-generate all sub-questions before answering any — answer each before generating the next
- Do not skip sub-questions when the answer "seems obvious" — the discipline of explicit answering is where the accuracy gains come from
- Do not use Self-Ask for tasks where the question is already fully decomposed — it adds overhead without benefit

## Key Rules

- Generate sub-questions one at a time; let each answer inform the next question
- Every intermediate answer must be grounded — look it up, calculate it, or call a tool
- End with a synthesis step that explicitly references the intermediate answers
- Use Self-Ask for multi-hop and dependency-chain problems; skip it for simple queries
- In tool-calling agents, map each sub-question to a discrete tool call for auditability
