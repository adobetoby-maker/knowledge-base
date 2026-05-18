# Code Completion with Local Models (Copilot-Style)

Code completion is the latency-tightest application of local inference. Users feel a 500ms pause; a 100ms completion feels like thinking. Anything beyond 1 second breaks the flow state. This shapes every architectural decision.

## Fill-in-the-Middle (FIM) Format

Standard left-to-right generation (prompt → completion) is wrong for inline completion. The model sees prefix context but not what comes after the cursor, so it can't constrain the completion to fit. FIM was specifically designed for this: pass prefix, suffix, and a middle-marker, and the model generates what belongs in the gap.

Ollama/llama.cpp expose FIM via special tokens. For Code Llama:

```
<PRE> {prefix_before_cursor} <SUF> {suffix_after_cursor} <MID>
```

For DeepSeek Coder:
```
<｜fim▁begin｜>{prefix}<｜fim▁hole｜>{suffix}<｜fim▁end｜>
```

Always check which FIM tokens your specific model checkpoint uses — they differ by family and are not interchangeable. Using the wrong tokens causes the model to generate narrative text rather than code.

## Context Window Sizing

Keep the completion context window small: 512–2048 tokens maximum. Reasons:

1. **Latency scales with context length.** At 2048 tokens the model must process every token in the KV cache before generating. At 512 tokens it's 4× faster.
2. **Code completion doesn't need long context.** The function signature, the few lines above the cursor, and the few lines below are 95% of what the model needs. File-level context matters for imports and class definitions; pass those as a compressed prefix, not the full file.
3. **Relevant context beats large context.** Retrieve the 10 most relevant lines from the file (current function, referenced function signatures, imports) rather than naively dumping the first 2048 tokens.

Practical budget: 512 tokens prefix + 256 tokens suffix + 128 tokens for the generated completion. Tune down if p95 latency exceeds 300ms on your hardware.

## Stop Sequences

Code completion must stop at the right boundary. Without stop sequences, the model will generate multiple functions or fill in code the user hasn't written yet. Set stop sequences to:

- `\n\n` (blank line — end of a block in most languages)
- The next structural keyword at the same indentation level (`def `, `class `, `function `, `}` on its own line)
- Language-specific terminators

Do not rely on max_tokens alone — it produces truncated mid-expression completions that break syntax.

## Latency Targets

| Latency | User perception |
|---|---|
| < 100ms | Invisible, feels native |
| 100–300ms | Acceptable, slight pause |
| 300–500ms | Noticeable, acceptable for single-line |
| 500ms–1s | Disrupts flow, acceptable only for block completion |
| > 1s | Broken — user has already typed past the suggestion |

Achieve sub-200ms by: using a quantized model (Q4_K_M), keeping context under 512 tokens, batching prefix/suffix embedding ahead of time, and running the model server warm (keep-alive, don't cold-load per request).

## Key Rules

- Use FIM format, not standard completion — verify the exact tokens for your model family
- Cap context at 2048 tokens; prefer 512 for single-line completions
- Set stop sequences for language-specific block boundaries
- Target < 300ms; instrument latency at p50 and p95, not just average
- Keep the model server warm — cold start latency is 2–10× worse
- Pass only relevant context (current function + imports), not the full file
