# Technical SEO Audit — Process and Tooling

## Scope Distinction from the Checklist

`seo--technical-audit-checklist.md` is a pass/fail checklist of known issues. This file covers the *process* of discovering unknown issues — how to crawl, read log files, and triage findings efficiently. Use both together.

## Crawlability: Screaming Frog

Screaming Frog crawls your site the way Googlebot would. Run it against production, not localhost — many issues (canonical tags pointing to HTTPS, hreflang, CDN headers) don't exist locally.

Key configuration:
- Set user-agent to Googlebot to catch bot-specific blocks (`robots.txt` directives, Cloudflare bot management rules)
- Enable JavaScript rendering (via Screaming Frog's built-in headless Chrome) for SPAs — otherwise it misses dynamically rendered content
- Export: **All pages**, **Directives** (noindex/canonical), **Hreflang** (if multilingual), **Response Codes** (4xx, 3xx chains)

Priority findings from the crawl:
1. Pages returning 200 that should be 301ing (www vs non-www duplicates, HTTP vs HTTPS)
2. Chains of more than 1 redirect (301 → 301 → 200) — Googlebot follows but penalizes deeply chained redirects
3. Canonicals pointing to non-200 pages
4. Large pages (>1MB HTML) — typically a symptom of unoptimized JSON in `__NEXT_DATA__`

## Indexability: URL Inspection Spot Checks

Screaming Frog tells you what the site serves. Google Search Console URL Inspection tells you what Google has *indexed* — these differ when:
- The page was recently changed and not re-crawled
- JavaScript content isn't rendering correctly on Googlebot
- A noindex was added and later removed but the page wasn't re-crawled

Spot-check these URL types in GSC URL Inspection:
- Homepage
- Top-traffic landing pages
- A recently published blog post
- Any page that had a URL change or canonical update recently

"Page is not indexed" + reason "Crawled but not currently indexed" typically means thin content or duplicate content — not a technical crawl block.

## Page Speed: CWV via PageSpeed Insights + CrUX

Use PageSpeed Insights (not just Lighthouse locally) for real-world Chrome User Experience data. The CrUX data shows P75 field data for actual users, not a simulated lab result.

Focus on LCP (Largest Contentful Paint) and INP (Interaction to Next Paint) first — CLS is usually easier to fix. The field data in GSC's Core Web Vitals report aggregates over 28 days, so improvements show up slowly there. Use PageSpeed Insights for immediate feedback after a fix.

For diagnosing LCP: the LCP element is identified in the Lighthouse trace. Most Next.js LCP issues are: unoptimized hero image (missing `priority` on `next/image`), render-blocking font load, or a large server-side data fetch blocking the initial HTML.

## Structured Data Validation

Two tools: Google's Rich Results Test (checks for Rich Result eligibility — not all schema qualifies) and schema.org's validator (checks spec compliance regardless of Rich Result eligibility). Use both.

Common errors that Screaming Frog won't catch:
- `datePublished` in wrong format (must be ISO 8601: `2025-01-15` not `January 15, 2025`)
- `author` without `url` or `sameAs` (reduces E-E-A-T signal)
- `LocalBusiness` with coordinates swapped (longitude before latitude — PostGIS convention vs schema.org convention)

## Log File Analysis for Crawl Efficiency

Vercel's request logs or Cloudflare analytics show Googlebot's actual crawl frequency. Access logs are the ground truth — they show which URLs Googlebot is visiting, how often, and what it gets back.

What to look for:
- Googlebot crawling paginated URLs with `?page=2` (waste of crawl budget if you block these in robots.txt but have mixed directives)
- Googlebot hitting 404s for URLs that were valid last year (old redirect target that no longer exists)
- Crawl frequency dropping — indicates Google has deprioritized the site (often after a period of slow response times)

On Vercel: enable log draining to Axiom or Datadog to retain logs longer than Vercel's 1-hour retention. Cloudflare analytics retain bot traffic data for 30 days in the dashboard without extra setup.

## Triage Priority

1. Indexability blocks (noindex, robots.txt blocks) — fix immediately, these prevent rankings entirely
2. 4xx errors on linked pages — waste crawl budget and signal poor maintenance
3. LCP > 4s on landing pages — directly impacts rankings via CWV
4. Structured data errors on pages targeting Rich Results
5. Redirect chains — lower priority but clean up in batches

## Key Rules

- Run Screaming Frog in JavaScript rendering mode for React/Next.js sites — non-JS crawl misses most content
- Use GSC URL Inspection for indexability truth — what Screaming Frog crawls and what Google indexes are different things
- PageSpeed Insights field data (CrUX) is what Google uses for rankings, not the Lighthouse lab score
- Set up log retention beyond Vercel's 1-hour limit to get useful crawl frequency data
- Validate schema with both Rich Results Test AND schema.org validator — one checks eligibility, the other checks correctness
