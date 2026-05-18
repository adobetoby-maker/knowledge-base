# Local Models: Summarization Pipeline

## Overview

Use local models to summarize large volumes of text: customer feedback, support tickets, articles, meeting transcripts, research papers. Key challenge: most documents exceed the context window — requires chunking strategy.

## Single Document Summarization

For documents that fit within context (< ~6,000 words for 8K context models):

```ts
const SUMMARIZE_PROMPT = `Summarize the following text in {target_length} words or fewer.

Requirements:
- Preserve the most important points
- Use clear, direct language
- Do not add information not in the source text
- Do not express opinions

Text:
---
{text}
---

Summary:
`

async function summarize(
  text: string,
  targetWords: number = 150,
): Promise<string> {
  const prompt = SUMMARIZE_PROMPT
    .replace('{target_length}', targetWords.toString())
    .replace('{text}', text)

  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    body: JSON.stringify({
      model: 'llama3.1',
      prompt,
      stream: false,
      options: {
        temperature: 0.3,
        num_predict: targetWords * 2,  // Allow 2x tokens for the summary
      },
    }),
  })

  const data = await response.json()
  return data.response.trim()
}
```

## Chunked Summarization (Map-Reduce)

For documents longer than the context window:

```ts
function chunkText(text: string, maxWords: number = 2000): string[] {
  const words = text.split(/\s+/)
  const chunks: string[] = []

  for (let i = 0; i < words.length; i += maxWords) {
    // Overlap by 100 words to preserve context across chunk boundaries
    const start = Math.max(0, i - 100)
    const chunk = words.slice(start, i + maxWords).join(' ')
    chunks.push(chunk)
  }

  return chunks
}

async function summarizeLongDocument(text: string): Promise<string> {
  const wordCount = text.split(/\s+/).length

  // Short enough to summarize directly
  if (wordCount < 2000) return summarize(text, 200)

  // Map: summarize each chunk
  const chunks = chunkText(text, 2000)
  console.log(`Document has ${wordCount} words — processing ${chunks.length} chunks`)

  const chunkSummaries = await Promise.all(
    chunks.map(chunk => summarize(chunk, 100))
  )

  // Reduce: combine chunk summaries into final summary
  const combined = chunkSummaries.join('\n\n')

  if (combined.split(/\s+/).length < 2000) {
    // Combined summaries fit in context — final pass
    return summarize(combined, 300)
  }

  // Recursive reduction for very long documents
  return summarizeLongDocument(combined)
}
```

## Structured Summarization

For extracting specific information (meeting notes, support escalations):

```ts
const STRUCTURED_PROMPT = `Extract the following from the text below.
Return valid JSON only:

{
  "main_topic": "one sentence describing what this is about",
  "key_points": ["point 1", "point 2", "point 3"],
  "action_items": ["action 1", "action 2"],
  "sentiment": "positive" | "neutral" | "negative",
  "urgency": "high" | "medium" | "low"
}

Text:
---
{text}
---

JSON:
`

async function extractStructured(text: string) {
  const response = await ollama.generate({
    model: 'llama3.1',
    prompt: STRUCTURED_PROMPT.replace('{text}', text),
    options: { temperature: 0 },
  })

  try {
    return JSON.parse(response.response.trim())
  } catch {
    // Try to extract JSON from surrounding text
    const match = response.response.match(/\{[\s\S]*\}/)
    if (match) return JSON.parse(match[0])
    throw new Error('Model did not return valid JSON')
  }
}
```

## Batch Processing Pipeline

```ts
import { createWriteStream } from 'fs'

async function processBatch(
  inputDir: string,
  outputFile: string,
) {
  const files = await readdir(inputDir).then(f =>
    f.filter(name => name.endsWith('.txt') || name.endsWith('.md'))
  )

  const out = createWriteStream(outputFile)
  let processed = 0

  for (const filename of files) {
    const text = await readFile(join(inputDir, filename), 'utf8')

    try {
      const summary = await summarizeLongDocument(text)
      const result = {
        filename,
        wordCount: text.split(/\s+/).length,
        summaryWordCount: summary.split(/\s+/).length,
        summary,
        processedAt: new Date().toISOString(),
      }
      out.write(JSON.stringify(result) + '\n')
      processed++
      console.log(`[${processed}/${files.length}] ${filename}`)
    } catch (err) {
      console.error(`Failed to process ${filename}:`, err)
      out.write(JSON.stringify({ filename, error: String(err) }) + '\n')
    }
  }

  out.close()
  console.log(`Processed ${processed}/${files.length} documents`)
}
```

## Quality Checks

Detect when a summary may be poor quality:

```ts
function validateSummary(original: string, summary: string): {
  valid: boolean
  issues: string[]
} {
  const issues: string[] = []

  const originalWords = original.split(/\s+/).length
  const summaryWords = summary.split(/\s+/).length

  // Summary should be shorter than original
  if (summaryWords > originalWords) {
    issues.push('Summary is longer than original')
  }

  // Summary shouldn't be too short (likely truncated)
  if (summaryWords < 20) {
    issues.push('Summary is suspiciously short')
  }

  // Detect hallucination signals (model refused or expressed confusion)
  const refusalPhrases = ["I'm sorry", "I cannot", "As an AI", "I don't have"]
  if (refusalPhrases.some(p => summary.includes(p))) {
    issues.push('Summary may contain model refusal')
  }

  return { valid: issues.length === 0, issues }
}
```

Flag summaries with quality issues for human review rather than silently using bad output.
