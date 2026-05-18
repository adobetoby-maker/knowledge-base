# Local Model: Fine-Tuning Dataset Preparation

## Overview
Fine-tuning a local model on task-specific data can dramatically improve performance on your exact use case. The quality of the training data matters far more than quantity—1,000 clean, well-structured examples outperform 10,000 noisy ones. The most common failure modes are: contaminated eval sets (train and test data overlapping), PII in training data, inconsistent instruction format, and not having enough examples per task variant.

## Instruction-Tuning Format (Chat Template)

```jsonl
// Each line is a JSON object (JSONL format — one example per line)
{"messages": [
  {"role": "system", "content": "You extract structured data from invoice text."},
  {"role": "user", "content": "Invoice from Acme Corp. Amount: $1,250.00. Due: 2026-06-15. PO#: 44821"},
  {"role": "assistant", "content": "{\"vendor\": \"Acme Corp\", \"amount\": 1250.00, \"due_date\": \"2026-06-15\", \"po_number\": \"44821\"}"}
]}
{"messages": [
  {"role": "system", "content": "You extract structured data from invoice text."},
  {"role": "user", "content": "Bill from TechSupply Inc - $345 - NET30 - Invoice 9921"},
  {"role": "assistant", "content": "{\"vendor\": \"TechSupply Inc\", \"amount\": 345.00, \"due_date\": null, \"po_number\": \"9921\"}"}
]}
```

## Dataset Size Guidelines

```
Minimum for basic task adaptation:
  Classification (few classes):         300–500 examples
  Named entity extraction:              500–1,000 examples
  Structured output (JSON):             500–1,500 examples
  Style/tone transfer:                  200–500 examples
  Domain-specific Q&A:                  1,000–3,000 examples

More complex tasks (multi-step reasoning, code generation):
  1,000–5,000 minimum; quality matters more than hitting a number

Signs you need more data:
  - Model confuses class boundaries → more examples near the boundary
  - High variance between runs → need more examples overall
  - Poor recall on rare classes → oversample the minority class
```

## Data Cleaning Pipeline

```ts
import { z } from 'zod';

const ExampleSchema = z.object({
  messages: z.array(z.object({
    role: z.enum(['system', 'user', 'assistant']),
    content: z.string().min(1).max(8000),
  })).min(2),
});

async function cleanDataset(rawExamples: unknown[]): Promise<string[]> {
  const cleaned: string[] = [];
  const skipped = { invalid: 0, tooLong: 0, pii: 0, duplicate: 0 };

  const seen = new Set<string>();

  for (const example of rawExamples) {
    // 1. Schema validation
    const parsed = ExampleSchema.safeParse(example);
    if (!parsed.success) { skipped.invalid++; continue; }

    const messages = parsed.data.messages;
    const fullText = messages.map(m => m.content).join(' ');

    // 2. Length check (avoid examples that exceed model context)
    if (fullText.length > 12000) { skipped.tooLong++; continue; }

    // 3. PII detection (basic patterns — extend for your domain)
    if (containsPII(fullText)) { skipped.pii++; continue; }

    // 4. Deduplication (exact match on user + assistant turn)
    const key = messages[1].content + messages[messages.length - 1].content;
    if (seen.has(key)) { skipped.duplicate++; continue; }
    seen.add(key);

    cleaned.push(JSON.stringify(parsed.data));
  }

  console.log('Skipped:', skipped, 'Kept:', cleaned.length);
  return cleaned;
}

function containsPII(text: string): boolean {
  return (
    /\b\d{3}-\d{2}-\d{4}\b/.test(text) ||     // SSN
    /\b4[0-9]{12}(?:[0-9]{3})?\b/.test(text) || // Visa card
    /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i.test(text) // email (context-dependent)
  );
}
```

## Train / Eval Split

```ts
function splitDataset(examples: string[], evalRatio = 0.1, seed = 42) {
  // Shuffle deterministically
  const shuffled = [...examples].sort(() => {
    seed = (seed * 1664525 + 1013904223) & 0xffffffff;
    return (seed & 1) ? 1 : -1;
  });

  const evalSize = Math.floor(shuffled.length * evalRatio);
  return {
    train: shuffled.slice(evalSize),
    eval: shuffled.slice(0, evalSize),
  };
}

// CRITICAL: Verify no contamination
function checkContamination(train: string[], eval_: string[]) {
  const trainKeys = new Set(train.map(e => JSON.parse(e).messages[1].content));
  const leaked = eval_.filter(e => trainKeys.has(JSON.parse(e).messages[1].content));
  if (leaked.length > 0) {
    throw new Error(`Data contamination: ${leaked.length} eval examples found in train set`);
  }
}
```

## LoRA vs Full Fine-Tune Decision

```
Full Fine-Tune:
  ✓ Maximum task performance
  ✗ Requires large GPU cluster (70B+ model = 8x A100)
  ✗ Risk of catastrophic forgetting (loses general capabilities)
  ✗ New base model version = repeat entire process
  Use when: you have the hardware and need maximum specialized performance

LoRA (Low-Rank Adaptation):
  ✓ 10–100x less VRAM (7B model on a single 24GB GPU)
  ✓ Merges into base model at inference (no latency overhead)
  ✓ Can swap multiple LoRA adapters for different tasks
  ✓ Less catastrophic forgetting
  ✗ Slightly lower ceiling than full fine-tune
  Use when: consumer hardware, production systems, multiple tasks

QLoRA (Quantized LoRA):
  ✓ Fine-tune 7B on 8GB VRAM, 13B on 12GB VRAM
  ✓ 4-bit quantization during training
  ✗ Slower training than LoRA
  Use when: very limited VRAM, local workstation fine-tuning
```

## Key Rules
- **Eval set must be unseen data** — split before any data augmentation; check for contamination explicitly.
- **Remove PII before training** — model will memorize and regurgitate names, emails, SSNs.
- **Consistent format is critical** — mixed instruction formats degrade model performance more than mixed quality.
- **1,000 examples minimum for any real task** — fewer examples leads to brittle, high-variance models.
- **LoRA for most cases** — full fine-tuning requires specialized infrastructure; LoRA runs on a single GPU.
- **Oversample rare classes** — if a label appears in 2% of examples, the model will rarely predict it; duplicate or synthesize more examples.
- **Store train/eval in separate files** — prevents accidental contamination when re-running data processing scripts.
