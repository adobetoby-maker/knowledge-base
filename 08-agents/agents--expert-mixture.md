# Agent Pattern: Mixture of Experts

## Why Mixture of Experts

A general-purpose agent prompted for legal analysis, technical architecture, and creative writing simultaneously will produce adequate output in all three areas and excellent output in none. Specialized expert agents trained on domain-specific prompts outperform generalists because the system prompt shapes vocabulary, reasoning style, level of detail, and the types of questions the agent asks itself. Routing to the right expert is cheaper and more accurate than asking one agent to do everything.

## Expert Specializations Worth Separating

**Legal expert** — focuses on liability, jurisdiction, compliance requirements, contract enforceability. Uses precise legal language. Flags ambiguous clauses rather than guessing intent.

**Technical expert** — focuses on implementation feasibility, performance tradeoffs, security implications, dependency risk. Stays concrete — no "it depends" without specifying what it depends on.

**Creative expert** — focuses on tone, narrative structure, emotional resonance, originality. Explicitly avoids safe/generic responses; encouraged to propose unexpected angles.

**Financial expert** — focuses on unit economics, cash flow, risk exposure, accounting treatment. Asks "what does this cost at scale?" before endorsing anything.

**Domain experts** are defined by prompt persona + few-shot examples. The examples matter as much as the persona description — they calibrate the register and depth of reasoning.

## The Router

The router classifies incoming input and selects one or more experts. Two approaches:

**Keyword/rule-based router** — fast, deterministic, zero extra LLM call. Works well when domains are clearly separated (user asks "is this contract enforceable?" → legal expert).

**LLM classifier router** — uses a small model (Haiku) to classify intent before routing. Handles ambiguous or multi-domain inputs. Returns `{ experts: ["legal", "technical"], confidence: 0.87 }`.

The router should output a list, not a single expert, when the query spans domains. A contract with a technical SLA clause needs both legal and technical eyes.

## Combining Multiple Expert Opinions

When two or more experts respond, a synthesis step combines them. Do not concatenate — synthesize:

```typescript
const synthesisPrompt = `
You have received analysis from multiple domain experts on the same question.
Your job is to integrate their views into a single coherent recommendation.
Identify points of agreement, points of tension, and gaps where no expert weighed in.
Output a recommendation that respects each domain's constraints simultaneously.

Legal analysis: ${legalResponse}
Technical analysis: ${technicalResponse}
Question: ${originalQuery}
`
```

The synthesizer is a neutral agent — it has no domain persona. Its job is integration, not additional domain analysis.

## Confidence-Weighted Blending

Each expert can emit a confidence score alongside their analysis:

```json
{
  "analysis": "The indemnification clause is overbroad...",
  "confidence": 0.72,
  "gaps": ["I cannot assess enforceability under California law without jurisdiction context"]
}
```

The synthesizer uses confidence scores to weight how much to defer to each expert when they conflict. Low-confidence experts flag what additional context they need rather than guessing.

## Implementation Structure

```
Input
  ↓
Router (classify domain(s))
  ↓
[Expert A]  [Expert B]  [Expert C]  ← parallel
  ↓
Synthesizer (integrate + surface conflicts)
  ↓
Output
```

Keep expert system prompts in version-controlled files, not inline strings. They evolve independently and need review history.

## What Goes Wrong

**Over-routing** — routing every query through all experts regardless of relevance. This wastes tokens and dilutes the synthesis. Route precisely; use the synthesizer only when multiple experts are genuinely needed.

**Expert drift** — general questions cause experts to stray outside their domain. Constrain with "stay within your domain; flag anything outside it for another expert."

**Synthesizer hallucination** — synthesizer invents consensus that did not exist in the expert responses. Fix: require synthesizer to quote the specific passage it is integrating, not paraphrase.

## Key Rules

- Define experts by persona plus few-shot examples — examples calibrate register, not just content
- Router must return a list; single-expert routing is the common case but not the only one
- Run multiple experts in parallel, never sequentially
- Synthesizer's job is integration, not additional analysis — keep it domain-neutral
- Version-control expert system prompts separately from application code
- Low-confidence responses are useful; silence is not — require experts to flag their gaps
