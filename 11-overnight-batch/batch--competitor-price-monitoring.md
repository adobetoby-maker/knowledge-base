# Batch: Competitor Price Monitoring

## Overview
Pricing intelligence is a competitive advantage — knowing when competitors change prices enables
timely response. Automated price monitoring replaces manual checking with a scheduled, consistent
process that stores historical data, enabling trend analysis beyond just point-in-time snapshots.

## Implementation

### Robots.txt Compliance Check
```ts
import { Robotstxt } from 'robots-txt-parser';

async function canScrape(baseUrl: string, path: string): Promise<boolean> {
  const parser = new Robotstxt();
  try {
    await parser.useRobotsFor(baseUrl);
    return parser.canCrawl('PriceMonitorBot/1.0', `${baseUrl}${path}`);
  } catch {
    // If robots.txt is unreachable, assume conservative (don't scrape)
    return false;
  }
}
```

### Structured Price Scraping
```ts
import * as cheerio from 'cheerio';

interface PriceRecord {
  competitor: string;
  productId: string;
  productName: string;
  price: number;
  currency: string;
  inStock: boolean;
  scrapedAt: Date;
}

async function scrapeCompetitorPrices(competitor: CompetitorConfig): Promise<PriceRecord[]> {
  const allowed = await canScrape(competitor.baseUrl, competitor.pricingPath);
  if (!allowed) {
    console.warn(`Robots.txt disallows scraping ${competitor.name}`);
    return [];
  }

  // Rate limit: 1 request per second minimum
  await sleep(1000 + Math.random() * 500);

  const response = await fetch(`${competitor.baseUrl}${competitor.pricingPath}`, {
    headers: { 'User-Agent': 'PriceMonitorBot/1.0 (price-comparison@company.com)' }
  });

  if (!response.ok) throw new Error(`HTTP ${response.status} from ${competitor.name}`);

  const $ = cheerio.load(await response.text());
  return competitor.extractPrices($);  // competitor-specific CSS selector logic
}
```

### Time-Series Storage
```sql
-- Store every scrape result, not just current prices
CREATE TABLE competitor_prices (
    id          BIGSERIAL PRIMARY KEY,
    competitor  TEXT NOT NULL,
    product_id  TEXT NOT NULL,
    product_name TEXT,
    price       NUMERIC(10, 2) NOT NULL,
    currency    CHAR(3) NOT NULL DEFAULT 'USD',
    in_stock    BOOLEAN DEFAULT true,
    scraped_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_competitor_prices_lookup
    ON competitor_prices (competitor, product_id, scraped_at DESC);

-- View for latest price per product per competitor
CREATE VIEW latest_competitor_prices AS
SELECT DISTINCT ON (competitor, product_id)
    competitor, product_id, product_name, price, currency, in_stock, scraped_at
FROM competitor_prices
ORDER BY competitor, product_id, scraped_at DESC;
```

### Alert on Price Changes > 10%
```ts
async function detectAndAlertPriceChanges() {
  const alerts: PriceAlert[] = [];

  // Compare today's prices against yesterday's
  const changes = await db.query(sql`
    SELECT
        today.competitor,
        today.product_id,
        today.product_name,
        yesterday.price AS old_price,
        today.price AS new_price,
        round(100.0 * (today.price - yesterday.price) / yesterday.price, 2) AS pct_change
    FROM latest_competitor_prices today
    JOIN LATERAL (
        SELECT price FROM competitor_prices
        WHERE competitor = today.competitor
          AND product_id = today.product_id
          AND scraped_at < NOW() - INTERVAL '20 hours'
        ORDER BY scraped_at DESC LIMIT 1
    ) yesterday ON true
    WHERE abs((today.price - yesterday.price) / yesterday.price) > 0.10  -- 10% threshold
  `);

  for (const change of changes) {
    const direction = change.pct_change > 0 ? 'price_increase' : 'price_decrease';
    await db.insert('price_alerts', {
      ...change,
      change_type: direction,
      alerted_at: new Date(),
    });

    if (Math.abs(change.pct_change) > 20) {  // significant change → immediate Slack alert
      await slack.send(`Price alert: ${change.competitor} changed ${change.product_name} by ${change.pct_change}%`);
    }
  }
}
```

### Weekly Trend Report
```ts
async function generateWeeklyPriceReport() {
  const report = await db.query(sql`
    SELECT
        competitor,
        count(*) AS products_tracked,
        count(*) FILTER (WHERE change_type = 'price_decrease') AS price_cuts,
        count(*) FILTER (WHERE change_type = 'price_increase') AS price_increases,
        count(*) FILTER (WHERE change_type = 'new_product') AS new_products,
        avg(abs(pct_change)) AS avg_change_magnitude
    FROM price_alerts
    WHERE alerted_at > NOW() - INTERVAL '7 days'
    GROUP BY competitor
  `);

  await emailService.send({
    to: 'pricing-team@company.com',
    subject: `Weekly competitor pricing report — ${formatDate(new Date())}`,
    template: 'pricing-report',
    data: { report },
  });
}
```

## Key Rules
- Always check robots.txt before scraping — identify your bot with a descriptive User-Agent and contact email
- Rate limit at minimum 1 request per second — aggressive scraping gets IP-blocked and may violate ToS
- Store every scrape result as a time series, never overwrite — historical data enables trend analysis
- Alert on > 10% changes, but also log all changes (< 10%) for weekly trend reports
- Use a randomized delay between requests (1s + random 0-500ms) to avoid pattern detection
- Never store scraped data for products you don't track internally — it creates a GDPR compliance burden
- If a competitor price API is available (via partnership or data provider), use it instead of scraping
