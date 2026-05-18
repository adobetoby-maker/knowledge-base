# MCP: Mintlify Patterns

## Overview

Mintlify MCP allows querying documentation hosted on Mintlify. Use it to look up API references, guides, and code examples from documentation sites without leaving the conversation context.

## Core Tools

### search_mintlify

Full-text search across a Mintlify documentation site:

```
Tool: mintlify.search_mintlify
  query: "authentication headers"
  domain: "docs.myapi.com"

→ Returns: matching doc sections with titles, URLs, excerpts
```

Use for: finding the right page when you don't know the exact URL structure.

### query_docs_filesystem_mintlify

Semantic query that understands intent:

```
Tool: mintlify.query_docs_filesystem_mintlify
  query: "How do I refresh an expired access token?"
  domain: "docs.myapi.com"

→ Returns: directly relevant content, often pulling from multiple sections
```

Use for: "How do I..." questions where the answer may span multiple pages.

## When to Use Each Tool

| Use `search_mintlify` | Use `query_docs_filesystem_mintlify` |
|----------------------|--------------------------------------|
| Looking for a specific term | Understanding how something works |
| Finding a page by title | Getting a workflow explanation |
| Checking if something is documented | Getting code examples for a task |

## Practical Patterns

### 1. API Integration Research

Before calling an unfamiliar API, query its docs:

```
1. query_docs: "What authentication method does this API use?"
2. query_docs: "What are the rate limits?"
3. query_docs: "Show me an example of creating a resource"
4. search: "error codes" → find the error reference page
```

Build mental model before writing any code. Reduces back-and-forth debugging.

### 2. Finding Code Examples

Mintlify docs often include code samples. Query specifically for them:

```
Tool: mintlify.query_docs_filesystem_mintlify
  query: "JavaScript code example for webhook verification"
```

If the docs include a code block, it appears in the result.

### 3. Checking Breaking Changes

Before upgrading a dependency with Mintlify docs:

```
Tool: mintlify.search_mintlify
  query: "migration v2 v3 breaking changes"
```

Mintlify changelogs and migration guides are indexed.

### 4. Error Resolution

When you hit an API error:

```
Tool: mintlify.query_docs_filesystem_mintlify
  query: "What does error code 429 mean and how to handle it?"
```

Then cross-reference with actual error response body — docs may be outdated.

## Domain Configuration

The `domain` parameter is the docs hostname. Common patterns:
- `docs.company.com`
- `company.mintlify.app`
- `developer.company.com/docs`

If you don't know the domain, check the package's README or npm page for a "docs" link.

## Result Quality

Mintlify search quality depends on:
- How well the docs are organized (headings, sections)
- Whether the docs are up to date with the current version
- Specificity of your query

If results are poor:
- Try more specific terms
- Try synonyms (e.g., "webhook" if "event callback" returns nothing)
- Try a direct URL fetch if you know the page structure

## Limitations

- Only works with Mintlify-hosted documentation
- Doesn't crawl external links from the docs
- Code examples in docs may be outdated vs actual library version
- No ability to verify if an example actually works — test it
