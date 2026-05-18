# Pattern: Reading Time Estimate

## Overview

"X min read" gives users a quick decision signal before they invest in an article. The algorithm is straightforward (word count ÷ reading speed), but the implementation decisions matter: average reading speed, how to handle code blocks, and updating dynamically in a live editor without running on every keystroke.

## Core Algorithm

```ts
const WORDS_PER_MINUTE = 200  // average adult reading speed for articles

export function calculateReadingTime(text: string): number {
  // Strip HTML/markdown tokens if needed
  const clean = text
    .replace(/<[^>]*>/g, ' ')          // remove HTML tags
    .replace(/```[\s\S]*?```/g, ' ')   // remove code blocks (counted separately)
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')  // markdown links → link text only

  const wordCount = clean.trim().split(/\s+/).filter(Boolean).length

  const minutes = Math.ceil(wordCount / WORDS_PER_MINUTE)
  return Math.max(1, minutes)  // minimum "1 min read"
}
```

**Why 200 wpm:** Common references cite 200–250 wpm for average readers. 200 is conservative (articles often have subheadings, callouts, and images that slow pacing). Being slightly slower is better UX — users are pleasantly surprised when they finish faster than estimated.

**Why strip code blocks:** Code is scanned, not read linearly. Counting code tokens as words wildly inflates estimates for technical articles. You can add a separate "includes N lines of code" note if helpful.

## Display Component

```tsx
type ReadingTimeProps = {
  text: string
  showIcon?: boolean
}

export function ReadingTime({ text, showIcon = true }: ReadingTimeProps) {
  const minutes = calculateReadingTime(text)

  return (
    <span className="reading-time" aria-label={`Estimated reading time: ${minutes} minutes`}>
      {showIcon && <ClockIcon aria-hidden="true" />}
      {minutes} min read
    </span>
  )
}
```

For static article pages, compute reading time at build time (in a server component, `getStaticProps`, etc.) — not in a `useEffect`.

## Live Editor: Debounce the Update

In a CMS or markdown editor, recalculate on content change but throttle to avoid running on every keystroke:

```tsx
import { useState, useEffect, useDeferredValue } from 'react'

export function LiveReadingTime({ content }: { content: string }) {
  // useDeferredValue defers re-computing to idle frames
  const deferredContent = useDeferredValue(content)
  const minutes = calculateReadingTime(deferredContent)

  return <span className="reading-time">{minutes} min read</span>
}
```

**Why `useDeferredValue` not `useDebounce`:** `useDeferredValue` is React's built-in mechanism for low-priority updates — it lets the browser handle typing first, then updates derived state in idle time. A manual `useDebounce` with `setTimeout` is fine too, but adds a visible lag; `useDeferredValue` feels more responsive because it updates as soon as the browser is free.

## Handling Images and Media

For articles with many images, add time per image:

```ts
const SECONDS_PER_IMAGE = 10  // Slack/Medium convention

export function calculateFullReadingTime(html: string): number {
  const textMinutes = calculateReadingTime(html)
  const imageCount = (html.match(/<img/g) ?? []).length
  const imageMinutes = Math.floor((imageCount * SECONDS_PER_IMAGE) / 60)
  return Math.max(1, textMinutes + imageMinutes)
}
```

## Structured Data (optional)

Medium and dev.to include reading time in article schema. Add it to article structured data if publishing to the open web:

```tsx
// In a <script type="application/ld+json">:
{
  "@type": "Article",
  "timeRequired": `PT${minutes}M`  // ISO 8601 duration
}
```

## Word Count Display

For editor UIs, show both word count and reading time:

```tsx
export function DocumentStats({ content }: { content: string }) {
  const words = content.trim().split(/\s+/).filter(Boolean).length
  const minutes = Math.max(1, Math.ceil(words / WORDS_PER_MINUTE))

  return (
    <div className="doc-stats" aria-live="polite">
      <span>{words.toLocaleString()} words</span>
      <span aria-hidden>·</span>
      <span>{minutes} min read</span>
    </div>
  )
}
```

`aria-live="polite"` lets screen readers announce updated counts without interrupting the user mid-sentence.

## Key Rules

- Use 200 wpm, not 250 — conservative estimates feel better when users finish early
- Strip code blocks before counting — code is scanned, not read; including it inflates estimates for technical content
- Minimum 1 min read — "0 min read" is confusing; any content takes some time
- Compute at build time for static pages — no reason to run this in a browser `useEffect`
- Use `useDeferredValue` in live editors — defers calculation to idle frames without blocking typing
- Add ~10 seconds per image for media-heavy articles — accounts for visual scanning time
- `aria-live="polite"` on dynamic word count — announces changes without interrupting screen reader flow
