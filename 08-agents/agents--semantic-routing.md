# Agent Pattern: Semantic Routing

## Overview

Semantic routing classifies an incoming request and directs it to the appropriate handler, agent, or pipeline. Unlike keyword matching, semantic routing understands meaning — "my car won't start" and "engine not turning over" route to the same handler.

## Why Semantic Over Keyword

Keyword routing:
- "invoice" → billing handler
- "billing" → billing handler
- Misses: "payment", "charge", "receipt" without explicit keywords

Semantic routing:
- Embeds the query
- Computes cosine similarity against route embeddings
- Routes based on meaning, not literal words

## Approach A: Embedding-Based Routing

```ts
import OpenAI from 'openai'

const openai = new OpenAI()

interface Route {
  name: string
  description: string
  examples: string[]
  handler: (query: string) => Promise<string>
}

// Pre-embed route descriptions + examples at startup
async function buildRouteEmbeddings(routes: Route[]) {
  return Promise.all(
    routes.map(async (route) => {
      const text = `${route.description}\n${route.examples.join('\n')}`
      const { data } = await openai.embeddings.create({
        input: text,
        model: 'text-embedding-3-small',
      })
      return { route, embedding: data[0].embedding }
    }),
  )
}

function cosineSimilarity(a: number[], b: number[]): number {
  const dot = a.reduce((sum, ai, i) => sum + ai * b[i], 0)
  const magA = Math.sqrt(a.reduce((sum, ai) => sum + ai * ai, 0))
  const magB = Math.sqrt(b.reduce((sum, bi) => sum + bi * bi, 0))
  return dot / (magA * magB)
}

async function semanticRoute(query: string, routeEmbeddings: RouteEmbedding[]): Promise<Route> {
  const { data } = await openai.embeddings.create({
    input: query,
    model: 'text-embedding-3-small',
  })
  const queryEmbedding = data[0].embedding

  const scores = routeEmbeddings.map(({ route, embedding }) => ({
    route,
    score: cosineSimilarity(queryEmbedding, embedding),
  }))

  scores.sort((a, b) => b.score - a.score)

  const topScore = scores[0].score
  const CONFIDENCE_THRESHOLD = 0.72

  if (topScore < CONFIDENCE_THRESHOLD) {
    throw new Error(`No confident route for query (best: ${topScore.toFixed(3)})`)
  }

  return scores[0].route
}
```

## Approach B: LLM Classification

Faster to build, more flexible for complex routing logic:

```ts
interface RouterResult {
  route: string
  confidence: number
  reason: string
}

const ROUTES = {
  billing: 'Questions about invoices, payments, subscriptions, charges, refunds',
  support: 'Technical issues, bugs, how to use features, troubleshooting',
  sales: 'Pricing questions, plan comparisons, upgrade inquiries, demos',
  general: 'General information, greetings, unclear requests',
}

async function classifyQuery(query: string): Promise<RouterResult> {
  const routeDescriptions = Object.entries(ROUTES)
    .map(([name, desc]) => `- ${name}: ${desc}`)
    .join('\n')

  const response = await callModel(`
Classify this user query into exactly one category.

Categories:
${routeDescriptions}

Query: "${query}"

Respond with JSON only:
{"route": "category_name", "confidence": 0.0-1.0, "reason": "one sentence"}
`)

  const json = response.match(/\{[\s\S]*\}/)?.[0]
  return JSON.parse(json ?? '{"route": "general", "confidence": 0.5, "reason": "fallback"}')
}
```

LLM classification handles complex cases (query matches multiple categories, sarcasm, implicit intent) but adds latency. Use it when edge cases matter more than speed.

## Approach C: Semantic Router Library

```ts
import { SemanticRouter, Route } from 'semantic-router'
import { OpenAIEncoder } from 'semantic-router/encoders'

const router = new SemanticRouter({
  encoder: new OpenAIEncoder(),
  routes: [
    new Route({
      name: 'billing',
      utterances: [
        'How do I update my payment method?',
        'I was charged twice',
        'Can I get a refund?',
        'Download my invoice',
        'What plan am I on?',
      ],
    }),
    new Route({
      name: 'support',
      utterances: [
        'The button is not working',
        'I cannot log in',
        'How do I export my data?',
        'Getting an error message',
      ],
    }),
  ],
})

const result = await router.route('My subscription expired')
// → { name: 'billing', score: 0.84 }
```

`semantic-router` handles embedding caching and route management. Good for production use where you want pre-built infrastructure.

## Routing Architecture

```ts
// Main dispatcher
async function handleQuery(query: string, userId: string): Promise<string> {
  const { route, confidence } = await classifyQuery(query)

  if (confidence < 0.6) {
    return 'I\'m not sure which area of the product your question is about. Could you provide more detail?'
  }

  switch (route) {
    case 'billing': return billingAgent.handle(query, userId)
    case 'support': return supportAgent.handle(query, userId)
    case 'sales': return salesAgent.handle(query, userId)
    default: return generalAgent.handle(query, userId)
  }
}
```

Log every routing decision with the query, route selected, confidence score, and eventual user satisfaction signal. This data trains a better classifier over time.
