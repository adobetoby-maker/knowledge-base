# Skill: Testing AI Outputs

## Overview
AI outputs are non-deterministic, which breaks traditional assertion-based tests. The solution is a two-tier eval system: deterministic checks for structure and format (run fast, run always), and probabilistic evals using LLM-as-judge for quality (run in CI, gate on regression). Without eval automation, every prompt or model change is a gamble — you won't know it regressed until users complain.

## Tier 1: Deterministic Evals (Always Run)

Check structure, format, constraints — things that are always true regardless of content:

```ts
import { z } from 'zod'

const SupportResponseSchema = z.object({
  category: z.enum(['billing', 'technical', 'general', 'escalate']),
  confidence: z.number().min(0).max(1),
  response: z.string().min(20).max(500),
  requires_human: z.boolean(),
})

test('support classifier returns valid structure', async () => {
  const result = await classifySupportTicket('My payment failed')
  expect(() => SupportResponseSchema.parse(result)).not.toThrow()
})

test('high confidence escalations always require human', async () => {
  const result = await classifySupportTicket('I want to sue your company')
  expect(result.category).toBe('escalate')
  expect(result.requires_human).toBe(true)
})
```

## Tier 2: Probabilistic Evals (LLM-as-Judge)

For quality, tone, accuracy — use a second LLM call to grade the output:

```ts
import Anthropic from '@anthropic-ai/sdk'

const anthropic = new Anthropic()

async function judgeOutput(
  input: string,
  output: string,
  rubric: string
): Promise<{ score: number; reasoning: string; pass: boolean }> {
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-5',  // cheaper model for judging
    max_tokens: 512,
    messages: [{
      role: 'user',
      content: `
        Evaluate this AI response on a scale of 1-5.

        Rubric: ${rubric}

        Input: ${input}
        Response: ${output}

        Respond with JSON: { "score": number, "reasoning": string }
      `,
    }],
  })

  const result = JSON.parse(response.content[0].text)
  return { ...result, pass: result.score >= 3 }
}

test('response is helpful and accurate', async () => {
  const input = 'How do I reset my password?'
  const output = await generateSupportResponse(input)
  const judgment = await judgeOutput(input, output,
    'Response should be helpful, accurate, specific to the question, and polite.'
  )
  expect(judgment.pass).toBe(true)
}, 30_000) // longer timeout for AI calls
```

## Regression Suite

Build a golden dataset of (input, expected behavior) pairs. Run on every model or prompt change:

```ts
// eval/support-classifier.eval.ts
const EVAL_CASES = [
  {
    input: 'My card was charged twice',
    expect: { category: 'billing', requires_human: false },
    rubric: 'Response acknowledges the issue and explains how to resolve a duplicate charge',
  },
  {
    input: 'The app crashes when I open it on iPhone',
    expect: { category: 'technical' },
    rubric: 'Response asks for device/OS version and provides troubleshooting steps',
  },
  // ... 20+ cases
]

async function runEvals() {
  const results = await Promise.all(
    EVAL_CASES.map(async (c) => {
      const output = await classifySupportTicket(c.input)

      // Deterministic checks
      const structureOk = Object.entries(c.expect).every(
        ([k, v]) => output[k as keyof typeof output] === v
      )

      // Probabilistic check
      const { pass, score, reasoning } = await judgeOutput(c.input, output.response, c.rubric)

      return { input: c.input, structureOk, qualityPass: pass, score, reasoning }
    })
  )

  const passRate = results.filter(r => r.structureOk && r.qualityPass).length / results.length
  console.log(`Pass rate: ${(passRate * 100).toFixed(1)}%`)

  if (passRate < 0.85) {
    throw new Error(`Eval pass rate ${passRate} below threshold 0.85`)
  }

  return results
}
```

## Running Evals in CI

```json
{
  "scripts": {
    "eval": "tsx eval/run-all.ts",
    "test": "vitest",
    "test:all": "npm test && npm run eval"
  }
}
```

```yaml
# .github/workflows/eval.yml — runs on prompt changes only
on:
  push:
    paths:
      - 'prompts/**'
      - 'lib/ai/**'

jobs:
  eval:
    steps:
      - run: npm run eval
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

## Production Sampling

```ts
// Sample 10% of production outputs for async review
async function generateWithSampling(input: string): Promise<string> {
  const output = await generate(input)

  if (Math.random() < 0.1) {
    // Fire and forget — don't block the response
    storeForReview({ input, output, ts: new Date().toISOString() }).catch(console.error)
  }

  return output
}
```

Review sampled outputs weekly. When you find failures, add them to the eval suite.

## Key Rules
- Never use `expect(output).toBe(exactString)` for AI outputs — they change run-to-run
- Deterministic evals must be fast (< 100ms) — they run in every test suite
- LLM-as-judge evals cost money — run them in CI on prompt changes, not on every commit
- Gate prompt changes on eval pass rate, not just code tests
- A/B test prompt changes using the eval suite before deploying to production
- Use a cheaper/faster model as judge (Haiku, GPT-4o-mini) — quality judgment doesn't require your best model
- Eval dataset grows over time — add every production failure as a new test case
