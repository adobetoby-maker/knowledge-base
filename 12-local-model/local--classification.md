# Text Classification with Local Models

Classification is one of the highest-ROI uses of local inference: the task is well-defined, outputs are constrained, and privacy-sensitive text never leaves your infrastructure. The challenge is calibration — making the model's expressed confidence actually reflect its accuracy.

## Multi-Class vs Multi-Label

**Multi-class** (exactly one label): instruct the model to output a single label. Enforce this in the prompt: "Output exactly one of: [label list]. No explanation." Without this constraint, local models frequently output multiple labels, hedged answers, or explanatory prose.

**Multi-label** (zero or more labels apply): require the model to evaluate each label independently rather than choose from a list. "For each label below, output YES or NO." This is more reliable than asking for a comma-separated list, which produces inconsistent ordering and formatting.

For multi-class, constrain the output using a structured format or logit bias if your inference server supports it. Parse the first token of the response to identify the label — everything after is noise.

## Calibration via Few-Shot Examples

An uncalibrated local model on a custom taxonomy is nearly useless — it doesn't know your label semantics. Few-shot examples are the calibration mechanism:

- Include at least one example per label
- Include examples for the hardest cases (inputs that are genuinely near the boundary between two labels)
- Include one ambiguous example and show the "correct" decision to teach the tiebreaker rule

Without boundary examples, the model learns only the canonical case per label and fails systematically on edge cases that represent 30–40% of real traffic.

## Handling Ambiguous Inputs

Some inputs genuinely belong to multiple categories or none. Build an explicit `AMBIGUOUS` or `UNSURE` class into your label set rather than forcing a best-guess. The model will use it — and those outputs are where human review is most valuable. If you don't provide an escape hatch, the model distributes ambiguous inputs unpredictably across similar classes, creating a hidden error floor.

## Confidence Threshold and Abstain

Many classification use cases benefit from a confidence gate: if the model isn't sure, escalate rather than classify. Implement this by asking for a confidence score (0–10) alongside the label:

```
Output format: LABEL | CONFIDENCE (0-10)
Example: BILLING_INQUIRY | 8
```

Set a threshold (e.g., score < 6 → route to human review). Local models are poorly calibrated on absolute confidence, but they are relatively well calibrated — a score of 3 is almost always worse than a score of 8 for the same model. Tune the threshold by measuring accuracy on a labeled validation set.

## Batch Processing for Throughput

For offline classification jobs (document processing, log triage, content moderation), batch inputs rather than processing one at a time. Local model servers (Ollama, llama.cpp) process requests sequentially unless you run multiple instances. Strategies:

- Run 4–8 worker processes, each with its own model server instance on different ports
- Send batches of 50–100 inputs through a queue
- Use async HTTP clients to saturate all workers simultaneously

For a single GPU/CPU machine, 4 workers is typically optimal — beyond that, memory bandwidth becomes the bottleneck, not request rate. Measure throughput empirically before scaling.

## Key Rules

- Constrain output to the exact label list — add "no explanation" explicitly
- Use multi-label prompting (YES/NO per label) rather than comma-separated lists
- Always include boundary examples in few-shot, not just canonical ones
- Add an AMBIGUOUS/UNSURE class rather than forcing classification
- Request confidence scores and threshold below some value to human review
- Batch offline jobs across multiple worker instances for throughput
- Validate calibration on a held-out labeled set before deploying
