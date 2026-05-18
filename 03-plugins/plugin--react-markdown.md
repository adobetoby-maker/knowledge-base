# Plugin: react-markdown

## What It Is

Renders Markdown as React components. Used for: blog post bodies, AI response rendering, user-created rich text (when stored as Markdown). Sanitization required when rendering user-submitted content.

## Installation

```bash
npm install react-markdown
# For syntax highlighting
npm install react-syntax-highlighter
npm install --save-dev @types/react-syntax-highlighter
# For GFM (tables, strikethrough, task lists)
npm install remark-gfm
```

## Basic Usage

```tsx
import Markdown from 'react-markdown'

function BlogPost({ content }: { content: string }) {
  return (
    <div className="prose prose-gray max-w-none">
      <Markdown>{content}</Markdown>
    </div>
  )
}
```

`prose` class from `@tailwindcss/typography` styles all Markdown elements with sensible defaults. Always use it.

## With GFM (GitHub-Flavored Markdown)

```tsx
import Markdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

function ArticleBody({ markdown }: { markdown: string }) {
  return (
    <article className="prose prose-gray max-w-none">
      <Markdown remarkPlugins={[remarkGfm]}>
        {markdown}
      </Markdown>
    </article>
  )
}
```

GFM adds: tables, task lists `- [x]`, strikethrough `~~text~~`, autolinks, footnotes.

## With Syntax Highlighting

```tsx
import Markdown from 'react-markdown'
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter'
import { oneDark } from 'react-syntax-highlighter/dist/esm/styles/prism'
import remarkGfm from 'remark-gfm'

const components = {
  code({ node, inline, className, children, ...props }: any) {
    const langMatch = (className || '').match(/language-(\w+)/)
    return !inline && langMatch ? (
      <SyntaxHighlighter
        style={oneDark}
        language={langMatch[1]}
        PreTag="div"
        {...props}
      >
        {String(children).replace(/\n$/, '')}
      </SyntaxHighlighter>
    ) : (
      <code className="bg-gray-100 text-gray-800 px-1 rounded text-sm" {...props}>
        {children}
      </code>
    )
  },
}

export function MarkdownRenderer({ content }: { content: string }) {
  return (
    <div className="prose prose-gray max-w-none">
      <Markdown
        remarkPlugins={[remarkGfm]}
        components={components}
      >
        {content}
      </Markdown>
    </div>
  )
}
```

## Custom Link Renderer

```tsx
const components = {
  a({ href, children }: any) {
    const isExternal = href?.startsWith('http')
    return (
      <a
        href={href}
        target={isExternal ? '_blank' : undefined}
        rel={isExternal ? 'noopener noreferrer' : undefined}
        className="text-blue-600 hover:underline"
      >
        {children}
      </a>
    )
  },
}
```

## Sanitization for User Content

`react-markdown` renders Markdown — not raw HTML. It does NOT execute script tags or inline event handlers. Raw HTML in Markdown is stripped by default.

If you allow raw HTML via `rehype-raw`:
```bash
npm install rehype-raw rehype-sanitize
```

```tsx
import rehypeRaw from 'rehype-raw'
import rehypeSanitize from 'rehype-sanitize'  // Required with rehype-raw

<Markdown rehypePlugins={[rehypeRaw, rehypeSanitize]}>
  {userContent}
</Markdown>
```

If not using `rehype-raw`, standard `react-markdown` is safe for user-submitted content — raw HTML is stripped.

## AI Response Rendering

```tsx
'use client'
import Markdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

function AIResponseBubble({ content, isLoading }: { content: string; isLoading: boolean }) {
  return (
    <div className="bg-gray-50 rounded-xl p-4 max-w-3xl">
      <div className="prose prose-sm prose-gray max-w-none">
        <Markdown remarkPlugins={[remarkGfm]}>
          {content}
        </Markdown>
      </div>
      {isLoading && (
        <span className="inline-block w-2 h-4 bg-gray-400 animate-pulse ml-1 align-middle" />
      )}
    </div>
  )
}
```

## Tailwind Typography Setup

```bash
npm install @tailwindcss/typography
```

```ts
// tailwind.config.ts
plugins: [require('@tailwindcss/typography')]
```

Useful modifiers:
- `prose` — default styling
- `prose-sm` — smaller text  
- `prose-lg` — larger text
- `prose-gray` — gray headings
- `prose-invert` — dark mode (white on dark)
- `max-w-none` — remove max-width constraint

## When NOT to Use

- Content is only simple text with no Markdown formatting — use a plain `<p>` tag
- You need collaborative editing — use a proper editor like TipTap or Lexical
- Content is already HTML (not Markdown) — render via TipTap's `generateHTML` or similar safe HTML-rendering approach
