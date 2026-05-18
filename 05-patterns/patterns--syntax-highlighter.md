# Pattern: Syntax Highlighter

## Overview

Display code blocks with syntax highlighting. Two approaches: Shiki (server-side, zero client JS, best quality) and Prism/highlight.js (client-side, dynamic).

## Shiki — Server-Side (Recommended)

Shiki uses VS Code's grammar engine and themes. Runs at build time or on the server — produces static HTML with inline styles. Zero JS on the client.

```tsx
// components/CodeBlock.tsx (Server Component)
import { codeToHtml } from 'shiki'

interface CodeBlockProps {
  code: string
  lang: string
  theme?: string
}

export async function CodeBlock({ code, lang, theme = 'github-dark' }: CodeBlockProps) {
  const html = await codeToHtml(code, { lang, theme })

  // Shiki generates the HTML from your code string — it's not user-supplied HTML.
  // The code content is escaped internally by Shiki before being injected.
  return (
    <div
      className="rounded-lg overflow-auto text-sm"
      // eslint-disable-next-line react/no-danger
      dangerouslySetInnerHTML={{ __html: html }}
    />
  )
}
```

Note: Shiki's output is safe to set as innerHTML because Shiki generates it entirely — it does not accept raw HTML input. The code string you pass is escaped before being embedded. This is a well-known safe usage pattern in the Shiki documentation.

## Shiki with Copy Button

```tsx
'use client'
import { useState } from 'react'

export function CopyButton({ code }: { code: string }) {
  const [copied, setCopied] = useState(false)

  async function handleCopy() {
    await navigator.clipboard.writeText(code)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <button
      onClick={handleCopy}
      className="absolute top-3 right-3 px-2 py-1 text-xs bg-white/10 hover:bg-white/20 text-white rounded transition-colors"
    >
      {copied ? 'Copied!' : 'Copy'}
    </button>
  )
}
```

## Shiki with rehype (MDX/Markdown)

```ts
// For markdown-processed content, use rehype-pretty-code (Shiki under the hood)
import rehypePrettyCode from 'rehype-pretty-code'

const options = {
  theme: 'github-dark',
  keepBackground: false,
}

// In next.config.ts with @next/mdx
const withMDX = createMDX({
  options: {
    rehypePlugins: [[rehypePrettyCode, options]],
  },
})
```

## Prism.js — Client-Side (For Dynamic Content)

Use when code content is fetched client-side and not available at render time:

```tsx
'use client'
import { useEffect, useRef } from 'react'
import Prism from 'prismjs'
import 'prismjs/themes/prism-tomorrow.css'
import 'prismjs/components/prism-typescript'
import 'prismjs/components/prism-bash'

export function DynamicCodeBlock({ code, language }: { code: string; language: string }) {
  const ref = useRef<HTMLElement>(null)

  useEffect(() => {
    if (ref.current) {
      Prism.highlightElement(ref.current)
    }
  }, [code, language])

  return (
    <pre className="rounded-lg overflow-auto">
      <code ref={ref} className={`language-${language}`}>
        {code}
      </code>
    </pre>
  )
}
```

Prism works by setting the code as text content in a `<code>` element, then walking the DOM to apply spans. The `ref.current` approach is the safe pattern — React sets `textContent`, not innerHTML, so user code strings are escaped automatically.

Import only the language components you need — Prism is modular and the full bundle is large.

## Language Detection from Filename

```ts
function langFromFilename(filename: string): string {
  const ext = filename.split('.').pop() ?? ''
  const map: Record<string, string> = {
    ts: 'typescript', tsx: 'tsx', js: 'javascript', jsx: 'jsx',
    py: 'python', rb: 'ruby', go: 'go', rs: 'rust',
    sh: 'bash', sql: 'sql', json: 'json', yaml: 'yaml', yml: 'yaml',
    md: 'markdown', css: 'css', html: 'html',
  }
  return map[ext] ?? 'plaintext'
}
```

## Shiki vs Prism Decision

- **Shiki**: Blog posts, documentation, content known at build/render time. Best output quality. Zero client JS.
- **Prism**: Chat interfaces, user-generated code, content fetched dynamically client-side.

Never use both on the same page — conflicting CSS creates rendering artifacts.

## Line Highlighting

Shiki supports line highlighting natively with metadata:

```ts
const html = await codeToHtml(code, {
  lang: 'typescript',
  theme: 'github-dark',
  transformers: [
    transformerMetaHighlight(),
  ],
  meta: { __raw: '{1,3-5}' },  // Highlight lines 1, 3, 4, 5
})
```
