# Agent Scratchpad / Thinking Space

## Purpose

Scratchpad gives an agent a place to reason before committing to an output. When reasoning and final answer share the same token stream, the model gets anchored by its first words — errors compound. Separating them lets the reasoning be exploratory and messy while the output stays clean and correct.

Visible reasoning improves accuracy on multi-step problems because the model can backtrack, contradict itself, notice errors, and try a different path — all before the user sees a word. Studies on chain-of-thought prompting consistently show that models which "think out loud" outperform models that jump directly to answers, even when the thinking is invisible to the end user.

## The `<parameter name="thinking">` Block Pattern

Wrap all intermediate reasoning in a `<thinking>` tag. Place it before the final answer section:

```
<thinking>
Let me break this down...
The user asked X. That means I need Y.
Wait, Y won't work because Z. Let me try W instead.
W looks right. The answer is W.
</thinking>

The recommended approach is W because...
```

The `<thinking>` block is for the model's benefit, not the user's. It should be stripped before returning the final response in production pipelines. An API layer that post-processes `response.content` can do this with a simple regex or tag-stripping function.

## When to Use It

Use scratchpad when:
- The task requires more than 2–3 reasoning steps
- The correct answer depends on ruling out plausible-but-wrong options
- The model must reconcile conflicting pieces of context
- Mathematical or logical derivation is involved

Skip scratchpad for simple lookups, single-step transformations, or tasks where latency matters more than accuracy.

## Stripping Scratchpad from Final Output

Never expose raw scratchpad to end users in a production UI. It degrades trust, leaks intermediate errors, and can expose internal prompt structure. Strip it at the API boundary:

```python
import re

def strip_thinking(text: str) -> str:
    return re.sub(r"<thinking>.*?</thinking>", "", text, flags=re.DOTALL).strip()
```

For streaming responses, buffer until `</thinking>` is detected, then begin forwarding tokens to the client.

## Separating Reasoning from Answer

The scratchpad is not a first draft — it is a different mode of operation. Do not summarize the scratchpad into the answer. Write the answer fresh, informed by what the scratchpad concluded. This prevents the answer from inheriting the scratchpad's hedging, false starts, and verbosity.

## Multi-Turn Agents

In a multi-turn loop, the scratchpad persists within a single turn only. Do not carry scratchpad content across turns as part of the conversation history — it inflates context rapidly. Carry only conclusions.

## Key Rules

- Place `<thinking>` before the answer, never interleaved with it
- Strip `<thinking>` blocks before returning output to users
- Use scratchpad for any task requiring 3+ reasoning steps
- Write the final answer fresh — do not inline the scratchpad
- In streaming, buffer the thinking block entirely before forwarding output
- Never forward scratchpad content across turns in conversation history
