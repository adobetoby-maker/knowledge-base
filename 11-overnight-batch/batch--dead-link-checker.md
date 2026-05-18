# Batch: Dead Link Checker

## What This Covers

Automated scanning of outbound links to detect 404s, redirects, and timeouts. Run weekly overnight. Alerts on broken links that hurt SEO and user experience.

## Script: Crawl and Check

```ts
// scripts/check-dead-links.ts
import { JSDOM } from 'jsdom'

interface LinkCheckResult {
  page: string
  link: string
  status: number | 'timeout' | 'error'
  redirectTo?: string
}

async function checkLink(url: string): Promise<{ status: number | 'timeout' | 'error'; redirectTo?: string }> {
  try {
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 8000)  // 8 second timeout

    const res = await fetch(url, {
      method: 'HEAD',  // HEAD is faster — no body
      redirect: 'manual',  // Don't follow redirects — detect them
      signal: controller.signal,
    })
    clearTimeout(timeout)

    if (res.status >= 300 && res.status < 400) {
      return { status: res.status, redirectTo: res.headers.get('location') ?? undefined }
    }
    return { status: res.status }
  } catch (err) {
    if ((err as Error).name === 'AbortError') return { status: 'timeout' }
    return { status: 'error' }
  }
}

async function extractLinks(pageUrl: string): Promise<string[]> {
  const res = await fetch(pageUrl)
  const html = await res.text()
  const dom = new JSDOM(html)

  const links: string[] = []
  dom.window.document.querySelectorAll('a[href]').forEach((a) => {
    const href = a.getAttribute('href')!
    if (href.startsWith('http') && !href.includes('yoursite.com')) {
      links.push(href)  // Only check external links
    }
  })

  return [...new Set(links)]  // Deduplicate
}

async function checkSiteLinks(pages: string[]): Promise<LinkCheckResult[]> {
  const broken: LinkCheckResult[] = []

  for (const page of pages) {
    const links = await extractLinks(page)

    // Check links with concurrency limit
    const batchSize = 5
    for (let i = 0; i < links.length; i += batchSize) {
      const batch = links.slice(i, i + batchSize)
      const results = await Promise.all(
        batch.map(async (link) => ({
          page,
          link,
          ...(await checkLink(link)),
        }))
      )

      const batchBroken = results.filter((r) =>
        r.status === 404 || r.status === 410 || r.status === 'error'
      )
      broken.push(...batchBroken)
    }

    // Rate limit — don't hammer external servers
    await new Promise((r) => setTimeout(r, 500))
  }

  return broken
}
```

## Get Pages to Check

```ts
async function getPagesToCheck(): Promise<string[]> {
  const BASE = 'https://yoursite.com'

  // From sitemap
  const sitemapRes = await fetch(`${BASE}/sitemap.xml`)
  const xml = await sitemapRes.text()
  const urls = [...xml.matchAll(/<loc>(.*?)<\/loc>/g)].map((m) => m[1])

  return urls.filter((u) => !u.includes('/admin') && !u.includes('/api'))
}
```

## Report Generation

```ts
async function generateReport(results: LinkCheckResult[]): Promise<string> {
  if (results.length === 0) return '✅ No broken links found'

  const byStatus = results.reduce<Record<string, LinkCheckResult[]>>((acc, r) => {
    const key = String(r.status)
    if (!acc[key]) acc[key] = []
    acc[key].push(r)
    return acc
  }, {})

  let report = `# Dead Link Report — ${new Date().toLocaleDateString()}\n\n`
  report += `**${results.length} broken links found**\n\n`

  for (const [status, links] of Object.entries(byStatus)) {
    report += `## Status ${status} (${links.length} links)\n\n`
    for (const link of links) {
      report += `- \`${link.page}\` → \`${link.link}\`\n`
      if (link.redirectTo) report += `  Redirects to: ${link.redirectTo}\n`
    }
    report += '\n'
  }

  return report
}
```

## Send Alert via Email

```ts
async function run() {
  console.log('Starting dead link check...')
  const pages = await getPagesToCheck()
  console.log(`Checking ${pages.length} pages`)

  const broken = await checkSiteLinks(pages)
  const report = await generateReport(broken)

  if (broken.length > 0) {
    await sendEmail({
      to: process.env.ADMIN_EMAIL!,
      subject: `Dead Links Found: ${broken.length} broken links`,
      text: report,
    })
    console.log(`Found ${broken.length} broken links — report emailed`)
  } else {
    console.log('No broken links found')
  }
}
```

## Overnight Schedule (GitHub Actions)

```yaml
# .github/workflows/dead-link-check.yml
name: Dead Link Check

on:
  schedule:
    - cron: '0 3 * * 1'  # Every Monday at 3 AM

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npx tsx scripts/check-dead-links.ts
        env:
          ADMIN_EMAIL: ${{ secrets.ADMIN_EMAIL }}
          RESEND_API_KEY: ${{ secrets.RESEND_API_KEY }}
```

## What to Skip

- Internal links (check with your own crawl/health check)
- Social media links (rate-limited aggressively — false positives)
- Archive.org / Wayback links (intentionally slow)
- `noindex` pages (not crawled by Google anyway)

## Automatic Fix for Redirected Links

For 301 redirects, update the links in your DB or content files:

```ts
const permanent301s = results.filter((r) => r.status === 301 && r.redirectTo)

// For articles stored in DB — update the link
for (const link of permanent301s) {
  await supabase.from('article_links')
    .update({ url: link.redirectTo })
    .eq('url', link.link)
}
```
