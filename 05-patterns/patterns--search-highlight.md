# Pattern: Search Term Highlighting in Results

## Overview

Highlighting matched search terms helps users instantly confirm relevance. The implementation looks trivial but has real failure modes: query strings with regex special characters crash the matcher, case sensitivity mismatches produce no highlights, and naively wrapping each match in a new DOM node inside a virtualized list causes expensive re-renders on every keystroke. Get these three things right and highlighting is robust.

## Core Highlight Function

```tsx
import { useMemo } from 'react'

type HighlightedTextProps = {
  text: string
  query: string
}

export function HighlightedText({ text, query }: HighlightedTextProps) {
  const parts = useMemo(() => splitWithHighlights(text, query), [text, query])

  if (!query.trim()) return <span>{text}</span>

  return (
    <span>
      {parts.map((part, i) =>
        part.highlight ? (
          <mark key={i} className="search-highlight">
            {part.text}
          </mark>
        ) : (
          <span key={i}>{part.text}</span>
        )
      )}
    </span>
  )
}

type Part = { text: string; highlight: boolean }

function splitWithHighlights(text: string, query: string): Part[] {
  if (!query.trim()) return [{ text, highlight: false }]

  // Escape regex special characters in user input
  const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const regex = new RegExp(`(${escaped})`, 'gi')  // capture group keeps the match in split result

  return text.split(regex).map(segment => ({
    text: segment,
    highlight: regex.test(segment) && segment.toLowerCase() === query.toLowerCase(),
  }))
}
```

**Why `regex.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')`:** If the user types `C++` or `$price` or `(optional)`, those characters are regex metacharacters. Without escaping, the regex either throws an error or matches incorrectly. Always escape user-supplied query strings before using them in `new RegExp`.

**Why a capture group in `split`:** `"hello world".split(/(world)/)` returns `["hello ", "world", ""]` — the matched portion is preserved in the array. Without the capture group, `split` discards the matched text.

## `<mark>` for Semantic Highlighting

`<mark>` is the correct HTML element for highlighted search results. It carries semantic meaning ("this text is highlighted as relevant to the user's search"), not just visual styling. Screen readers may announce it as "highlighted" in some configurations.

```css
mark.search-highlight {
  background: hsl(48 96% 89%);  /* pale yellow */
  color: inherit;
  border-radius: 2px;
  padding: 0 1px;
}

/* Dark mode */
@media (prefers-color-scheme: dark) {
  mark.search-highlight {
    background: hsl(48 96% 20%);
    color: hsl(48 96% 89%);
  }
}
```

Don't use `<span style="background: yellow">` — it loses semantic meaning and is harder to theme.

## Multi-Word / Phrase Matching

For highlighting all words in a multi-word query:

```ts
function buildMultiWordRegex(query: string): RegExp {
  const terms = query
    .trim()
    .split(/\s+/)
    .map(t => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
    .filter(Boolean)

  if (terms.length === 0) return /(?!)/  // never matches

  return new RegExp(`(${terms.join('|')})`, 'gi')
}
```

Each word is a separate alternation — the first match wins, so put longer terms first to prevent partial matches shadowing complete ones.

## Performance in Virtualized Lists

In a virtual list with thousands of rows, `splitWithHighlights` runs on every visible row on every query change. Memoize per-row:

```tsx
// Inside the virtual row renderer:
const highlighted = useMemo(
  () => splitWithHighlights(row.title, query),
  [row.title, query]  // only recomputes when title or query changes
)
```

If the list has hundreds of thousands of rows and query changes are fast (real-time), consider debouncing the query value passed to the highlight function:

```ts
const debouncedQuery = useDebounce(query, 150)
// pass debouncedQuery to HighlightedText, not the live query
```

## Accessibility Notes

Highlighted text should be meaningful without color alone — the yellow background is a visual aid, but the content is the same. Screen readers don't typically read `<mark>` differently, which is fine — the result text is still fully available. Don't add `aria-label` to each `<mark>` tag (it adds excessive noise for screen reader users scanning results).

## Key Rules

- Always escape user input before `new RegExp` — unescaped metacharacters throw errors or match incorrectly
- Use capture groups in `split` — without them the matched text is removed from the result array
- Use `<mark>` not `<span>` — carries semantic meaning for search relevance
- Style `<mark>` with a background that works in dark mode — default browser yellow is unreadable in dark themes
- `useMemo` on highlight computation in virtual lists — prevents re-splitting every visible row on re-render
- Debounce query in large lists — prevents highlighting lag blocking the input field
- Multi-word: sort alternations by length (longest first) to prevent shorter terms from shadowing complete matches
