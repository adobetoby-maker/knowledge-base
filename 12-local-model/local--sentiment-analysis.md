# Local Models: Sentiment Analysis

## Overview

Classify text as positive/negative/neutral or on a scale, and extract the aspect/reason for the sentiment. Common uses: customer feedback analysis, review scoring, support ticket triage, social media monitoring. Local models work well for simple sentiment; for aspect-level or nuanced analysis, larger models or fine-tuned models perform better.

## Simple Sentiment Classification

```ts
const SENTIMENT_PROMPT = `Classify the sentiment of the following text.

Respond with ONLY one of: positive, negative, neutral

Do not explain. Do not add punctuation. Just the label.

Text: {text}

Sentiment:`

async function classifySentiment(text: string): Promise<'positive' | 'negative' | 'neutral'> {
  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1',
      prompt: SENTIMENT_PROMPT.replace('{text}', text),
      stream: false,
      options: {
        temperature: 0,
        num_predict: 5,  // Short response — just the label
      },
    }),
  })

  const data = await response.json()
  const label = data.response.trim().toLowerCase()

  if (['positive', 'negative', 'neutral'].includes(label)) {
    return label as 'positive' | 'negative' | 'neutral'
  }

  // Fallback if model adds extra text
  if (label.includes('positive')) return 'positive'
  if (label.includes('negative')) return 'negative'
  return 'neutral'
}
```

## Structured Sentiment with Aspect and Score

```ts
const DETAILED_SENTIMENT_PROMPT = `Analyze the sentiment of this customer feedback.
Return JSON only:

{
  "overall": "positive" | "negative" | "neutral",
  "score": 1-5,
  "aspects": [
    { "aspect": "what they commented on", "sentiment": "positive|negative|neutral" }
  ],
  "summary": "one sentence summarizing the feedback"
}

Text: {text}

JSON:`

interface SentimentResult {
  overall: 'positive' | 'negative' | 'neutral'
  score: number  // 1-5
  aspects: Array<{ aspect: string; sentiment: string }>
  summary: string
}

async function analyzeSentiment(text: string): Promise<SentimentResult> {
  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1',
      prompt: DETAILED_SENTIMENT_PROMPT.replace('{text}', text),
      stream: false,
      options: { temperature: 0, num_predict: 512 },
    }),
  })

  const data = await response.json()
  const match = data.response.match(/\{[\s\S]*\}/)
  if (!match) throw new Error('No JSON in response')

  const parsed = JSON.parse(match[0])
  return {
    overall: parsed.overall ?? 'neutral',
    score: Math.min(5, Math.max(1, parseInt(parsed.score) || 3)),
    aspects: Array.isArray(parsed.aspects) ? parsed.aspects : [],
    summary: typeof parsed.summary === 'string' ? parsed.summary : '',
  }
}
```

## Batch Review Analysis

```ts
interface Review {
  id: string
  text: string
  product: string
}

async function analyzeReviews(reviews: Review[]) {
  const results = []

  for (const review of reviews) {
    const sentiment = await analyzeSentiment(review.text)
    results.push({
      reviewId: review.id,
      product: review.product,
      ...sentiment,
    })
  }

  // Aggregate
  const byProduct = new Map<string, typeof results>()
  for (const r of results) {
    const group = byProduct.get(r.product) ?? []
    group.push(r)
    byProduct.set(r.product, group)
  }

  const summary = [...byProduct.entries()].map(([product, reviews]) => ({
    product,
    avgScore: reviews.reduce((s, r) => s + r.score, 0) / reviews.length,
    positive: reviews.filter(r => r.overall === 'positive').length,
    negative: reviews.filter(r => r.overall === 'negative').length,
    neutral: reviews.filter(r => r.overall === 'neutral').length,
  }))

  return { results, summary }
}
```

## Score Calibration

Raw model scores can be miscalibrated. Run a sample against labeled data first:

```ts
async function calibrateModel(labeled: Array<{ text: string; trueLabel: string }>) {
  const predictions = await Promise.all(labeled.map(l => classifySentiment(l.text)))

  const correct = predictions.filter((pred, i) => pred === labeled[i].trueLabel).length
  const accuracy = (correct / labeled.length) * 100

  console.log(`Accuracy: ${accuracy.toFixed(1)}%`)
  // 75%+ acceptable for general sentiment
  // 85%+ needed for production routing/alerting
}
```

## Key Rules

- For simple positive/negative/neutral, `num_predict: 5` is sufficient — prevents model from generating a long explanation.
- Score normalization: models are inconsistent on 1-10 scales; 1-5 is more reliable.
- Batch with concurrency 3-5 — sentiment analysis is fast per call but high concurrency doesn't help much and adds load.
- Calibrate against labeled samples for your specific domain before using for business decisions.
