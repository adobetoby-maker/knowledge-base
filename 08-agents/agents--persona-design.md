# Agent Persona Design

A persona is the stable identity an agent maintains across a conversation. It shapes tone, refusal behavior, response length defaults, and vocabulary choices. Well-designed personas produce consistent, predictable behavior; vague personas drift based on how the user phrases requests.

## System Prompt Persona Definition

The system prompt is where persona lives. It must specify:
- **Role identity**: who this agent is (e.g., "a senior customer support specialist for Acme Corp").
- **Tone calibration**: formal/informal, terse/verbose, empathetic/neutral.
- **Domain scope**: what topics the agent addresses vs. defers to other resources.
- **Communication defaults**: default response length, use of bullet points vs. prose, whether to ask clarifying questions or proceed with best-guess interpretation.

The persona statement should be one concrete paragraph, not a list of adjectives. Adjectives like "helpful, friendly, professional" are too vague to constrain behavior. Concrete behaviors do: "When a user is frustrated, acknowledge the frustration in one sentence before addressing the technical issue."

## Persona Constraints

Define what the agent refuses, not just what it does. Explicit refusal constraints are more reliable than implicit inference from the role description:
- "Do not provide legal or financial advice. Refer users to a qualified professional for those questions."
- "Do not impersonate a human if sincerely asked whether you are an AI."
- "Do not discuss competitor products by name."

Constraints should state the behavior, not just the category. "Don't be rude" is unenforceable. "If a user is hostile, do not mirror their tone; respond calmly and without sarcasm" is enforceable.

## Tone Calibration

Tone should be calibrated to the user context, not the agent's aesthetic preference:
- **B2B SaaS support**: technical precision, minimal hedging, numbered steps for procedures.
- **Consumer product support**: warmer, validate feelings first, avoid technical jargon unless the user introduces it.
- **Internal developer tool**: terse, code-first responses, no preamble.

Include a few example exchanges in the system prompt to anchor tone — telling is weaker than showing. Three input/response examples in the system prompt calibrate tone better than three paragraphs describing it.

## Multi-Persona Routing

When a product needs multiple distinct agents (a sales agent, a support agent, a technical expert), implement routing at the orchestrator layer, not by prompt-switching mid-conversation. Reasons:
- Switching a persona mid-conversation creates incoherence — the user experiences a different "person" without transition.
- Shared context between personas must be explicitly passed, not assumed.

Routing logic: classify the incoming message by intent, route to the appropriate persona's system prompt, maintain a per-persona conversation history, and if the user explicitly asks to be transferred (e.g., "connect me to billing"), make the transition explicit in the response: "I'm connecting you to the billing team now."

Never allow one persona to impersonate another by adopting its phrasing. If the technical agent and the support agent have distinct voices, that distinction is load-bearing for the user's trust model.

## Key Rules

- System prompt persona must specify role, tone, scope, and communication defaults — adjectives alone are insufficient.
- Refusal constraints must describe the behavior, not just the category of refusal.
- Include 2–3 example exchanges in the system prompt for tone anchoring — examples outperform descriptions.
- Route to distinct personas at the orchestrator layer, not via mid-conversation prompt modification.
- Never allow a persona to claim to be human if the user sincerely asks.
- Persona consistency is a reliability feature — drift undermines user trust even when individual responses are correct.
