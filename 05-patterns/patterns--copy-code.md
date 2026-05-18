# Code Block with Copy Button

## Clipboard API vs execCommand Fallback

`navigator.clipboard.writeText()` is the modern, async API. It only works in secure contexts (HTTPS or localhost) and requires user interaction. For 2024+ browsers this covers virtually all cases. The `document.execCommand('copy')` fallback handles legacy environments (HTTP pages, some embedded WebViews) but is deprecated — include it only if you know your environment requires it.

```tsx
const copyToClipboard = async (text: string) => {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text)
  } else {
    // Fallback for non-secure contexts
    const textarea = document.createElement('textarea')
    textarea.value = text
    textarea.style.position = 'fixed'
    textarea.style.opacity = '0'
    document.body.appendChild(textarea)
    textarea.focus()
    textarea.select()
    document.execCommand('copy')
    document.body.removeChild(textarea)
  }
}
```

The `patterns--copy-to-clipboard.md` file covers the general clipboard pattern. This file focuses on the code block component specifically: syntax highlighting, line numbers, and the UX of copying code.

## Success Feedback: Icon Swap + Timeout

Don't use a toast for copy confirmation inside a code block — it's too heavy. Swap the copy icon to a checkmark for 2 seconds, then revert.

```tsx
const [copied, setCopied] = useState(false)

const handleCopy = async () => {
  await copyToClipboard(code)
  setCopied(true)
  setTimeout(() => setCopied(false), 2000)
}

// In JSX:
<button onClick={handleCopy} aria-label={copied ? 'Copied' : 'Copy code'}>
  {copied ? <Check className="h-4 w-4 text-green-500" /> : <Copy className="h-4 w-4" />}
</button>
```

The `aria-label` swap is important — screen readers announce the button label, so "Copied" vs "Copy code" provides the same feedback as the visual icon change.

## Syntax Highlighting: Prism vs highlight.js

**Prism.js** (`prismjs` or `react-syntax-highlighter` with Prism): Better language coverage, tree-shakeable (import only the languages you need), CSS-based themes. Preferred for production.

**highlight.js**: Easier auto-detection, good for user-submitted code where the language is unknown. Heavier bundle if you include all languages.

For most docs/blog use cases, `react-syntax-highlighter` wraps both cleanly:

```tsx
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter'
import { oneDark } from 'react-syntax-highlighter/dist/esm/styles/prism'

<SyntaxHighlighter
  language={language}
  style={oneDark}
  customStyle={{ margin: 0, borderRadius: 0 }}
  showLineNumbers={showLineNumbers}
  wrapLines={false}
>
  {code}
</SyntaxHighlighter>
```

For a lighter-weight alternative without a heavy library, use `shiki` (WASM-based, VSCode-quality themes) — but it requires async initialization and is better suited for server-side rendering.

## Line Number Display

Line numbers are a "nice to have" for long blocks (20+ lines). For short snippets they add visual noise. Make them conditional:

```tsx
// Show line numbers only for blocks with more than 8 lines
const showLineNumbers = code.split('\n').length > 8
```

When copying, the copy action should copy the code *without* the line numbers. `react-syntax-highlighter` renders line numbers as separate DOM elements — the clipboard copy reads from the raw `code` prop, not the DOM, so this is handled correctly by calling `copyToClipboard(code)` directly.

## Component Structure

```tsx
interface CodeBlockProps {
  code: string
  language?: string
  filename?: string
  showLineNumbers?: boolean
}

export function CodeBlock({ code, language = 'tsx', filename, showLineNumbers }: CodeBlockProps) {
  const [copied, setCopied] = useState(false)

  return (
    <div className="relative rounded-lg overflow-hidden border border-border">
      {/* Header bar with filename + copy button */}
      <div className="flex items-center justify-between px-4 py-2 bg-muted border-b border-border">
        <span className="text-xs text-muted-foreground font-mono">
          {filename ?? language}
        </span>
        <button onClick={handleCopy} className="...">
          {copied ? <Check /> : <Copy />}
        </button>
      </div>
      {/* Highlighted code */}
      <div className="overflow-x-auto text-sm">
        <SyntaxHighlighter language={language} style={oneDark} ...>
          {code.trim()}
        </SyntaxHighlighter>
      </div>
    </div>
  )
}
```

Always `.trim()` the code string before passing to the highlighter and copying — leading/trailing newlines cause the first line to appear blank and add a stray newline when pasted.

## Key Rules

- Copy from the raw `code` prop, not from the DOM — DOM-scraped text includes line number characters and syntax markup
- `navigator.clipboard.writeText` only works in secure contexts (HTTPS) — include the `execCommand` fallback only when HTTP is a real requirement, not by default
- Swap icon + revert via `setTimeout`, not toast — toasts are too disruptive for a single-element action
- Update `aria-label` alongside the icon swap — screen reader users need the same "Copied" confirmation as visual users
- `.trim()` code before highlighting — extra whitespace creates empty leading lines in both the rendered block and pasted output
