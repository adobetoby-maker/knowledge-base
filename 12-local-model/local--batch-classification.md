# Local Models: Batch Classification

## Overview

Use local models to classify large volumes of text offline — support tickets, emails, form submissions, product reviews, log messages. Local inference avoids API costs and handles data that shouldn't leave your network.

## Task Setup

Define your categories clearly and create examples for each. Ambiguous category definitions produce inconsistent classification.

```ts
interface ClassificationTask {
  id: string
  text: string
}

interface ClassificationResult {
  id: string
  category: string
  confidence: 'high' | 'medium' | 'low'
  subcategory?: string
}
```

## Prompt Design

```
System:
You are a customer support ticket classifier.

Classify each ticket into exactly one of these categories:
- billing: questions about invoices, payments, refunds, pricing
- technical: bugs, errors, feature not working, setup help
- account: login problems, password reset, account access, cancellation
- feature-request: suggestions for new features or improvements
- other: anything that doesn't fit the above

Rules:
- Output only the category name in lowercase
- Do not explain your choice
- Do not add punctuation
- If unsure between two categories, pick the more specific one

Ticket: {ticket_text}

Category:
```

The trailing "Category:" primes the model to output the answer immediately.

## Single Request

```ts
async function classifyTicket(text: string): Promise<string> {
  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1',
      prompt: buildPrompt(text),
      stream: false,
      options: {
        temperature: 0,  // Deterministic for classification
        top_p: 1,
        num_predict: 20,  // Category name is short — no need for more tokens
      },
    }),
  })

  const data = await response.json()
  return data.response.trim().toLowerCase()
}
```

## Batch Processing

```ts
import { createReadStream } from 'fs'
import readline from 'readline'

async function classifyBatch(
  inputFile: string,
  outputFile: string,
  concurrency = 5,
) {
  const results: ClassificationResult[] = []
  const queue: ClassificationTask[] = []

  // Read input CSV/JSON
  const stream = createReadStream(inputFile)
  const rl = readline.createInterface({ input: stream })

  for await (const line of rl) {
    const task = JSON.parse(line) as ClassificationTask
    queue.push(task)
  }

  console.log(`Classifying ${queue.length} items with concurrency ${concurrency}`)

  // Process in concurrent batches
  for (let i = 0; i < queue.length; i += concurrency) {
    const batch = queue.slice(i, i + concurrency)

    const batchResults = await Promise.allSettled(
      batch.map(async (task): Promise<ClassificationResult> => {
        const category = await classifyTicket(task.text)
        return {
          id: task.id,
          category,
          confidence: validateCategory(category) ? 'high' : 'low',
        }
      })
    )

    for (const [j, result] of batchResults.entries()) {
      if (result.status === 'fulfilled') {
        results.push(result.value)
      } else {
        results.push({
          id: batch[j].id,
          category: 'error',
          confidence: 'low',
        })
      }
    }

    // Progress log every 100 items
    if ((i + concurrency) % 100 === 0) {
      console.log(`Progress: ${Math.min(i + concurrency, queue.length)}/${queue.length}`)
    }
  }

  // Write output
  await writeFile(outputFile, results.map(r => JSON.stringify(r)).join('\n'))
  console.log(`Done. ${results.length} classified.`)
}
```

## Validation and Confidence

```ts
const VALID_CATEGORIES = new Set(['billing', 'technical', 'account', 'feature-request', 'other'])

function validateCategory(category: string): boolean {
  return VALID_CATEGORIES.has(category.toLowerCase().trim())
}

async function classifyWithConfidence(text: string): Promise<ClassificationResult> {
  // Run classification 3 times and check agreement
  const runs = await Promise.all([
    classifyTicket(text),
    classifyTicket(text),
    classifyTicket(text),
  ])

  const counts = runs.reduce((acc, cat) => {
    acc[cat] = (acc[cat] ?? 0) + 1
    return acc
  }, {} as Record<string, number>)

  const topCategory = Object.entries(counts).sort((a, b) => b[1] - a[1])[0]
  const votes = topCategory[1]

  return {
    id: '',
    category: topCategory[0],
    confidence: votes === 3 ? 'high' : votes === 2 ? 'medium' : 'low',
  }
}
```

Running 3 times adds cost but gives confidence signal — 3/3 agreement = high confidence, 2/3 = medium, 1/3 = low (send to human review).

## Accuracy Benchmarking

Before running production classification, benchmark against a labeled test set:

```ts
async function benchmark(testSet: Array<{ text: string; expected: string }>) {
  let correct = 0
  const confusion: Record<string, Record<string, number>> = {}

  for (const item of testSet) {
    const predicted = await classifyTicket(item.text)
    if (predicted === item.expected) correct++

    confusion[item.expected] ??= {}
    confusion[item.expected][predicted] = (confusion[item.expected][predicted] ?? 0) + 1
  }

  console.log(`Accuracy: ${(correct / testSet.length * 100).toFixed(1)}%`)
  console.log('Confusion matrix:', JSON.stringify(confusion, null, 2))
}
```

Target: >90% accuracy before deploying. Common issues:
- Categories are too similar → merge them or add examples
- Model misclassifies short texts → add minimum length filtering
- Specific topics consistently wrong → add few-shot examples for those

## Few-Shot Examples

For hard cases, add examples directly in the prompt:

```
Examples:
"My card was charged twice" → billing
"I can't log in to my account" → account  
"The PDF export button doesn't work" → technical
"It would be great if you added dark mode" → feature-request

Ticket: {ticket_text}

Category:
```

Few-shot examples dramatically improve accuracy on edge cases.
