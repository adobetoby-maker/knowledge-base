# Agents: Multi-Turn Context Management

## Overview
LLMs are stateless — they have no memory between API calls. The illusion of conversation continuity is maintained by including prior messages in every request. As conversations grow, the context window fills, costs rise, and the model's attention on early messages degrades. Managing the context window in multi-turn conversations is therefore a core engineering concern, not just an optimization.

## Message Array Structure

Every request to the model includes:
1. **System prompt** (static): persona, capabilities, constraints, injected context
2. **Messages array** (growing): alternating user/assistant turns

The model only sees what's in these two inputs. Nothing persists otherwise.

## Context Window Pressure

As the conversation grows:
- Input tokens increase linearly → cost increases linearly
- Context window limit approaches → must trim or summarize to continue
- Model attention degrades on very early messages in very long contexts ("lost in the middle" effect)

## Trimming Strategies

**FIFO trimming (simplest)**
Drop the oldest user/assistant pairs when approaching the context limit. Fast to implement, but loses early context entirely. Works for shallow conversations (customer support, one-off tasks).

**Summarization trimming (better for long sessions)**
When the history grows past a threshold:
1. Extract the oldest N message pairs
2. Send them to the model with a "summarize this conversation so far" prompt
3. Replace the trimmed messages with a summary injected into the system prompt
4. Continue with the remainder of the history

The summary lives in the system prompt as a "context so far" block — permanent within the session.

**Sliding window (simplest useful default)**
Keep the last K turns verbatim. Enough recency for most conversations, very simple to implement.

## System Prompt Context Block

For long-running agents, maintain a dynamic context block at the bottom of the system prompt:

```
## Conversation History Summary
[Auto-updated summary of the conversation so far]

## Current Task State
[What has been accomplished, what is pending]
```

Update this block before each API call when the history has grown significantly. This way, even if turns are trimmed, the essential context persists.

## What to Keep vs Trim

**Keep:**
- The most recent N turns (recency matters most)
- Turns that established critical decisions or constraints
- Any turn where a tool returned important data that is still relevant

**Trim first:**
- Early turns that were superseded by later clarifications
- Turns that contained failed attempts that were abandoned
- Repetitive back-and-forth that reduced to a single conclusion

## Token Counting

Trim proactively — don't wait for a context limit error:
- Track running token count with the tokenizer (tiktoken for OpenAI-compatible models, Anthropic token counting API)
- Trigger summarization when at 70–80% of context limit, not at 100%
- Reserve headroom for the model's response (output tokens share the context window)

## Key Rules

- The messages array is the entire memory — nothing else persists between API calls
- Summarize before trimming — pruned turns can often be replaced by a 100-token summary
- Never trim the system prompt — it's the static contract with the model
- Keep the most recent turns; older turns have lower recall probability even when present
- Token counting should happen before every API call in production systems
- Session state (current task, completed steps) belongs in the system prompt context block, not only in message history (message history may be trimmed)
