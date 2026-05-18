# Web Search Agent

A web search agent formulates queries, retrieves results, extracts relevant facts, and cites sources. The main failure modes are: bad query formulation producing irrelevant results, blindly trusting all retrieved content, and failing to cite claims so errors can be traced.

## Query Formulation: 3–5 Targeted Searches

One broad query produces shallow results. Plan 3–5 targeted queries per research task:
- **Narrow by subtopic**: break the user's question into its component facts. "What are the side effects and dosage of metformin?" becomes two searches, not one.
- **Vary terminology**: the first query uses the user's language; a follow-up uses domain-specific synonyms. "Heart attack" and "myocardial infarction" return overlapping but not identical result sets.
- **Source-specific queries**: when you need authoritative data (statistics, regulations, official guidance), add a site: filter or a term like "official", "CDC", "FDA", "NIST" to bias toward primary sources.
- **Recency filter**: for time-sensitive topics, include a year or "2024 2025" in the query, or use the date-filter parameter if the search API supports it.

Avoid one-and-done broad queries: "tell me everything about X" returns a generic top-10-results page with shallow coverage of each subtopic.

## Result Filtering

Not every retrieved result is useful. After retrieval:
1. Discard results where the URL or title clearly doesn't match the query intent (e.g., a shopping page when you searched for documentation).
2. Prioritize pages with full article content over aggregator pages, listicles, or forum threads for factual queries.
3. If the top result is a Wikipedia disambiguation page, follow the most specific topic link before extracting.

Limit extraction to the top 3–5 results per query unless you need breadth for a "what are multiple perspectives on X" question.

## Fact Extraction from HTML

Web pages contain navigation, ads, boilerplate, and cookie banners mixed with the actual content. Strip before extracting:
- Use `innerText` or Readability-style extraction to get body text, not raw HTML.
- Identify the main content block by paragraph density — the section with the most `<p>` tags per `<div>` nesting level is usually the article body.
- For structured data (tables, lists), extract the data structure rather than flattened text to preserve relationships.

Don't pass raw HTML to the model for extraction — it bloats the context and the model will spend tokens on navigation menus.

## Source Credibility Weighting

Not all sources are equal. Apply a credibility hierarchy:
1. **Primary sources**: official government sites (.gov, .edu), peer-reviewed abstracts, official vendor documentation.
2. **Established news/reference**: major news organizations, Wikipedia (for non-controversial facts), established industry publications.
3. **Secondary commentary**: blogs, aggregators, forums. Use for context and leads to primary sources, not as standalone citations.

When two sources conflict, the higher-tier source wins. If two primary sources conflict, flag the conflict in the response rather than picking one silently.

## Citation Formatting

Every factual claim gets an inline citation. Standard format:
- Inline: `Metformin reduces A1C by 1–2% on average [Mayo Clinic, 2024].`
- Footnote block at the end: source name, URL, date accessed, one-sentence description of what was retrieved from it.

Never omit the URL — it's the audit trail. If the URL will break (dynamic search result), include the domain and article title instead so the reader can find it.

## Key Rules

- Plan 3–5 targeted queries per task; one broad query produces shallow, unreliable results.
- Filter results before extraction — discard off-topic URLs, aggregators, and disambiguation pages.
- Strip HTML to body text before passing to the model.
- Apply source credibility tiers; flag conflicts rather than silently picking a winner.
- Every factual claim gets an inline citation with URL.
- Date-filter queries for time-sensitive topics to avoid citing outdated information as current.
