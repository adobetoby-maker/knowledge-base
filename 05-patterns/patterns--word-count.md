# Pattern: Word Count / Reading Time

## Overview

Word count and reading time indicators help users gauge content length before reading. They're common in CMSs, blog editors, and long-form content platforms. The reading time calculation is based on average adult reading speed (~200-250 wpm). Display both in editors and optionally in the reader view.

## Core Calculation

```ts
function countWords(text: string): number {
  if (!text.trim()) return 0
  // Strip HTML/Markdown markup before counting
  const plain = text
    .replace(/<[^>]+>/g, ' ')        // Strip HTML tags
    .replace(/[#*_`~\[\]()>]/g, ' ') // Strip Markdown syntax
    .replace(/\s+/g, ' ')            // Normalize whitespace
    .trim()
  return plain.split(' ').filter(Boolean).length
}

function readingTimeMinutes(wordCount: number, wpm = 230): number {
  return Math.ceil(wordCount / wpm)
}

function formatReadingTime(minutes: number): string {
  if (minutes < 1) return 'Less than 1 min read'
  if (minutes === 1) return '1 min read'
  return `${minutes} min read`
}

// Usage
const words = countWords(article.body)
const readingTime = readingTimeMinutes(words)
// Display: "1,240 words · 6 min read"
```

## Live Editor Counter

```tsx
import { useDeferredValue } from 'react'

function WordCountBar({ content }: { content: string }) {
  // Defer calculation to avoid blocking fast typing
  const deferred = useDeferredValue(content)

  const wordCount = useMemo(() => countWords(deferred), [deferred])
  const minutes = readingTimeMinutes(wordCount)

  return (
    <div className="flex items-center gap-3 text-xs text-gray-500 px-4 py-2 border-t">
      <span>{wordCount.toLocaleString()} words</span>
      <span className="text-gray-300">·</span>
      <span>{formatReadingTime(minutes)}</span>
      {wordCount > 0 && wordCount < 300 && (
        <span className="text-amber-600">Short article — consider expanding</span>
      )}
    </div>
  )
}
```

`useDeferredValue` defers the expensive calculation when the user is typing fast — the UI stays responsive.

## Selection Word Count

```tsx
function SelectionWordCount() {
  const [selection, setSelection] = useState('')

  useEffect(() => {
    function handleSelection() {
      const selected = window.getSelection()?.toString() ?? ''
      setSelection(selected)
    }

    document.addEventListener('selectionchange', handleSelection)
    return () => document.removeEventListener('selectionchange', handleSelection)
  }, [])

  if (!selection.trim()) return null

  const count = countWords(selection)
  return (
    <div className="fixed bottom-4 right-4 bg-gray-900 text-white text-xs px-2 py-1 rounded">
      {count} words selected
    </div>
  )
}
```

## Reading Time in Article Metadata

```tsx
function ArticleMeta({ article }: { article: Article }) {
  const wordCount = countWords(article.body)
  const readingTime = readingTimeMinutes(wordCount)

  return (
    <div className="flex items-center gap-3 text-sm text-gray-500">
      <time dateTime={article.publishedAt.toISOString()}>
        {article.publishedAt.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}
      </time>
      <span>·</span>
      <span>{readingTime} min read</span>
    </div>
  )
}
```

## Storing Pre-Computed Values

For CMS-backed content, compute at save time rather than render time:

```ts
// Compute on save
async function saveArticle(article: ArticleInput) {
  const wordCount = countWords(article.body)
  const readingTimeMin = readingTimeMinutes(wordCount)

  await db.update(articles).set({
    body: article.body,
    wordCount,
    readingTimeMin,
    updatedAt: new Date(),
  })
}
```

## Target Length Indicators (for Editors)

```tsx
interface WordCountTarget {
  min: number
  max: number
  label: string
}

const CONTENT_TARGETS: Record<string, WordCountTarget> = {
  'blog-post': { min: 600, max: 1800, label: 'Blog post' },
  'product-description': { min: 150, max: 500, label: 'Product description' },
  'landing-page': { min: 300, max: 800, label: 'Landing page' },
  'seo-article': { min: 1200, max: 3000, label: 'SEO article' },
}

function WordCountTarget({ count, contentType }: { count: number; contentType: string }) {
  const target = CONTENT_TARGETS[contentType]
  if (!target) return null

  const pct = Math.min(100, (count / target.max) * 100)
  const inRange = count >= target.min && count <= target.max

  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs text-gray-500">
        <span>{count}/{target.max} words</span>
        <span className={inRange ? 'text-green-600' : 'text-amber-600'}>
          {inRange ? 'Good length' : count < target.min ? `Add ${target.min - count} more words` : 'Consider trimming'}
        </span>
      </div>
      <div className="h-1 bg-gray-200 rounded-full">
        <div
          className={`h-1 rounded-full transition-all ${inRange ? 'bg-green-500' : 'bg-amber-500'}`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  )
}
```

## Key Rules

- Strip HTML and Markdown syntax before counting — raw markup inflates word counts significantly.
- `useDeferredValue` for live counting in editors — prevents the DOM from lagging behind typing.
- Reading time of 230 wpm is the average adult reading speed; adjust down to 180–200 for technical content, up to 250 for narrative.
- Pre-compute and store word count and reading time on save — don't recompute on every page load for published content.
- Show word count feedback in context (e.g., "Add 200 more words to reach minimum length") not just a raw number.
