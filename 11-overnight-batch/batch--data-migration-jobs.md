# Overnight Data Migration Jobs

## When to Use Batch Migration

- Backfilling new columns on existing rows
- Transforming data format across all records
- Cleaning/normalizing data (phone numbers, addresses, slugs)
- Generating embeddings for vector search
- Syncing data between tables

## Safe Migration Pattern

Never modify all records in a single query. Process in chunks so:
- Partial failures don't corrupt data
- Progress is resumable
- Database load is manageable
- Rollback is possible

```typescript
// scripts/backfill-invoice-slugs.ts
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

const CHUNK_SIZE = 100

function generateSlug(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
}

async function backfillSlugs() {
  let offset = 0
  let totalProcessed = 0
  let totalErrors = 0

  while (true) {
    // Fetch chunk without slug
    const { data: invoices, error } = await supabase
      .from('invoices')
      .select('id, number')
      .is('slug', null)
      .range(offset, offset + CHUNK_SIZE - 1)
      .order('id')

    if (error) {
      console.error('Fetch error:', error.message)
      break
    }

    if (!invoices || invoices.length === 0) {
      console.log('All rows processed')
      break
    }

    // Process chunk
    const updates = invoices.map(inv => ({
      id: inv.id,
      slug: generateSlug(inv.number),
    }))

    const { error: updateError } = await supabase
      .from('invoices')
      .upsert(updates, { onConflict: 'id' })

    if (updateError) {
      console.error(`Chunk error at offset ${offset}:`, updateError.message)
      totalErrors++
    } else {
      totalProcessed += invoices.length
      console.log(`Processed ${totalProcessed} rows (${invoices.length} this chunk)`)
    }

    offset += CHUNK_SIZE
    
    // Rate limit — don't hammer the DB
    await new Promise(r => setTimeout(r, 100))
  }

  console.log(`Done: ${totalProcessed} processed, ${totalErrors} chunks with errors`)
}

backfillSlugs().catch(console.error)
```

## Progress Tracking for Long Jobs

For jobs that may take hours:

```typescript
interface MigrationProgress {
  lastProcessedId: string | null
  totalProcessed: number
  errors: Array<{ id: string; error: string }>
  startedAt: string
  updatedAt: string
}

const PROGRESS_FILE = '/tmp/migration-progress.json'

function loadProgress(): MigrationProgress {
  if (existsSync(PROGRESS_FILE)) {
    return JSON.parse(readFileSync(PROGRESS_FILE, 'utf-8'))
  }
  return {
    lastProcessedId: null,
    totalProcessed: 0,
    errors: [],
    startedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }
}

function saveProgress(progress: MigrationProgress) {
  progress.updatedAt = new Date().toISOString()
  writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2))
}
```

## Dry Run Mode

Always support a dry-run flag to test without modifying data:

```typescript
const DRY_RUN = process.argv.includes('--dry-run')

if (DRY_RUN) {
  console.log('[DRY RUN] Would update:', updates)
} else {
  await supabase.from('invoices').upsert(updates)
}
```

```bash
# Test first
npx ts-node scripts/backfill-invoice-slugs.ts --dry-run

# Run for real when satisfied
npx ts-node scripts/backfill-invoice-slugs.ts
```

## Embedding Generation Job

Generating embeddings for vector search:

```typescript
// scripts/generate-embeddings.ts
import Anthropic from '@anthropic-ai/sdk'

const client = new Anthropic()

async function generateEmbedding(text: string): Promise<number[]> {
  // Anthropic doesn't have embeddings API — use Voyage AI or OpenAI
  // This is a placeholder pattern
  const response = await fetch('https://api.voyageai.com/v1/embeddings', {
    method: 'POST',
    headers: { Authorization: `Bearer ${process.env.VOYAGE_API_KEY}` },
    body: JSON.stringify({ input: text, model: 'voyage-2' }),
  })
  const data = await response.json()
  return data.data[0].embedding
}

async function backfillArticleEmbeddings() {
  const { data: articles } = await supabase
    .from('articles')
    .select('id, title, body')
    .is('embedding', null)

  for (const article of articles ?? []) {
    try {
      const text = `${article.title}\n\n${article.body}`
      const embedding = await generateEmbedding(text)
      
      await supabase
        .from('articles')
        .update({ embedding })
        .eq('id', article.id)
      
      console.log(`Embedded: ${article.title}`)
    } catch (err) {
      console.error(`Failed: ${article.title} — ${(err as Error).message}`)
    }
    
    await new Promise(r => setTimeout(r, 500))  // rate limit
  }
}
```

## Job Safety Rules

1. **Never update ALL rows in one query** — use chunked processing
2. **Always test with dry-run** before running on production
3. **Verify the WHERE clause** — `UPDATE invoices SET slug = ...` without a WHERE updates every row
4. **Keep original data** — add a new column, don't overwrite the old one until verified
5. **Test rollback** before starting — know how to undo the change
6. **Monitor during the job** — watch error rate, abort if >5% failure
