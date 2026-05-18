# Agent Pattern: Grounding Responses in Facts

## The Core Problem

Language models generate text that is fluent and confident regardless of whether the underlying claim is supported by retrieved evidence. Grounding techniques do not fix this at the model level — they create structural constraints that make unsupported claims detectable and auditable. The goal is not to eliminate hallucination (impossible) but to make it catch-able before it reaches users.

## Retrieval-Augmented Generation (RAG)

The foundation of factual grounding. Before generating a response, retrieve relevant documents from a trusted corpus and inject them into context. The generation is then anchored to real retrieved content rather than model weights alone.

What matters in RAG beyond the retrieval step:

**Source quality over source quantity** — 3 high-relevance chunks beat 20 loosely related ones. Too many chunks dilute the signal and increase the chance the model synthesizes across chunks in ways that produce compound errors.

**Chunk attribution in context** — label each chunk with its source before including it:

```
[Source: jrs-policies.pdf, Section 4.2]
Customers must provide 48-hour notice for cancellations.

[Source: jrs-policies.pdf, Section 4.3]
Same-day cancellations incur a 50% fee.
```

Labeled chunks allow the model to attribute its claims to specific sources. Unlabeled chunks will be synthesized without traceable origin.

**Retrieval failure handling** — when no relevant documents are found, the model must be told to say so rather than falling back to general knowledge. Explicit instruction: "If the provided sources do not contain information relevant to the question, say 'I don't have information on that' rather than answering from general knowledge."

## Citation Requirement Prompts

Require the model to cite specific sources for every factual claim:

```
For each factual claim in your response, provide a citation in the format [Source Name, section].
If you cannot cite a source for a claim, do not make that claim.
```

This shifts the burden from "generate text and hope it is accurate" to "generate text you can support." Claims the model cannot cite either disappear or are flagged as uncertain. Both outcomes are better than uncited confident assertions.

Validating citations programmatically: extract `[Source, section]` patterns from the response and verify each cited source was in the retrieved context. If a citation does not match any retrieved source, it is hallucinated.

## Self-Check for Unsupported Claims

After generating a response, run a second pass asking the model to audit its own output:

```
Review your previous response and identify any claims that:
1. Are not directly supported by the provided sources
2. Require assumptions not stated in the sources
3. Are inferences that go beyond what the sources say

For each such claim, either remove it, qualify it as an inference, or note what source would be needed to support it.
```

This does not catch everything — a model will sometimes incorrectly clear its own hallucinations. But it catches cases where the model knows it overreached and provides structural opportunity to retract.

Run this as a separate inference call, not within the same conversation turn. A second call with fresh framing is more likely to be critical.

## Hallucination Mitigation vs. Elimination

These are different problems. Mitigation means reducing the rate of undetected hallucinations in production. Elimination means guaranteeing no hallucinations, which is not achievable with current generation models.

Mitigation strategies (realistic):
- RAG with relevant, labeled sources
- Citation requirements with programmatic verification
- Self-check audits
- Human review for high-stakes outputs

Elimination approaches (not achievable at inference time):
- Fine-tuning on domain data reduces but does not eliminate hallucination
- Constitutional AI techniques reduce harmful hallucinations but not factual ones
- Retrieval alone does not prevent the model from synthesizing across chunks incorrectly

Design systems around the assumption that some fraction of outputs will contain unsupported claims. Grounding techniques reduce this fraction; auditing and human review catch the remainder.

## Key Rules

- RAG requires labeled chunks in context — unlabeled chunks produce untraceable synthesis
- When retrieval finds nothing relevant, the model must say so — never fall back to general knowledge silently
- Require explicit citations; validate citations programmatically against retrieved sources
- Self-check is a second inference call — same-turn review is too forgiving
- Mitigation reduces hallucination rate; it does not reach zero — design review steps for high-stakes outputs
- Source quality matters more than source quantity; fewer high-relevance chunks outperform many loosely related ones
