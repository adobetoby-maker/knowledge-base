# Managing Conversation History with Local Models

Local models degrade faster with long conversation histories than their cloud counterparts. A 7B model fine-tuned for chat was trained on thousands of turns, but at inference time it processes the entire history as a flat token sequence. The further the relevant context is from the generation point, the more likely the model is to ignore or contradict it. This is the "lost in the middle" problem, and it's significantly worse at small model sizes.

## Message Role Format

Local chat models (Llama 3, Mistral, Phi-3, etc.) use a role-tagged format. Always use the canonical three roles:

- `system` — task instructions, persona, constraints. Appears once at the top. Never repeat it mid-conversation.
- `user` — human turn
- `assistant` — model turn

Do not invent roles like `context` or `memory`. They will be misinterpreted or ignored. If you're using a raw completion API rather than a chat API, format with the model's specific template (e.g., `[INST]...[/INST]` for Mistral, `<|user|>...<|end|>` for Phi-3). Mismatched templates cause silent quality degradation.

## Truncation Strategy

When history exceeds the context window (or a soft budget you set), truncate from the middle — not from the end. Preserve:

1. The full system prompt (always)
2. The most recent N turns (recency matters most for coherence)
3. The oldest turn if it contains a critical constraint or the initial user request

Drop the middle turns first. A window of the last 6–8 turns (3–4 exchanges) is usually sufficient for task continuity. Going beyond 12 turns with a 7B model rarely improves coherence and reliably increases hallucination.

## Summary Injection

For conversations that need to span more than ~10 turns, summarize dropped history and inject it as a prefix in the system prompt or as a synthetic user/assistant exchange at position 2 (after the system prompt):

```
System: You are a helpful assistant. [task instructions]
User: [Conversation so far summary]: The user is planning a road trip from Denver to Portland. 
They have a budget of $1,200 and prefer scenic routes. Two stops have been confirmed: Salt Lake City and Boise.
Assistant: Understood. I'll continue from there.
User: [current message]
```

The summary substitutes for dropped turns. Keep it under 200 tokens. A dense summary is more useful than a sparse transcript.

## Why Local Models Degrade Faster

Cloud models (GPT-4, Claude Opus) run at scales where attention over long sequences stays sharp — both because of larger parameter counts and because they are often trained with longer context windows and positional encodings optimized for retrieval across distance. A local 7B–13B model was typically trained on sequences of 2K–4K tokens, so its positional encoding and attention heads are not calibrated for retrieving facts from 8,000 tokens back. Recency bias is a natural consequence: the model implicitly weights recent tokens more, meaning early constraints get forgotten.

This is architectural, not a prompt engineering failure. The correct response is structural: keep histories short, summarize aggressively, and never assume the model has "remembered" something said 15 turns ago.

## Key Rules

- Always include the system prompt as the first message; never repeat it inline
- Use only system/user/assistant roles
- Keep live history to the last 6–10 turns maximum
- Truncate from the middle, preserving system prompt + recent turns
- Summarize dropped context and inject near the top, not the bottom
- Do not assume a local model retains constraints stated more than 5–6 turns back
- Test degradation explicitly: run a 20-turn script and check if early constraints hold
