# Local Models: Prompt Templates

## Overview

Local models (Llama 3, Mistral, Phi, Gemma) require explicit, structured prompts. Unlike hosted models trained on instruction-following with RLHF, local models vary widely in how they interpret prompts. Templates reduce variability and make output predictable enough for pipeline use.

## Chat Format vs. Raw Completion

Most local models are instruction-tuned and expect a chat format, not raw completion:

```
Wrong (raw completion):
  "The invoice total should be"

Right (instruction-tuned chat):
  [INST] Calculate the invoice total for: 3 items at $50 each, 10% tax [/INST]
```

Each model family has its own chat template. Use the model's tokenizer's `apply_chat_template()` if using Transformers, or match the format for the inference server.

## Common Chat Formats

### Llama 3 / Llama 3.1

```
<|begin_of_text|><|start_header_id|>system<|end_header_id|>
You are a helpful assistant.<|eot_id|>
<|start_header_id|>user<|end_header_id|>
{user_message}<|eot_id|>
<|start_header_id|>assistant<|end_header_id|>
```

### Mistral / Mixtral

```
<s>[INST] {user_message} [/INST]
```

With system prompt:
```
<s>[INST] <<SYS>>
{system_prompt}
<</SYS>>

{user_message} [/INST]
```

### Phi-3

```
<|system|>
{system_prompt}<|end|>
<|user|>
{user_message}<|end|>
<|assistant|>
```

### Gemma 2

```
<start_of_turn>user
{user_message}<end_of_turn>
<start_of_turn>model
```

## Use the Inference Server's API

Don't format chat tokens manually. Use the inference server's chat completions endpoint:

```ts
// Ollama
const res = await fetch('http://localhost:11434/api/chat', {
  method: 'POST',
  body: JSON.stringify({
    model: 'llama3.1',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userMessage },
    ],
    stream: false,
  }),
})

// llama.cpp server / LM Studio (OpenAI-compatible)
const res = await fetch('http://localhost:8080/v1/chat/completions', {
  method: 'POST',
  body: JSON.stringify({
    model: 'local-model',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userMessage },
    ],
  }),
})
```

The server handles template formatting. Always prefer this over raw completion.

## Effective System Prompts for Local Models

Local models need more explicit guidance than hosted models:

```
Ineffective:
  "You are a helpful assistant."

Effective:
  "You are a data extraction assistant. Your job is to extract specific fields from text.
   Always respond with valid JSON only. No explanation, no commentary, no markdown.
   If a field cannot be found, use null for its value.
   Output format: { 'name': string|null, 'date': string|null, 'amount': number|null }"
```

Key elements for local model system prompts:
1. **Role** — what the model is doing
2. **Task** — exactly what to produce
3. **Format** — explicit output format with example
4. **Edge cases** — what to do when something is missing or ambiguous
5. **Constraints** — what NOT to include (explanations, markdown, apologies)

## JSON Output Template

For extraction tasks, give the exact schema in the prompt:

```
Extract the following fields from the text below.
Return ONLY valid JSON matching this exact schema:
{
  "invoice_number": "string or null",
  "date": "YYYY-MM-DD format or null", 
  "vendor_name": "string or null",
  "total_amount": number (cents, integer) or null,
  "line_items": [{"description": "string", "amount": number}]
}

Text:
---
{input_text}
---

JSON:
```

The trailing "JSON:" prefix primes the model to output JSON immediately.

## Classification Template

```
Classify the following support ticket into ONE category.
Categories: billing, technical, feature-request, account, other

Rules:
- Output only the category name, nothing else
- Use lowercase
- If unclear, use "other"

Ticket: {ticket_text}

Category:
```

## Summarization Template

```
Summarize the following in {max_words} words or fewer.
Focus on: {focus_points}
Audience: {audience}
Do not include: opinions, speculation, information not in the source text.

Text:
{input_text}

Summary:
```

## Temperature Settings

| Task | Temperature |
|------|------------|
| JSON extraction | 0.0 - 0.1 |
| Classification | 0.0 - 0.2 |
| Summarization | 0.3 - 0.5 |
| Content generation | 0.7 - 0.9 |
| Brainstorming | 0.9 - 1.2 |

Low temperature = more deterministic, less creative. For pipeline automation, use 0.0-0.2.
