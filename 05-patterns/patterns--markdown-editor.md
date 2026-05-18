# Pattern: Markdown Editor

## Overview

A markdown editor with live preview. The key decisions: use a textarea-based editor (simple, accessible, no dependencies) or a rich editor library like CodeMirror/Monaco (feature-rich but heavy). For most product use cases, the split-pane textarea + preview is the right choice. Add toolbar buttons for common formatting.

## Split-Pane Editor

```tsx
import { useState, useRef, useEffect } from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

interface MarkdownEditorProps {
  value: string
  onChange: (value: string) => void
  placeholder?: string
}

export function MarkdownEditor({ value, onChange, placeholder }: MarkdownEditorProps) {
  const [tab, setTab] = useState<'write' | 'preview'>('write')
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  return (
    <div className="border border-gray-200 rounded-lg overflow-hidden">
      {/* Toolbar */}
      <div className="flex items-center gap-1 px-3 py-2 border-b border-gray-200 bg-gray-50">
        <ToolbarButton icon="B" title="Bold" onClick={() => insertFormatting('**', '**', textareaRef, onChange)} />
        <ToolbarButton icon="I" title="Italic" onClick={() => insertFormatting('_', '_', textareaRef, onChange)} />
        <ToolbarButton icon='`' title="Code" onClick={() => insertFormatting('`', '`', textareaRef, onChange)} />
        <div className="ml-auto flex">
          <button onClick={() => setTab('write')} className={tab === 'write' ? 'bg-white shadow-sm px-3 py-1 text-sm rounded' : 'px-3 py-1 text-sm text-gray-500'}>Write</button>
          <button onClick={() => setTab('preview')} className={tab === 'preview' ? 'bg-white shadow-sm px-3 py-1 text-sm rounded' : 'px-3 py-1 text-sm text-gray-500'}>Preview</button>
        </div>
      </div>

      {tab === 'write' ? (
        <textarea
          ref={textareaRef}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className="w-full min-h-48 p-4 font-mono text-sm resize-y focus:outline-none"
          onKeyDown={(e) => handleTabKey(e, onChange)}
        />
      ) : (
        <div className="min-h-48 p-4 prose prose-sm max-w-none">
          {value
            ? <ReactMarkdown remarkPlugins={[remarkGfm]}>{value}</ReactMarkdown>
            : <p className="text-gray-400 italic">Nothing to preview</p>
          }
        </div>
      )}
    </div>
  )
}
```

`react-markdown` renders markdown as React elements — not raw HTML strings — so user content is safe from XSS injection by default.

## Toolbar Formatting Helpers

```ts
function insertFormatting(
  before: string,
  after: string,
  ref: React.RefObject<HTMLTextAreaElement>,
  onChange: (v: string) => void
) {
  const el = ref.current
  if (!el) return
  const { selectionStart, selectionEnd, value } = el
  const selected = value.slice(selectionStart, selectionEnd)
  const newValue =
    value.slice(0, selectionStart) +
    before + selected + after +
    value.slice(selectionEnd)

  onChange(newValue)

  // Restore cursor position after React re-render
  requestAnimationFrame(() => {
    el.focus()
    if (selected) {
      el.setSelectionRange(selectionStart + before.length, selectionEnd + before.length)
    } else {
      const cursor = selectionStart + before.length
      el.setSelectionRange(cursor, cursor)
    }
  })
}

function insertLine(
  prefix: string,
  ref: React.RefObject<HTMLTextAreaElement>,
  onChange: (v: string) => void
) {
  const el = ref.current
  if (!el) return
  const { selectionStart, value } = el
  const lineStart = value.lastIndexOf('\n', selectionStart - 1) + 1
  const newValue = value.slice(0, lineStart) + prefix + value.slice(lineStart)
  onChange(newValue)
  requestAnimationFrame(() => {
    el.focus()
    el.setSelectionRange(selectionStart + prefix.length, selectionStart + prefix.length)
  })
}
```

## Tab Key Indentation

```ts
function handleTabKey(
  e: React.KeyboardEvent<HTMLTextAreaElement>,
  onChange: (v: string) => void
) {
  if (e.key !== 'Tab') return
  e.preventDefault()
  const el = e.currentTarget
  const { selectionStart, selectionEnd, value } = el
  const newValue = value.slice(0, selectionStart) + '  ' + value.slice(selectionEnd)
  onChange(newValue)
  requestAnimationFrame(() => {
    el.setSelectionRange(selectionStart + 2, selectionStart + 2)
  })
}
```

## Auto-Grow Textarea Height

```ts
function useAutoGrow(ref: React.RefObject<HTMLTextAreaElement>, value: string) {
  useEffect(() => {
    const el = ref.current
    if (!el) return
    el.style.height = 'auto'
    el.style.height = `${el.scrollHeight}px`
  }, [value])
}
```

## Rendering Safely with HTML Passthrough

If markdown source is trusted (from your own CMS, not user input) and needs HTML passthrough:

```tsx
import rehypeRaw from 'rehype-raw'
import rehypeSanitize from 'rehype-sanitize'

// rehypeSanitize must come AFTER rehypeRaw to strip any injected HTML
<ReactMarkdown rehypePlugins={[rehypeRaw, rehypeSanitize]}>
  {trustedCmsContent}
</ReactMarkdown>
```

For user-generated content: never enable `rehype-raw`. The default react-markdown behavior (React elements only) is safe.

## Key Rules

- `requestAnimationFrame` around cursor restoration is required because React's re-render happens asynchronously — setting `selectionRange` synchronously fires before the DOM updates.
- Tab key in textarea must call `e.preventDefault()` or focus moves to the next form element.
- `react-markdown` with `remarkGfm` handles tables, strikethrough, task lists, and autolinks without configuration.
- Split write/preview tabs (not side-by-side): side-by-side requires scroll-sync which is painful to implement correctly.
- For user-generated content: never enable HTML passthrough. For CMS-controlled content: always pair `rehype-raw` with `rehype-sanitize`.
