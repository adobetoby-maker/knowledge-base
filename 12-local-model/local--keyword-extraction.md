# Local Model: Keyword Extraction

## Overview

Keyword extraction pulls key terms and phrases from text: product descriptions for tagging, support tickets for routing, articles for indexing. Local models outperform simple TF-IDF by understanding context — "Apple" in a tech article means different things than in a recipe. Use small models (3B) with temperature 0 for consistent, fast results.

## Basic Keyword Extraction

```ts
async function extractKeywords(text: string, count = 10): Promise<string[]> {
  const response = await ollama.chat({
    model: 'llama3.2:3b',
    messages: [{
      role: 'user',
      content: `Extract the ${count} most important keywords or key phrases from this text.
Return only a JSON array of strings. No explanations.

Text: "${text.slice(0, 2000)}"`,
    }],
    format: 'json',
    options: { temperature: 0 },
  })

  try {
    const parsed = JSON.parse(response.message.content)
    return Array.isArray(parsed) ? parsed.slice(0, count) : []
  } catch {
    return []
  }
}
```

## Typed Keyword Extraction

```ts
interface ExtractedKeywords {
  topics: string[]       // Main subjects
  entities: string[]     // Named things (companies, people, places)
  actions: string[]      // Verbs/actions
  technical: string[]    // Technical terms
}

async function extractTypedKeywords(text: string): Promise<ExtractedKeywords> {
  const response = await ollama.chat({
    model: 'llama3.2:3b',
    messages: [{
      role: 'user',
      content: `Analyze this text and extract keywords by type. Return JSON only.

Text: "${text.slice(0, 2000)}"

Return: {
  "topics": ["main subject areas"],
  "entities": ["named companies/people/products"],
  "actions": ["key verbs/actions"],
  "technical": ["technical terms/jargon"]
}`,
    }],
    format: 'json',
    options: { temperature: 0 },
  })

  try {
    const parsed = JSON.parse(response.message.content)
    return {
      topics: parsed.topics ?? [],
      entities: parsed.entities ?? [],
      actions: parsed.actions ?? [],
      technical: parsed.technical ?? [],
    }
  } catch {
    return { topics: [], entities: [], actions: [], technical: [] }
  }
}
```

## SEO Keyword Extraction from Articles

```ts
async function extractSeoKeywords(title: string, body: string): Promise<{
  primaryKeyword: string
  secondaryKeywords: string[]
  lsiKeywords: string[]
}> {
  const response = await ollama.chat({
    model: 'llama3.2:7b',
    messages: [{
      role: 'user',
      content: `You are an SEO expert. Extract keywords from this article for optimization.

Title: "${title}"
Content excerpt: "${body.slice(0, 1500)}"

Return JSON:
{
  "primaryKeyword": "the single most important keyword",
  "secondaryKeywords": ["5-10 supporting keywords"],
  "lsiKeywords": ["10-15 related/semantic keywords for LSI"]
}`,
    }],
    format: 'json',
    options: { temperature: 0.1 },
  })

  try {
    return JSON.parse(response.message.content)
  } catch {
    return { primaryKeyword: '', secondaryKeywords: [], lsiKeywords: [] }
  }
}
```

## Batch Processing Articles

```ts
async function tagArticleLibrary(articles: { id: string; title: string; body: string }[]) {
  const CONCURRENCY = 2  // Limit concurrent Ollama calls
  const results: { id: string; keywords: string[] }[] = []

  for (let i = 0; i < articles.length; i += CONCURRENCY) {
    const chunk = articles.slice(i, i + CONCURRENCY)
    const chunkResults = await Promise.all(
      chunk.map(async article => ({
        id: article.id,
        keywords: await extractKeywords(`${article.title}\n\n${article.body}`, 15),
      }))
    )
    results.push(...chunkResults)
    console.log(`Processed ${Math.min(i + CONCURRENCY, articles.length)}/${articles.length}`)
  }

  return results
}
```

## Deduplication and Normalization

```ts
function normalizeKeywords(keywords: string[]): string[] {
  return [...new Set(
    keywords
      .map(k => k.toLowerCase().trim())
      .filter(k => k.length > 2 && k.length < 50)
      .filter(k => !STOP_WORDS.has(k))
  )]
}

const STOP_WORDS = new Set(['the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'been', 'from', 'has', 'had', 'have', 'that', 'was', 'were', 'will', 'with'])
```

## Storing Extracted Keywords

```sql
CREATE TABLE article_keywords (
  article_id  uuid NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  keyword     text NOT NULL,
  weight      float NOT NULL DEFAULT 1.0,
  source      text DEFAULT 'model',   -- 'model', 'manual', 'tfidf'
  PRIMARY KEY (article_id, keyword)
);

CREATE INDEX article_keywords_keyword_idx ON article_keywords(keyword);
```

```ts
// Upsert keywords (re-extraction replaces old)
async function saveKeywords(articleId: string, keywords: string[]) {
  await db.delete(articleKeywords).where(
    and(eq(articleKeywords.articleId, articleId), eq(articleKeywords.source, 'model'))
  )
  await db.insert(articleKeywords).values(
    keywords.map((keyword, i) => ({
      articleId,
      keyword,
      weight: 1 - (i / keywords.length),  // Earlier = higher weight
      source: 'model',
    }))
  )
}
```

## Key Rules

- Temperature 0 for keyword extraction — you want consistent, deterministic results on re-runs.
- 3B models are sufficient for keyword extraction — faster and cheaper than 7B for this task.
- Post-process: lowercase, deduplicate, filter stop words — models include stop words and inconsistent casing.
- Store keywords in a separate table with a `source` column — allows combining model-extracted and manually-added keywords.
- For SEO use, pair with search volume data (Ahrefs/SEMrush API) — extracted keywords need volume validation to be actionable.
