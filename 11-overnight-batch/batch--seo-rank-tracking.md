# Batch: SEO Search Rank Tracking

## Overview
Search ranking visibility is a lagging indicator — changes in ranking signal content quality,
technical SEO issues, or algorithmic shifts. Daily tracking with a persistent time series enables
detection of ranking drops before they significantly impact traffic, and attribution of ranking
changes to specific content or technical changes deployed around the same time.

## Implementation

### Daily Rank Query via SERP API
```ts
import { DataForSEO } from 'dataforseo-client';  // or serpapi, valueserp

const client = new DataForSEO({
  login: process.env.DATAFORSEO_LOGIN,
  password: process.env.DATAFORSEO_PASSWORD,
});

async function queryRankings(keywords: string[], domain: string): Promise<RankResult[]> {
  const results: RankResult[] = [];

  // Batch keywords to minimize API calls (most SERP APIs support batch)
  const tasks = keywords.map(keyword => ({
    keyword,
    location_code: 2840,     // US
    language_code: 'en',
    device: 'desktop',
    os: 'windows',
    depth: 100,              // scan top 100 results
  }));

  const response = await client.serp.google.organic.taskPost(tasks);

  for (const taskId of response.tasks.map(t => t.id)) {
    const result = await client.serp.google.organic.taskGetAdvanced(taskId);

    for (const item of result.tasks[0].result[0].items ?? []) {
      if (item.url?.includes(domain)) {
        results.push({
          keyword: result.tasks[0].data.keyword,
          position: item.rank_absolute,
          url: item.url,
          isFeaturedSnippet: item.type === 'featured_snippet',
          date: new Date(),
        });
        break;  // only record highest-ranking URL for this domain
      }
    }

    // Not in top 100
    if (!results.find(r => r.keyword === result.tasks[0].data.keyword)) {
      results.push({
        keyword: result.tasks[0].data.keyword,
        position: null,  // not ranked in top 100
        url: null,
        isFeaturedSnippet: false,
        date: new Date(),
      });
    }
  }

  return results;
}
```

### Time-Series Storage
```sql
CREATE TABLE rank_tracking (
    id          BIGSERIAL PRIMARY KEY,
    keyword     TEXT NOT NULL,
    position    SMALLINT,          -- NULL = not in top 100
    url         TEXT,
    is_featured_snippet BOOLEAN DEFAULT false,
    tracked_at  DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE UNIQUE INDEX idx_rank_tracking_daily
    ON rank_tracking (keyword, tracked_at);

CREATE INDEX idx_rank_tracking_keyword
    ON rank_tracking (keyword, tracked_at DESC);
```

### Detect Ranking Drops > 5 Positions
```sql
-- Drops from yesterday to today
SELECT
    today.keyword,
    yesterday.position AS previous_position,
    today.position AS current_position,
    (today.position - yesterday.position) AS position_change,
    today.url
FROM rank_tracking today
JOIN rank_tracking yesterday
    ON yesterday.keyword = today.keyword
    AND yesterday.tracked_at = today.tracked_at - INTERVAL '1 day'
WHERE today.tracked_at = CURRENT_DATE
  AND (
    -- Dropped in rankings (higher position number = worse)
    (today.position > yesterday.position AND today.position - yesterday.position >= 5)
    -- Was ranking, now not in top 100
    OR (today.position IS NULL AND yesterday.position IS NOT NULL)
    -- Entered top 100 (for positive alerting)
    -- OR (today.position IS NOT NULL AND yesterday.position IS NULL)
  )
ORDER BY position_change DESC;
```

### Featured Snippet Tracking
```ts
async function checkFeaturedSnippetChanges() {
  const changes = await db.query(sql`
    SELECT
        today.keyword,
        today.is_featured_snippet AS has_snippet_today,
        yesterday.is_featured_snippet AS had_snippet_yesterday
    FROM rank_tracking today
    JOIN rank_tracking yesterday
        ON yesterday.keyword = today.keyword
        AND yesterday.tracked_at = today.tracked_at - INTERVAL '1 day'
    WHERE today.tracked_at = CURRENT_DATE
      AND today.is_featured_snippet != yesterday.is_featured_snippet
  `);

  for (const change of changes) {
    const event = change.has_snippet_today ? 'gained_featured_snippet' : 'lost_featured_snippet';
    await slack.send(`SEO: ${event} for "${change.keyword}"`);
  }
}
```

### Weekly Trend Charts Data
```ts
async function getRankingTrend(keyword: string, days = 30) {
  return db.query(sql`
    SELECT
        tracked_at::date AS date,
        position,
        is_featured_snippet
    FROM rank_tracking
    WHERE keyword = ${keyword}
      AND tracked_at >= NOW() - INTERVAL '${days} days'
    ORDER BY tracked_at ASC
  `);
}

async function generateWeeklyReport() {
  const topKeywords = await getTrackedKeywords({ limit: 20, orderBy: 'traffic_value' });
  const trends = await Promise.all(topKeywords.map(kw => getRankingTrend(kw, 7)));

  await emailService.send({
    to: 'seo@company.com',
    subject: `Weekly SEO rank report — ${formatDate(new Date())}`,
    template: 'seo-weekly-report',
    data: { topKeywords, trends },
  });
}
```

## Key Rules
- Track rankings at the same time each day — SERP results vary throughout the day, consistent timing reduces noise
- Store `NULL` for "not in top 100" rather than position 101+ — it is semantically different
- Alert on drops of 5+ positions for high-value keywords; weekly reports cover all tracked keywords
- Correlate ranking changes with deployment timestamps — rank drops often follow technical changes
- Featured snippet tracking is separate from position tracking — a featured snippet at position 1 is categorically different
- SERP API costs scale with keyword count × daily frequency — track high-value keywords daily, long-tail weekly
- Store URL alongside position — the same keyword can rank for different URLs, indicating canonicalization issues
