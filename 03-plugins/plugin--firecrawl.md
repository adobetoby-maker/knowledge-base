# Plugin: firecrawl@claude-plugins-official

**What it provides:** Web scraping, crawling, search, and content extraction from any URL.
**When to reach for it:** Getting content from a website, researching a competitor, scraping structured data, extracting docs from any URL.

## Key Skills

| Skill | When to Use |
|-------|-------------|
| `firecrawl:firecrawl-scrape` | Get clean markdown from a single URL |
| `firecrawl:firecrawl-crawl` | Crawl an entire site, following links |
| `firecrawl:firecrawl-search` | Search the web and get clean content back |
| `firecrawl:firecrawl-map` | Get all URLs from a site without fetching content |
| `firecrawl:firecrawl-extract` | Structured data extraction from a page (JSON output) |
| `firecrawl:firecrawl-instruct` | Give natural language instructions for what to extract |
| `firecrawl:firecrawl-download` | Download a page's assets |
| `firecrawl:firecrawl-agent` | Autonomous scraping agent — finds and extracts without explicit instructions |

## Decision Branch
- IF you have a specific URL and want its content → `firecrawl:firecrawl-scrape`
- IF you want to search and read results → `firecrawl:firecrawl-search`
- IF you want to crawl a whole site → `firecrawl:firecrawl-crawl` (can be slow/costly)
- IF you want a list of all URLs without content → `firecrawl:firecrawl-map` (fast)
- IF you want structured JSON from a page → `firecrawl:firecrawl-extract`
- IF you want to explain what you need in plain English → `firecrawl:firecrawl-instruct`

## Common Use Cases in This Stack

**Research competitor site:**
```
Skill("firecrawl:firecrawl-scrape", "https://competitor.com/pricing")
→ Returns clean markdown, no ads or navigation
```

**Get docs from any URL:**
```
Skill("firecrawl:firecrawl-scrape", "https://supabase.com/docs/guides/auth")
→ Better than WebFetch for messy sites
```

**Extract structured data:**
```
Skill("firecrawl:firecrawl-extract", "https://example.com/products — extract: name, price, description as JSON array")
```

**Find all pages on a site:**
```
Skill("firecrawl:firecrawl-map", "https://example.com")
→ Returns URL list. Use to scope a crawl before running it.
```

## vs WebFetch
- `WebFetch` — built-in, fast, simple. Use for clean/well-structured pages.
- `Firecrawl scrape` — handles JavaScript-rendered content, returns cleaner markdown. Use when WebFetch returns garbage.

## vs WebSearch
- `WebSearch` — finds pages by query, returns snippets
- `Firecrawl search` — finds pages AND returns full clean content. More expensive but richer.

## Cost Awareness
Crawling is expensive (API calls per page). Always `firecrawl-map` first to see scope.
If you need > 20 pages, confirm with user before crawling.
