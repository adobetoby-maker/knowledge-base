# Local Model: Text Summarization

## Overview

Summarize documents, emails, support tickets, meeting notes, and articles using local models. Summarization tasks tolerate higher temperature (0.3-0.5) than classification but should still be constrained. Key considerations: chunk long documents before summarizing, define the output format explicitly, and validate summary length.

## Basic Summarization

```ts
async function summarize(text: string, maxSentences = 3): Promise<string> {
  const prompt = `Summarize the following text in ${maxSentences} sentences or fewer.
Write in third person. Be factual and concise. Don't add information not in the text.

Text:
${text.slice(0, 4000)}

Summary:`

  const res = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1:8b',
      prompt,
      stream: false,
      options: {
        temperature: 0.3,
        num_predict: 300,
        stop: ['\n\n', '---'],
      },
    }),
  })

  return (await res.json()).response.trim()
}
```

## Structured Summary

For support tickets, extract key fields:

```ts
interface TicketSummary {
  problem: string
  impact: string
  priority: 'low' | 'medium' | 'high'
  suggestedAction: string
}

async function summarizeTicket(ticketBody: string): Promise<TicketSummary> {
  const prompt = `Analyze this support ticket and extract key information.

Ticket:
${ticketBody.slice(0, 2000)}

Respond with JSON only:
{
  "problem": "one sentence describing the issue",
  "impact": "who is affected and how",
  "priority": "low" | "medium" | "high",
  "suggestedAction": "recommended next step"
}`

  const res = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1:8b',
      prompt,
      stream: false,
      options: { temperature: 0, num_predict: 200 },
    }),
  })

  const output = (await res.json()).response
  try {
    return JSON.parse(output.slice(output.indexOf('{')))
  } catch {
    return {
      problem: 'Unable to parse',
      impact: 'Unknown',
      priority: 'medium',
      suggestedAction: 'Manual review required',
    }
  }
}
```

## Chunked Summarization for Long Documents

Documents longer than the model's context window (typically 4K-8K tokens) require chunking:

```ts
function chunkText(text: string, maxChunkChars = 3000, overlapChars = 200): string[] {
  const chunks: string[] = []
  let start = 0

  while (start < text.length) {
    const end = Math.min(start + maxChunkChars, text.length)
    // Try to break at sentence boundary
    const chunk = text.slice(start, end)
    const lastSentence = chunk.lastIndexOf('. ')
    const breakPoint = lastSentence > maxChunkChars * 0.7 ? lastSentence + 1 : chunk.length

    chunks.push(text.slice(start, start + breakPoint))
    start += breakPoint - overlapChars
  }

  return chunks
}

async function summarizeLongDocument(text: string): Promise<string> {
  const chunks = chunkText(text)

  if (chunks.length === 1) return summarize(text)

  // Summarize each chunk
  const chunkSummaries = await Promise.all(chunks.map(chunk => summarize(chunk, 2)))

  // Summarize the summaries
  const combined = chunkSummaries.join('\n\n')
  return summarize(combined, 5)
}
```

## Email Thread Summarization

```ts
interface EmailMessage {
  from: string
  date: string
  body: string
}

async function summarizeEmailThread(messages: EmailMessage[]): Promise<string> {
  const formatted = messages
    .map(m => `From: ${m.from}\nDate: ${m.date}\n${m.body}`)
    .join('\n---\n')

  const prompt = `Summarize this email thread briefly.
Include: what was decided, what action items remain, key points of disagreement if any.
Max 100 words.

Thread:
${formatted.slice(0, 5000)}

Summary:`

  const res = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1:8b',
      prompt,
      stream: false,
      options: { temperature: 0.3, num_predict: 200 },
    }),
  })

  return (await res.json()).response.trim()
}
```

## Bullet Point Summary

```ts
async function bulletSummary(text: string, bulletCount = 5): Promise<string[]> {
  const prompt = `Extract the ${bulletCount} most important points from this text.
Format as a bulleted list with each point on its own line starting with "- ".
Be specific. No vague statements.

Text:
${text.slice(0, 3000)}

Key points:`

  const res = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1:8b',
      prompt,
      stream: false,
      options: { temperature: 0.2, num_predict: 400 },
    }),
  })

  const output = (await res.json()).response
  return output
    .split('\n')
    .filter((line: string) => line.trim().startsWith('-') || line.trim().startsWith('•'))
    .map((line: string) => line.replace(/^[-•]\s*/, '').trim())
    .filter(Boolean)
    .slice(0, bulletCount)
}
```

## Key Rules

- Define output format precisely — "one sentence", "100 words max", "JSON object" — vague prompts produce inconsistent lengths.
- Chunk at ~3000 chars with 200-char overlap to preserve context at boundaries.
- Temperature 0.2-0.4 for summaries — enough variation to produce natural prose, low enough to stay factual.
- Always validate summary is shorter than the input — a model that expands the text is hallucinating.
- Instruct the model explicitly not to add information: "Don't include anything not stated in the text."
