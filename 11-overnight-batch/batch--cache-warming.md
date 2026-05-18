# Batch: Cache Warming

## Overview

Cache warming pre-populates cache with data that will be needed on first request, preventing cold-start latency spikes after deploys, Redis restarts, or cache expirations. Run before traffic resumes, not after.

## When Cache Warming Matters

- After deploy: new server processes have empty in-memory caches
- After Redis restart/flush: all cached data gone
- After database migration: new data shape not in old cached format
- ISR (Next.js): pages not regenerated until first request

Without warming, the first users after a deploy experience slow responses while caches rebuild.

## What to Warm

Prioritize by: access frequency × cost-to-compute

```
High priority (warm first):
  - Homepage and landing pages (high traffic, high cost if uncached)
  - Popular product/listing pages
  - Navigation data (menus, categories)
  - User-agnostic configuration

Medium priority:
  - Top 100 most-visited articles/posts
  - Price lists, inventory summaries

Low priority (let warm naturally):
  - Long-tail pages with low traffic
  - User-specific data (can't pre-warm anyway)
```

## Redis Cache Warming Script

```ts
// scripts/warm-cache.ts
import { getRedis } from '../lib/redis'
import { getDb } from '../lib/db'

async function warmCache() {
  const redis = getRedis()
  const db = getDb()
  const start = Date.now()
  let warmed = 0

  console.log('Starting cache warming...')

  // 1. Navigation / site config
  const config = await db.query.siteConfig.findFirst()
  if (config) {
    await redis.set('site:config', JSON.stringify(config), 'EX', 3600)
    warmed++
  }

  // 2. Top articles
  const articles = await db.query.articles.findMany({
    where: eq(articles.published, true),
    orderBy: desc(articles.views),
    limit: 50,
  })
  for (const article of articles) {
    await redis.set(`article:${article.slug}`, JSON.stringify(article), 'EX', 3600)
    warmed++
  }

  // 3. Category lists
  const categories = await db.query.categories.findMany()
  await redis.set('categories:all', JSON.stringify(categories), 'EX', 3600)
  warmed++

  // 4. Active service listings
  const services = await db.query.services.findMany({
    where: eq(services.active, true),
  })
  await redis.set('services:active', JSON.stringify(services), 'EX', 3600)
  warmed++

  const duration = Date.now() - start
  console.log(`Cache warming complete: ${warmed} keys in ${duration}ms`)
}

warmCache().catch(console.error).finally(() => process.exit(0))
```

## Next.js ISR Warming

After deploy, trigger revalidation for critical pages:

```ts
// scripts/warm-isr.ts

const CRITICAL_PAGES = [
  '/',
  '/services',
  '/about',
  '/contact',
  '/blog',
]

const BASE_URL = process.env.NEXT_PUBLIC_APP_URL!
const REVALIDATION_SECRET = process.env.REVALIDATION_SECRET!

async function warmISR() {
  console.log('Warming ISR cache...')
  
  for (const path of CRITICAL_PAGES) {
    try {
      const res = await fetch(
        `${BASE_URL}/api/revalidate?path=${path}&secret=${REVALIDATION_SECRET}`,
        { method: 'POST' }
      )
      
      if (res.ok) {
        console.log(`✓ Revalidated ${path}`)
      } else {
        console.error(`✗ Failed to revalidate ${path}: ${res.status}`)
      }
      
      // Small delay to avoid overwhelming the origin
      await new Promise(resolve => setTimeout(resolve, 200))
    } catch (err) {
      console.error(`Error revalidating ${path}:`, err)
    }
  }
}
```

```ts
// app/api/revalidate/route.ts
import { revalidatePath } from 'next/cache'

export async function POST(req: Request) {
  const { searchParams } = new URL(req.url)
  const secret = searchParams.get('secret')
  const path = searchParams.get('path')

  if (secret !== process.env.REVALIDATION_SECRET) {
    return Response.json({ error: 'Invalid secret' }, { status: 401 })
  }

  if (!path) {
    return Response.json({ error: 'Path required' }, { status: 400 })
  }

  revalidatePath(path)
  return Response.json({ revalidated: true, path })
}
```

## Integrating with Deploy Pipeline

In CI/CD (GitHub Actions):

```yaml
# After deploy completes
- name: Warm cache
  run: |
    npx ts-node scripts/warm-cache.ts
    npx ts-node scripts/warm-isr.ts
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}
    REDIS_URL: ${{ secrets.REDIS_URL }}
    NEXT_PUBLIC_APP_URL: ${{ secrets.APP_URL }}
    REVALIDATION_SECRET: ${{ secrets.REVALIDATION_SECRET }}
```

## Cache Warming vs Cold Start

Cache warming is different from infrastructure warm-up:
- **Cache warming**: pre-fill Redis/KV with data
- **Cold start**: process initialization (Node.js module loading)

For cold starts on serverless: use `keepAlive` on functions, or pre-warm by hitting the endpoint in deploy pipeline. These are separate concerns.

## Monitoring Cache Hit Rate

Track cache effectiveness:

```ts
async function getCachedWithMetrics<T>(key: string, ttl: number, fetch: () => Promise<T>): Promise<T> {
  const cached = await redis.get(key)
  
  if (cached) {
    metrics.increment('cache.hit', { key_prefix: key.split(':')[0] })
    return JSON.parse(cached)
  }
  
  metrics.increment('cache.miss', { key_prefix: key.split(':')[0] })
  const fresh = await fetch()
  await redis.set(key, JSON.stringify(fresh), 'EX', ttl)
  return fresh
}
```

Target: >90% hit rate for frequently accessed keys after warmup. Alert if hit rate drops below 70% — indicates cache churn or TTL misconfiguration.
