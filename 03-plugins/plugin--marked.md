# Plugin: marked (Markdown Parser)

## Overview

`marked` converts Markdown to HTML. Fast, widely used, supports GitHub Flavored Markdown (GFM). Use when you need to render user-submitted markdown, display documentation, or generate HTML from markdown strings. Always sanitize HTML output when markdown comes from user input.

## Installation

```bash
npm install marked
npm install dompurify @types/dompurify   # For sanitization
```

## Basic Usage

```ts
import { marked } from 'marked'

// Synchronous parse
const html = marked.parse('# Hello\n\nSome **bold** text')

// Async (recommended for large documents)
const html = await marked.parseAsync(content)
```

## Sanitization (Required for User Content)

Never render user-submitted markdown HTML directly — sanitize first:

```ts
import { marked } from 'marked'
import DOMPurify from 'dompurify'

function parseUserMarkdown(markdown: string): string {
  const html = marked.parse(markdown) as string
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['p', 'b', 'strong', 'i', 'em', 'ul', 'ol', 'li', 'a', 'code', 'pre', 'blockquote', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'br', 'hr'],
    ALLOWED_ATTR: ['href', 'title', 'target'],
  })
}
```

## React Component (Prefer react-markdown)

For React apps, `react-markdown` is safer because it produces a React element tree without raw HTML injection:

```tsx
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

function MarkdownRenderer({ content }: { content: string }) {
  return (
    <ReactMarkdown
      remarkPlugins={[remarkGfm]}
      className="prose prose-sm max-w-none"
      components={{
        a: ({ href, children }) => (
          <a href={href} target="_blank" rel="noopener noreferrer">{children}</a>
        ),
      }}
    >
      {content}
    </ReactMarkdown>
  )
}
```

## GFM Configuration

```ts
import { marked } from 'marked'

marked.setOptions({
  gfm: true,       // GitHub Flavored Markdown (tables, strikethrough, task lists)
  breaks: false,   // true = single newline creates <br> (like GFM)
})
```

## Custom Renderer

Override how specific elements render:

```ts
const renderer = new marked.Renderer()

// Open external links in new tab
renderer.link = ({ href, title, tokens }) => {
  const text = tokens.map(t => t.raw).join('')
  const isExternal = href?.startsWith('http')
  const attrs = isExternal ? ' target="_blank" rel="noopener noreferrer"' : ''
  const titleAttr = title ? ` title="${title}"` : ''
  return `<a href="${href}"${titleAttr}${attrs}>${text}</a>`
}

marked.use({ renderer })
```

## Server-Side (Node.js)

DOMPurify is browser-only. For server-side sanitization:

```ts
import { marked } from 'marked'
import createDOMPurify from 'dompurify'
import { JSDOM } from 'jsdom'

const { window } = new JSDOM('')
const DOMPurify = createDOMPurify(window as unknown as Window)

function sanitizeMarkdown(md: string): string {
  const html = marked.parse(md) as string
  return DOMPurify.sanitize(html)
}
```

## marked vs react-markdown vs remark

| Library | Use case |
|---|---|
| `marked` | Fast HTML string output, custom renderers |
| `react-markdown` | React component tree (no raw HTML injection needed) |
| `remark` + `rehype` | Pipeline with plugins (syntax highlighting, GFM, math) |

For React apps: prefer `react-markdown` — it produces a React element tree safely without raw HTML injection.

## Key Rules

- Sanitize user markdown output with DOMPurify always, no exceptions.
- `DOMPurify` is browser-only; use `jsdom` + `dompurify` for server-side.
- `prose` class from `@tailwindcss/typography` provides good default markdown styling.
- Don't use marked for static site content — remark/rehype ecosystem with `next-mdx-remote` is better.
