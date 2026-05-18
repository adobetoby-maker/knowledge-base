# Local Model: Document Classification

## Overview

Classify documents, emails, tickets, or messages into predefined categories. Use local models for: support ticket routing, document filing, content tagging, intent detection. At temperature 0 with a constrained prompt, local models reliably output single-label classifications from a known set.

## Single-Label Classification

Force output to a specific set of labels:

```ts
const TICKET_CATEGORIES = ['billing', 'technical', 'account', 'feature-request', 'general'] as const
type TicketCategory = typeof TICKET_CATEGORIES[number]

async function classifyTicket(body: string): Promise<TicketCategory> {
  const prompt = `Classify this customer support ticket into exactly one category.

Categories: ${TICKET_CATEGORIES.join(', ')}

Rules:
- billing: payment, invoice, refund, subscription, pricing
- technical: bug, error, not working, broken, crash
- account: login, password, access, permissions, profile
- feature-request: suggestion, would be nice, please add, can you add
- general: everything else

Ticket: "${body.slice(0, 500)}"

Respond with only the category name. No explanation.`

  const res = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.2:3b',  // Small model is sufficient for classification
      prompt,
      stream: false,
      options: {
        temperature: 0,
        num_predict: 10,  // Short output — just one word
        stop: ['\n', '.', ' '],
      },
    }),
  })

  const output = (await res.json()).response.trim().toLowerCase() as string

  // Validate output is a known category
  if (TICKET_CATEGORIES.includes(output as TicketCategory)) {
    return output as TicketCategory
  }

  // Fuzzy match if model adds extra chars
  const match = TICKET_CATEGORIES.find(c => output.includes(c) || c.includes(output))
  return match ?? 'general'
}
```

## Multi-Label Classification

```ts
const CONTENT_TAGS = ['javascript', 'typescript', 'react', 'nextjs', 'database', 'security', 'performance', 'devops']

async function tagArticle(title: string, body: string): Promise<string[]> {
  const prompt = `Tag this article with relevant topics from this list: ${CONTENT_TAGS.join(', ')}

Apply 1-4 tags. Output a JSON array of tag names only.

Article title: "${title}"
Article excerpt: "${body.slice(0, 600)}"

Output format: ["tag1", "tag2"]
Only include tags from the provided list.`

  const res = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'qwen2.5:7b',
      prompt,
      stream: false,
      options: {
        temperature: 0,
        num_predict: 100,
        stop: [']'],
      },
    }),
  })

  const raw = (await res.json()).response + ']'
  try {
    const tags = JSON.parse(raw.slice(raw.indexOf('[')))
    return tags.filter((t: string) => CONTENT_TAGS.includes(t))
  } catch {
    // Parse failure — extract tags manually
    return CONTENT_TAGS.filter(tag => raw.toLowerCase().includes(tag))
  }
}
```

## Intent Classification (Routing)

```ts
const INTENTS = {
  search: 'user wants to find something',
  purchase: 'user wants to buy or subscribe',
  support: 'user has a problem or question about existing usage',
  navigate: 'user wants to go to a specific section',
  compare: 'user wants to compare options',
} as const

type Intent = keyof typeof INTENTS

async function classifyIntent(userMessage: string): Promise<{ intent: Intent; confidence: 'high' | 'low' }> {
  const intentDescriptions = Object.entries(INTENTS)
    .map(([k, v]) => `${k}: ${v}`)
    .join('\n')

  const prompt = `Classify the user's intent.

Intents:
${intentDescriptions}

User message: "${userMessage}"

Respond with JSON: {"intent": "...", "confidence": "high" or "low"}
Only one of these intents: ${Object.keys(INTENTS).join(', ')}`

  const res = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.2:3b',
      prompt,
      stream: false,
      options: { temperature: 0, num_predict: 50 },
    }),
  })

  const output = (await res.json()).response
  try {
    const json = JSON.parse(output.slice(output.indexOf('{')))
    const intent = json.intent as Intent
    if (!Object.keys(INTENTS).includes(intent)) throw new Error('Invalid intent')
    return { intent, confidence: json.confidence ?? 'low' }
  } catch {
    return { intent: 'search', confidence: 'low' }  // Safe default
  }
}
```

## Batch Classification

```ts
async function classifyBatch(items: { id: string; text: string }[]): Promise<Map<string, string>> {
  const results = new Map<string, string>()

  // Process in small batches to avoid overwhelming the model
  for (const item of items) {
    const category = await classifyTicket(item.text)
    results.set(item.id, category)

    // Small delay between requests for single-GPU systems
    await new Promise(r => setTimeout(r, 50))
  }

  return results
}
```

## Calibration

Before deploying, validate against a labeled sample:

```ts
async function calibrate(samples: { text: string; expected: TicketCategory }[]) {
  let correct = 0

  for (const sample of samples) {
    const predicted = await classifyTicket(sample.text)
    if (predicted === sample.expected) correct++
    else {
      console.log(`Expected: ${sample.expected}, Got: ${predicted}`)
      console.log(`Text: ${sample.text.slice(0, 100)}`)
    }
  }

  console.log(`Accuracy: ${(correct / samples.length * 100).toFixed(1)}%`)
}
```

## Key Rules

- Temperature 0 is essential — classification should be deterministic, not creative.
- Small models (3B-7B) are sufficient for classification — don't waste a 70B model on label assignment.
- Always validate output against the known label set — models sometimes output near-matches or extra words.
- `num_predict: 10-20` for single-label classification — short output forces the model to commit quickly.
- Calibrate against 50-100 labeled examples before deploying — know your accuracy before trusting the output.
