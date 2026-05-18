# Pattern: Reading Progress Indicator

## Overview

A thin bar at the top of an article that grows as the user scrolls, indicating how much they've read. Useful for long-form content like blog posts.

## Implementation

```tsx
import { useState, useEffect } from 'react'

export function ReadingProgressBar() {
  const [progress, setProgress] = useState(0)

  useEffect(() => {
    function updateProgress() {
      const scrollTop = window.scrollY
      const docHeight = document.documentElement.scrollHeight - window.innerHeight
      const pct = docHeight > 0 ? (scrollTop / docHeight) * 100 : 0
      setProgress(Math.min(100, pct))
    }

    window.addEventListener('scroll', updateProgress, { passive: true })
    updateProgress()  // Set initial value

    return () => window.removeEventListener('scroll', updateProgress)
  }, [])

  return (
    <div
      className="fixed top-0 left-0 z-50 h-1 bg-blue-500 transition-all duration-75"
      style={{ width: `${progress}%` }}
      role="progressbar"
      aria-valuenow={Math.round(progress)}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-label="Reading progress"
    />
  )
}
```

## With Article Element Scope

If you only want to track progress within the article (not the full page including header/footer):

```tsx
import { useState, useEffect, useRef } from 'react'

export function ArticleReadingProgress({ articleRef }: { articleRef: React.RefObject<HTMLElement> }) {
  const [progress, setProgress] = useState(0)

  useEffect(() => {
    function updateProgress() {
      const article = articleRef.current
      if (!article) return

      const { top, height } = article.getBoundingClientRect()
      const viewportHeight = window.innerHeight

      if (top > viewportHeight) {
        // Article hasn't started
        setProgress(0)
      } else if (top + height < 0) {
        // Article is fully above viewport
        setProgress(100)
      } else {
        // In progress: how much of article has scrolled above viewport
        const scrolled = -top
        const total = height - viewportHeight
        setProgress(total > 0 ? Math.min(100, (scrolled / total) * 100) : 100)
      }
    }

    window.addEventListener('scroll', updateProgress, { passive: true })
    updateProgress()

    return () => window.removeEventListener('scroll', updateProgress)
  }, [articleRef])

  return (
    <div
      className="fixed top-0 left-0 z-50 h-0.5 bg-blue-500 transition-[width] duration-100"
      style={{ width: `${progress}%` }}
    />
  )
}
```

## Usage in Article Page

```tsx
import { useRef } from 'react'

export default function BlogPost({ post }: { post: Post }) {
  const articleRef = useRef<HTMLElement>(null)

  return (
    <>
      <ArticleReadingProgress articleRef={articleRef} />
      
      <article ref={articleRef} className="prose max-w-3xl mx-auto px-4 py-8">
        <h1>{post.title}</h1>
        <div>{post.content}</div>
      </article>
    </>
  )
}
```

## Time-to-Read Estimate

Pair with a reading time estimate in the header:

```tsx
function estimateReadTime(text: string): number {
  const wordsPerMinute = 225  // Average adult reading speed
  const wordCount = text.trim().split(/\s+/).length
  return Math.max(1, Math.ceil(wordCount / wordsPerMinute))
}

function ReadingMeta({ content }: { content: string }) {
  const minutes = estimateReadTime(content)
  return (
    <span className="text-sm text-gray-500">
      {minutes} min read
    </span>
  )
}
```

## Scroll-Based Analytics

Combine with engagement tracking:

```tsx
useEffect(() => {
  let maxProgress = 0
  let reported25 = false, reported50 = false, reported75 = false, reported100 = false

  function trackProgress() {
    if (progress > maxProgress) {
      maxProgress = progress
    }

    if (progress >= 25 && !reported25) {
      trackEvent('article_read_25pct', { slug: post.slug })
      reported25 = true
    }
    if (progress >= 50 && !reported50) {
      trackEvent('article_read_50pct', { slug: post.slug })
      reported50 = true
    }
    if (progress >= 75 && !reported75) {
      trackEvent('article_read_75pct', { slug: post.slug })
      reported75 = true
    }
    if (progress >= 99 && !reported100) {
      trackEvent('article_read_complete', { slug: post.slug })
      reported100 = true
    }
  }

  trackProgress()
}, [progress])
```

25/50/75/100% milestones are the industry standard for content engagement measurement. The 25% event fires quickly (on page load for readers who scroll at all), so 50% and 75% are more meaningful for "engaged reader" classification.

## Accessibility Note

Always include `role="progressbar"` with aria values. Screen readers don't need to announce this continuously — it's purely visual — but the semantic markup keeps it valid.
