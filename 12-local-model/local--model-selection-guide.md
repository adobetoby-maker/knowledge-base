# Local Model Selection Guide

## Model Families for Local Use

### Llama 3.2 (Meta)
- `llama3.2:1b` — 1B params, very fast, limited reasoning. Use for: classification, simple extraction, keyword tagging.
- `llama3.2:3b` — 3B params, good balance. Use for: article classification, metadata extraction, short rewrites.
- `llama3.2` (8B) — strong all-around. Use for: article generation, content analysis, multi-field extraction.

### Mistral
- `mistral:7b` — strong for structured output and instruction following. Good for JSON extraction.
- `mistral-nemo` — 12B, excellent instruction following, better structured output than Llama.

### Qwen2.5
- `qwen2.5:7b` — strong multilingual, good for Spanish/Portuguese content (climb-brasil, language-lens).
- `qwen2.5:14b` — best local option for content generation if GPU allows.

### CodeLlama
- `codellama:7b` — for code-related tasks (type checking descriptions, migration generation).

## Selection Decision Tree

```
Is this multilingual content (Spanish, Portuguese)?
  → qwen2.5:7b or qwen2.5:14b

Is this structured data extraction (JSON output)?
  → mistral-nemo or mistral:7b (better structure adherence than Llama)

Is this bulk article generation (quality matters)?
  → llama3.2 (8B) minimum, qwen2.5:14b for best results

Is this simple classification (spam, category, sentiment)?
  → llama3.2:3b (fast, cheap enough)

Is this code-related?
  → codellama:7b for generation, llama3.2 for code review/explanation

Is hardware limited (< 8GB VRAM)?
  → llama3.2:3b or llama3.2:1b + quantization
```

## Quantization Trade-offs

```bash
# Available quantization options via Ollama:
ollama pull llama3.2          # default (Q4_K_M) — good balance
ollama pull llama3.2:latest   # same

# Quantization levels:
# Q2_K  — smallest, fastest, lowest quality (avoid for content)
# Q4_K_M — recommended: 80% of full quality, 40% of memory
# Q5_K_M — good quality, moderate memory
# Q8_0  — near-full quality, large memory requirement
# F16   — full precision, requires GPU with large VRAM
```

For content generation tasks (articles, rewrites): Q4_K_M minimum.
For classification tasks (category, sentiment): Q2_K is acceptable.

## Context Window Considerations

Default context window per model:
- `llama3.2:1b` — 4K tokens
- `llama3.2:3b` — 4K tokens
- `llama3.2` (8B) — 8K tokens
- `mistral:7b` — 8K tokens
- `qwen2.5:7b` — 32K tokens (very long context capable)

For article generation (system prompt + article brief + 1000-word output): 8K is usually enough.
For context-heavy tasks (summarize a full document, analyze a long article): use qwen2.5 with 32K context.

## Configuring Context Window in Ollama

```typescript
const response = await ollama.chat({
  model: 'llama3.2',
  messages,
  options: {
    num_ctx: 8192,     // increase if model supports it
    temperature: 0.7,   // 0 = deterministic, 1 = creative
    top_p: 0.9,
    repeat_penalty: 1.1,  // reduce repetition in long articles
  },
})
```

## Performance Benchmarks (Approximate)

On M2 Mac with 16GB RAM:

| Model | Tokens/sec | Memory |
|---|---|---|
| llama3.2:1b | ~80 t/s | ~1.5GB |
| llama3.2:3b | ~45 t/s | ~3GB |
| llama3.2 (8B) | ~20 t/s | ~6GB |
| qwen2.5:7b | ~18 t/s | ~5.5GB |
| qwen2.5:14b | ~10 t/s | ~10GB |

A 1000-word article at ~20 t/s: ~3 minutes. For 50 articles: ~2.5 hours overnight.
