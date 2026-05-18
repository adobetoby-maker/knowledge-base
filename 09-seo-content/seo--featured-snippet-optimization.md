# SEO: Featured Snippet Optimization

## Overview
Featured snippets (Position 0) appear above the first organic result and capture a large share of clicks for informational queries. They're awarded to pages already ranking in the top 5 for a query — Google extracts and formats content from a ranking page to answer the query directly. The implication: you must already rank to earn the snippet, but once you have it, you own Position 0 and effectively "double" your SERP real estate.

## Snippet Types

**Paragraph snippets** (~40–50 words)
- Triggered by: "what is X", "who is X", "why does X"
- Format: direct, declarative answer in the first 50 words after a relevant H2
- The question as H2, the answer as the first paragraph under it

**List snippets (ordered / unordered)**
- Triggered by: "how to X", "steps to X", "best X", "types of X"
- Format: H2 with the target query, followed by H3s or bullet points as list items
- Google expands the list — usually 7 or 8 items before truncating

**Table snippets**
- Triggered by: comparison queries, "X vs Y", pricing queries, schedules
- Format: HTML `<table>` with clear column headers
- Keep tables simple — complex merged cells don't render well in snippets

**Video snippets**
- Triggered by: how-to queries with video intent
- YouTube video with chapters/timestamps — Google can highlight the relevant segment

## How to Target Snippets

### Identify snippet opportunities
1. Pull queries from GSC where you rank positions 3–10 and the SERP shows a featured snippet
2. Check if the snippet source has weaker content than yours — if so, reformat your page
3. Use Ahrefs / SEMrush "featured snippet" filter to find queries with snippet opportunity

### Format for paragraph snippets
```
## What Is [Term]?
[Term] is [concise definition in 40–60 words that directly answers the question with key context].
```
The definition should be complete on its own — Google may display only this paragraph.

### Format for list snippets
```
## How to [Do X]
### Step 1: [Action]
[Brief description — 1–2 sentences]
### Step 2: [Action]
...
```
Or use `<ul>` / `<ol>` with clear item labels. More items generally = better chance of capturing the snippet.

### Format for table snippets
Use proper HTML `<table>` (not CSS-styled divs). Include `<th>` headers. Keep 2–4 columns.

## Position 0 Trade-off

Some SEOs avoid targeting snippets for high-commercial-value queries because the snippet satisfies the query without a click ("zero-click search"). For informational queries that lead to funnel entry, snippets are valuable. For pure "what is X" queries with no conversion path, the click steal trade-off is real.

Rule: target snippets for informational queries that serve as top-of-funnel awareness, where the goal is brand exposure and trust, not just the click.

## After Winning the Snippet

- Monitor with GSC — snippets are volatile and can be lost to competitor format changes
- If you win the snippet and click rate drops, consider removing the snippet (add `<meta name="robots" content="nosnippet">`) — this is rare but occasionally justified for high-value commercial queries

## Key Rules

- You must already rank in the top 5 before snippet optimization is possible — don't target snippets on new pages
- Format matters more than content quality for snippet selection — same information, structured differently, wins
- Target question-format H2s for every informational page — "What Is X?" "How Does X Work?" "Why Does X Happen?"
- 40–50 words for paragraph answers — Google truncates longer answers
- List items should be scannable headings, not long paragraphs
