# Skill: Automated Content Pipeline

## Overview
An automated content pipeline ingests from external sources, transforms the content for your domain, validates quality, and stores/publishes the result. The pipeline's reliability depends on idempotency (running it twice produces the same result), stage independence (each stage can fail and retry without re-running earlier stages), and observability (every stage is logged with enough context to debug failures). Ad-hoc scripts that run once are not pipelines — a pipeline is defined by repeatability and auditability.

## Implementation

### Pipeline Architecture
```
Source (URL/RSS/API) → Fetch → Parse → Clean → Enrich → Validate → Store → Publish
     ↓ fail              ↓ fail  ↓ fail   ↓ fail   ↓ fail    ↓ fail    ↓ fail
     log + skip          log + dead-letter queue, alert on >N failures
```

### Pipeline Job Record
```ts
type PipelineStatus = 'pending' | 'fetching' | 'parsing' | 'enriching' | 'validating' | 'storing' | 'done' | 'failed';

interface PipelineJob {
  id: string;
  sourceUrl: string;
  sourceType: 'rss' | 'api' | 'scrape';
  sourceHash: string;      // SHA256 of raw content for deduplication
  status: PipelineStatus;
  stage: string;
  rawContent?: string;
  parsedContent?: object;
  enrichedContent?: object;
  qualityScore?: number;
  publishedId?: string;
  error?: string;
  retryCount: number;
  createdAt: Date;
  updatedAt: Date;
}
```

### Stage 1: Fetch
```ts
async function fetchSource(sourceUrl: string): Promise<{ raw: string; hash: string }> {
  const res = await fetch(sourceUrl, {
    headers: { 'User-Agent': 'ContentBot/1.0' },
    signal: AbortSignal.timeout(30_000),
  });

  if (!res.ok) throw new Error(`HTTP ${res.status} from ${sourceUrl}`);
  const raw = await res.text();
  const hash = crypto.createHash('sha256').update(raw).digest('hex');

  return { raw, hash };
}

// Idempotency: skip if we've already processed this exact content
async function isAlreadyProcessed(hash: string): Promise<boolean> {
  const existing = await db.pipelineJobs.findOne({ where: { sourceHash: hash, status: 'done' } });
  return Boolean(existing);
}
```

### Stage 2: Parse (RSS Example)
```ts
import Parser from 'rss-parser';
const parser = new Parser();

async function parseRSS(raw: string): Promise<ParsedItem[]> {
  const feed = await parser.parseString(raw);
  return feed.items.map(item => ({
    title: item.title ?? '',
    url: item.link ?? '',
    publishedAt: item.pubDate ? new Date(item.pubDate) : new Date(),
    description: item.contentSnippet ?? item.summary ?? '',
    rawHtml: item.content ?? '',
  }));
}
```

### Stage 3: Clean
```ts
import { JSDOM } from 'jsdom';
import DOMPurify from 'isomorphic-dompurify';

function cleanContent(rawHtml: string): string {
  // Sanitize HTML
  const clean = DOMPurify.sanitize(rawHtml, {
    ALLOWED_TAGS: ['p', 'h1', 'h2', 'h3', 'ul', 'ol', 'li', 'strong', 'em', 'a'],
    ALLOWED_ATTR: ['href'],
  });

  // Extract text (strip remaining HTML for indexing)
  const dom = new JSDOM(clean);
  return dom.window.document.body.textContent?.trim() ?? '';
}
```

### Stage 4: Enrich (AI Categorization + Tags)
```ts
async function enrichContent(item: ParsedItem): Promise<EnrichedItem> {
  // Call AI to extract structured data
  const enrichment = await classifyContent(item.title, item.description);

  return {
    ...item,
    category: enrichment.category,
    tags: enrichment.tags,
    sentiment: enrichment.sentiment,
    summary: enrichment.summary,
    readingTimeMinutes: Math.ceil(item.description.split(' ').length / 200),
  };
}
```

### Stage 5: Validate + Quality Score
```ts
function qualityScore(item: EnrichedItem): number {
  let score = 0;
  if (item.title.length > 10) score += 20;
  if (item.description.length > 200) score += 30;
  if (item.url.startsWith('https://')) score += 10;
  if (item.publishedAt > new Date(Date.now() - 7 * 86400_000)) score += 20; // fresh
  if (item.tags.length >= 2) score += 20;
  return score; // max 100
}

const QUALITY_THRESHOLD = 60;
```

### Orchestrator
```ts
export async function runPipeline(sourceUrl: string) {
  const jobId = crypto.randomUUID();
  const job = await db.pipelineJobs.create({ id: jobId, sourceUrl, status: 'pending', retryCount: 0 });

  try {
    // Fetch
    await updateJobStatus(jobId, 'fetching');
    const { raw, hash } = await fetchSource(sourceUrl);
    if (await isAlreadyProcessed(hash)) {
      await updateJobStatus(jobId, 'done', { note: 'duplicate' });
      return;
    }
    await db.pipelineJobs.update({ rawContent: raw, sourceHash: hash }, { where: { id: jobId } });

    // Parse + Clean + Enrich + Validate each item
    const parsed = await parseRSS(raw);
    const results = [];

    for (const item of parsed) {
      const cleaned = { ...item, description: cleanContent(item.rawHtml) };
      const enriched = await enrichContent(cleaned);
      const score = qualityScore(enriched);

      if (score >= QUALITY_THRESHOLD) {
        const stored = await db.content.create({ ...enriched, qualityScore: score });
        results.push(stored.id);
      } else {
        await db.lowQualityContent.create({ ...enriched, qualityScore: score, rejectionReason: 'low_quality' });
      }
    }

    await updateJobStatus(jobId, 'done', { publishedCount: results.length });
  } catch (err) {
    await db.pipelineJobs.update({
      status: 'failed',
      error: (err as Error).message,
      retryCount: job.retryCount + 1,
    }, { where: { id: jobId } });

    if (job.retryCount < 3) {
      await scheduleRetry(jobId, job.retryCount + 1);
    }
  }
}
```

## Key Rules
- Deduplication by content hash prevents reprocessing the same source content on reruns.
- Each stage must be independently restartable — store intermediate state in the job record.
- Quality score gates publication — never auto-publish content below threshold; store it for review instead.
- Failed enrichment (AI API down) must not fail the whole pipeline — enrich what you can, store without enrichment if needed.
- Log every stage transition with timestamps — debugging a 2AM pipeline failure requires a complete record.
- Rate-limit external API calls during enrichment — a batch of 100 items hitting an AI API simultaneously will get throttled.
- Store `rawContent` in the pipeline job record — enables re-running the parse/enrich/validate stages without re-fetching.
