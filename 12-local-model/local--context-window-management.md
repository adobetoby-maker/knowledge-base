# Local Model: Context Window Management

## Overview
Local models have context window limits from 4K tokens (older models) up to 128K tokens (Qwen2.5, Gemma2). Unlike hosted APIs where you pay per token and the API enforces limits gracefully, local models silently truncate or produce garbage output when context exceeds their limit. The practical strategy is to manage context aggressively—summarizing old turns, chunking long documents, and choosing models with window sizes matched to your task.

## Context Window by Model (Approximate)

```
Model                     Context Window    Notes
-------------------------------------------------
Llama 3.1 8B / 70B        128K              Works well at 128K
Qwen2.5 7B / 14B / 72B    128K              Best long-context performance
Mistral 7B v0.3           32K               Degradation > 16K
Phi-3 mini / medium       128K              Good at 128K; fast
Gemma 2 9B / 27B          8K                Strong at 8K; poor beyond
Llama 2 7B / 13B          4K                Hard limit; legacy models
CodeLlama 7B / 13B        16K               Code-focused
DeepSeek Coder v2         128K              Code-optimized, long context
```

## Strategy 1: Sliding Window for Conversations

```ts
interface Message { role: string; content: string; }

function applyContextWindow(
  messages: Message[],
  maxTokens: number,
  systemPrompt: string
): Message[] {
  const systemTokens = estimateTokens(systemPrompt);
  const responseReserve = 500; // reserve tokens for the response
  let budget = maxTokens - systemTokens - responseReserve;

  // Always keep the most recent messages; drop from the front
  const window: Message[] = [];
  for (let i = messages.length - 1; i >= 0; i--) {
    const msgTokens = estimateTokens(messages[i].content) + 4; // role overhead
    if (budget - msgTokens < 0) break;
    window.unshift(messages[i]);
    budget -= msgTokens;
  }

  return window;
}

// Rough token estimator (English text)
function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4); // ~4 chars per token for English
}
```

## Strategy 2: Summarize-and-Compress Old Turns

```ts
async function compressConversationHistory(
  messages: Message[],
  model: string,
  keepRecentN = 6
): Promise<Message[]> {
  if (messages.length <= keepRecentN) return messages;

  const toCompress = messages.slice(0, -keepRecentN);
  const recentMessages = messages.slice(-keepRecentN);

  // Summarize old portion
  const summaryPrompt = `Summarize this conversation concisely, preserving key facts,
decisions, and context needed for future turns. Be brief but complete.

Conversation:
${toCompress.map(m => `${m.role}: ${m.content}`).join('\n')}

Summary:`;

  const summaryResponse = await generate(model, summaryPrompt, { temperature: 0.1 });

  return [
    { role: 'system', content: `Previous conversation summary: ${summaryResponse}` },
    ...recentMessages,
  ];
}
```

## Strategy 3: Chunking Long Documents

```ts
function chunkDocument(text: string, chunkSize = 1500, overlap = 200): string[] {
  const chunks: string[] = [];
  let start = 0;

  while (start < text.length) {
    const end = start + chunkSize;
    let chunk = text.slice(start, end);

    // Try to break at sentence boundary
    if (end < text.length) {
      const lastPeriod = chunk.lastIndexOf('. ');
      if (lastPeriod > chunkSize * 0.7) {
        chunk = text.slice(start, start + lastPeriod + 1);
      }
    }

    chunks.push(chunk);
    start += chunk.length - overlap; // overlap for continuity
  }

  return chunks;
}

// Process with map-reduce pattern
async function analyzeDocument(text: string, question: string, model: string) {
  const chunks = chunkDocument(text);

  // Map: extract relevant info from each chunk
  const extracts = await Promise.all(
    chunks.map(chunk =>
      generate(model, `Context: ${chunk}\n\nQuestion: ${question}\n\nRelevant excerpt:`, {
        temperature: 0.1,
        max_tokens: 300,
      })
    )
  );

  // Reduce: synthesize extracts into final answer
  const finalAnswer = await generate(model,
    `Synthesize these excerpts to answer: "${question}"\n\n${extracts.join('\n---\n')}`,
    { temperature: 0.2 }
  );

  return finalAnswer;
}
```

## Context Length vs Accuracy Tradeoff

```
Research finding: most models degrade significantly in the middle of long contexts
("Lost in the Middle" problem). Critical information should be at the beginning
or end of the context, not buried in the middle.

Model performance by context position:
  First 20%:  ★★★★★ excellent recall
  Last 20%:   ★★★★☆ good recall
  Middle 60%: ★★★☆☆ degraded recall (especially for models without RoPE scaling)

Mitigation:
  - Put the question/task at both the beginning AND end of long contexts
  - Chunk documents rather than stuffing everything into one call
  - Qwen2.5 and Phi-3 handle long context better than Llama 2 / Mistral
```

## Models That Handle Long Context Well

```
Best for 32K+ contexts:
  Qwen2.5 7B/14B/72B       — best overall long-context performance
  Phi-3 medium 128K         — fast, good for structured tasks
  Llama 3.1 8B/70B          — solid at 128K, widely available

Avoid for long context:
  Llama 2 (all sizes)       — 4K hard limit, no extension
  Gemma 2                   — 8K practical limit
  Mistral 7B v0.1/v0.2      — degrades beyond 8K despite 32K advertised
```

## Key Rules
- **Estimate tokens before sending** — use `text.length / 4` as a rough estimate; 1 token ≈ 4 English characters.
- **Sliding window first, summarization second** — sliding window is cheaper; summarization adds a model call.
- **Put instructions at top AND bottom for long contexts** — models lose track of instructions buried in the middle.
- **Chunk documents at sentence boundaries** — mid-sentence chunks lose meaning; split at `. ` or `\n\n`.
- **Qwen2.5 for serious long-context tasks** — it genuinely outperforms other open models on long-context benchmarks.
- **Reserve tokens for the response** — always subtract 500–1000 tokens from the budget for the model's output.
