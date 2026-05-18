# Classifying User Intent with a Local Model

## Why Local Intent Detection

Cloud-based intent classifiers add latency and cost per request. A local 3B–7B model can classify most intents in under 100ms on CPU, making it viable for real-time routing. The tradeoff is accuracy — local models need careful taxonomy design and few-shot examples to match cloud classifier quality.

## Intent Taxonomy Design

The taxonomy is the most important decision. Get it wrong and no amount of prompt engineering fixes it.

**Size the taxonomy to 5–15 intents.** Below 5 you're over-generalizing (every question becomes "query"). Above 15 the model confuses similar intents and accuracy drops sharply. Group related fine-grained intents under a parent and route to a sub-classifier if needed.

**Avoid overlap.** Each intent should have a clear discriminating feature. "Get account info" and "Check billing" sound different but share too much vocabulary — users can't predict which their message triggers, and neither can the model. Merge them or draw a sharper boundary (e.g., "account settings" vs "invoice history").

**Name intents descriptively, not abstractly.** `place_order` beats `purchase_intent`. The name appears in few-shot examples; it must be self-evident.

**Include an `unknown` intent.** This is the safety valve. Anything the model isn't confident about falls here. Never route unknown to a random handler.

## Few-Shot Prompting for Classification

Local models respond better to examples than instructions alone. Provide 2–3 examples per intent in the prompt:

```
Classify the user message into one of: [place_order, track_shipment, cancel_order, billing_inquiry, unknown]

Examples:
"I want to buy 3 units of SKU-442" → place_order
"Where is my package?" → track_shipment
"Stop my subscription" → cancel_order
"What was I charged last month?" → billing_inquiry
"Do you sell wholesale?" → unknown

Message: "{user_input}"
Intent:
```

Use real examples from your actual traffic, not synthetic ones. Real language has typos, abbreviations, and domain slang that synthetic examples miss.

## Confidence Score via Log Probabilities

Force the model to output only the intent label (not a sentence), then read the log probability of the top token. Log probability maps directly to confidence:

- logprob > -0.1 → very high confidence (p > 0.90)
- logprob -0.1 to -0.5 → moderate confidence (p 0.60–0.90)
- logprob < -0.5 → low confidence → fall back to `unknown`

With Ollama, use `"logprobs": true` in the generate request. With llama.cpp server, use the `/completion` endpoint with `n_probs: 5`. The distribution across the top-5 tokens tells you whether the model was decisive or split between two intents.

## Fallback to Unknown

Two triggers for unknown routing:
1. Model outputs an intent label not in your taxonomy (hallucinated label) → remap to `unknown`.
2. Confidence below threshold (logprob < -0.5) → override to `unknown`.

The `unknown` handler should ask a clarifying question or route to a human, never silently fail.

## Routing to Handlers

Build a dispatch table, not a chain of if/else:

```js
const handlers = {
  place_order: placeOrderHandler,
  track_shipment: trackShipmentHandler,
  // ...
  unknown: unknownHandler,
};
const handler = handlers[intent] ?? handlers.unknown;
await handler(message, context);
```

Log every intent classification with the input message, predicted intent, confidence, and which handler ran. This data drives taxonomy iteration — you'll discover new intents you missed and intents that never fire.

## Key Rules

- Keep taxonomy to 5–15 intents; use sub-classifiers for finer granularity.
- Zero overlap between intent definitions — if you need a Venn diagram to explain them, redesign.
- Always include an `unknown` intent and route low-confidence predictions to it.
- Use real traffic examples in few-shot prompts, not synthetic ones.
- Read log probabilities to get confidence scores; don't ask the model to self-report confidence in prose.
- Log every classification with inputs, outputs, and confidence for ongoing taxonomy tuning.
