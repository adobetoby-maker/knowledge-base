# Local Model Cost Comparison

## The Real Cost of Cloud Models

API costs for a batch job depend on token volume. At scale, these add up:

| Model | Input per 1M tokens | Output per 1M tokens |
|---|---|---|
| Claude Haiku 4.5 | $0.80 | $4.00 |
| Claude Sonnet 4.6 | $3.00 | $15.00 |
| Claude Opus 4.7 | $15.00 | $75.00 |
| GPT-4o mini | ~$0.15 | ~$0.60 |
| GPT-4o | ~$5.00 | ~$15.00 |

For a batch job generating 100 articles at ~800 tokens each:
- **Haiku**: ~$0.32 output cost
- **Sonnet**: ~$1.20 output cost

Tiny at this scale. But a job running nightly × 365 days × growing article count matters.

## Local Model Cost

Effectively zero beyond electricity and hardware depreciation:
- Ollama on an M1 MacBook Pro: ~$0 per query
- Power draw during generation: ~15-20W extra
- At 24/7 operation: ~$5-15/month in electricity
- This breaks even vs Haiku at ~15,000+ Haiku requests/month

Below ~5,000 requests/month: just use Haiku. Above that: evaluate local.

## Quality vs Cost Decision

This is the real trade-off — not just the dollar amount:

```
Task: Generate an SEO article intro paragraph
Local (llama3.1:8b): ~70% quality vs cloud
Cost: $0

→ If 70% quality is acceptable for this use case: use local
→ If it needs to be customer-facing and high quality: use Haiku

Task: Generate TypeScript interface from schema
Local (qwen2.5-coder:7b): ~80% quality for simple schemas, drops fast for complex ones
Cost: $0

→ Use local for simple schemas, Haiku for complex ones
```

## Hybrid Strategy

Use both in the same pipeline:

```typescript
interface GenerationConfig {
  model: 'local' | 'haiku' | 'sonnet'
  qualityThreshold: number  // 0-1, what's acceptable
}

const TASK_CONFIG: Record<string, GenerationConfig> = {
  'article-body': { model: 'haiku', qualityThreshold: 0.8 },      // customer-facing
  'meta-description': { model: 'haiku', qualityThreshold: 0.7 },   // SEO-critical
  'boilerplate-types': { model: 'local', qualityThreshold: 0.6 },  // mechanical
  'rename-variables': { model: 'local', qualityThreshold: 0.9 },   // deterministic
  'sql-from-schema': { model: 'haiku', qualityThreshold: 0.85 },   // need accuracy
}
```

## Measuring Quality

Automated quality assessment for generated content:

```typescript
function assessQuality(generated: string, expected: {
  minLength: number
  requiredPhrases?: string[]
  forbiddenPatterns?: RegExp[]
}): number {
  let score = 1.0
  
  if (generated.length < expected.minLength) {
    score -= 0.3  // too short
  }
  
  for (const phrase of expected.requiredPhrases ?? []) {
    if (!generated.includes(phrase)) score -= 0.15
  }
  
  for (const pattern of expected.forbiddenPatterns ?? []) {
    if (pattern.test(generated)) score -= 0.2
  }
  
  return Math.max(0, score)
}

// Usage:
const quality = assessQuality(localOutput, {
  minLength: 200,
  requiredPhrases: ['Twin Falls'],
  forbiddenPatterns: [/\[object Object\]/, /TODO/, /PLACEHOLDER/],
})

if (quality < 0.7) {
  // Fall back to Haiku
  return await claudeGenerate(prompt, 'claude-haiku-4-5')
}
```

## Token Budget for Local Models

Local models have hard context limits AND quality degrades before the limit:

| Model | Hard limit | Quality degrades after |
|---|---|---|
| llama3.2:3b | 128k | 4k tokens |
| llama3.1:8b | 128k | 8k tokens |
| qwen2.5-coder:7b | 128k | 8k tokens |
| codellama:13b | 16k | 8k tokens |

For local batch jobs: keep total prompt (system + context + user) under 3k tokens for reliable output quality. Use pre-built context bundles from `13-stack-bundles/` to pack the most relevant context into this budget.

## When Cost Doesn't Matter

Interactive development sessions (daytime coding, debugging, architecture decisions): use Sonnet without hesitation. The cost per session is $0.50-5.00 — trivial compared to developer time saved.

Reserve cost optimization for batch jobs and overnight automation.
