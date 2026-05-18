# Routing Tasks to Different Local Models by Complexity

## Why Multi-Model Routing

A single large model (13B+) running everything is slow and resource-intensive. A 3B model is fast but can't reason through complex multi-step tasks. Routing by task complexity gives you the accuracy of large models where needed and the speed of small models everywhere else.

The routing decision adds ~5ms of overhead. The saved inference time on simple tasks is typically 300–3000ms. The math strongly favors routing.

## Model Tiers

**Small (1B–3B):** Classification, extraction, intent detection, sentiment analysis, yes/no decisions. These tasks have constrained output spaces and don't require multi-step reasoning. Target latency: 50–200ms. Models: `phi3:mini`, `qwen2.5:1.5b`, `llama3.2:1b`.

**Medium (7B):** Paragraph-length generation, summarization, translation, simple Q&A with retrieved context, code completion for common patterns. Target latency: 500ms–2s. Models: `llama3.1:8b`, `qwen2.5:7b`, `mistral:7b`.

**Large (13B+):** Complex reasoning, multi-step planning, code generation for novel logic, long-document synthesis, tasks requiring extended chain-of-thought. Target latency: 3–15s. Models: `llama3.1:70b` (quantized), `qwen2.5:14b`, `mixtral:8x7b`.

## Routing Decision Logic

Route by task type first, complexity signals second.

Task-type rules (deterministic, no model needed):
```
classification → small
extraction → small  
sentiment → small
short_generation (< 100 tokens output) → medium
summarization → medium
qa_with_context → medium
code_generation → large
complex_reasoning → large
```

Complexity escalation signals that override task-type defaults:
- Output expected to exceed 500 tokens → escalate one tier
- Input contains multiple entities to reconcile → escalate one tier
- Task requires referencing more than 3 facts simultaneously → escalate to large

## Confidence-Based Escalation

Run the small model first on tasks that might need escalation. If the model's output confidence (via log probabilities on the final token or a structured confidence field) falls below a threshold, re-run on the next tier.

```js
const result = await runSmallModel(task);
if (result.confidence < 0.7) {
  return await runMediumModel(task);
}
return result;
```

This pattern costs 2x latency in the escalation case but is faster than always using the large model. Set escalation thresholds conservatively — false escalations are expensive, missed escalations produce bad output.

Log all escalations. A high escalation rate for a specific task type signals it should be permanently reassigned to the next tier.

## Cost Tracking Per Route

"Cost" for local models is compute time × resource usage, not dollars. Track:
- `tokens_in` + `tokens_out` per request
- `model_tier` used
- `latency_ms`
- Whether escalation occurred

Aggregate weekly to see actual model distribution. You'll typically find 60–70% of tasks route to small, 25–30% to medium, and 5–10% to large. If large model usage is >20%, your routing rules are miscalibrated.

## Warm Model Management

Local models require loading into VRAM/RAM before first inference (30–60s for large models). Keep frequently used models warm:

- Small model: always loaded (tiny resource cost)
- Medium model: load on first request, evict after 10 minutes idle
- Large model: load on demand, evict after 2 minutes idle (high VRAM cost)

With Ollama, models stay loaded based on the `OLLAMA_KEEP_ALIVE` setting. Set small model keep-alive to `"24h"`, medium to `"10m"`, large to `"2m"`.

## Key Rules

- Route by task type first using deterministic rules — don't use a model to decide which model to use.
- Log every route decision and escalation; review weekly to recalibrate routing rules.
- Track latency and escalation rate per task type separately — they reveal different failure modes.
- Keep the small model always warm; evict the large model aggressively to free VRAM for inference.
- Set confidence escalation thresholds conservatively; a missed escalation degrades quality, but frequent false escalations destroy latency.
- Never route to large model by default and "optimize later" — the right time to set routing rules is before you discover the bottleneck in production.
