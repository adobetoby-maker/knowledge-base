# plugin--highlight-js — Syntax Highlighting

## What It Is
highlight.js is a zero-dependency syntax highlighter that works in the browser and Node.js. It detects language automatically or accepts an explicit hint, and outputs HTML with semantic class names that CSS themes color.

## Auto-detection vs Explicit Language

```ts
import hljs from 'highlight.js';

// Auto-detect — convenient but slow on large blocks, sometimes wrong
hljs.highlightElement(el);

// Explicit — always prefer this when the language is known
el.removeAttribute('data-highlighted');
el.className = 'language-typescript';
hljs.highlightElement(el);
```

**Why explicit is better**: Auto-detection runs the input through every registered language and picks the highest confidence score. On 500-line files this takes measurable time. When rendering markdown with fenced code blocks, the language tag is available — use it.

For programmatic use without DOM:

```ts
const result = hljs.highlight(code, { language: 'typescript' });
// Always sanitize with DOMPurify before rendering result.value into the DOM
```

## Theme CSS Imports

```ts
// In your entry file or component
import 'highlight.js/styles/github.css';         // light
import 'highlight.js/styles/github-dark.css';    // dark
import 'highlight.js/styles/atom-one-dark.css';  // popular dark
```

For dark/light mode switching, import both and toggle with a class on `<html>`, or use a CSS media query approach with `@media (prefers-color-scheme: dark)`.

**Don't import styles inside a component file** that mounts/unmounts — this causes flash-of-unstyled-content on remount in some bundlers. Import once at the app entry point.

## Line Numbers via Plugin

highlight.js dropped native line number support. Use `highlightjs-line-numbers.js`:

```ts
import hljs from 'highlight.js';
import lineNumbers from 'highlightjs-line-numbers.js';

hljs.addPlugin(lineNumbers);
hljs.highlightAll();
```

Or implement them in CSS with a `counter` on the `<code>` element — cleaner and no extra JS.

## Registering Only Needed Languages

The default import bundles all ~190 languages (~800KB minified). Import only what you need:

```ts
import hljs from 'highlight.js/lib/core';
import typescript from 'highlight.js/lib/languages/typescript';
import json from 'highlight.js/lib/languages/json';
import bash from 'highlight.js/lib/languages/bash';

hljs.registerLanguage('typescript', typescript);
hljs.registerLanguage('json', json);
hljs.registerLanguage('bash', bash);
```

This is the single biggest bundle-size win available with highlight.js.

## Performance — Virtual Lists

**Never call `hljs.highlightElement()` inside a virtual list row renderer.** Highlighting is synchronous and CPU-heavy. In a list of 10,000 items rendered to a virtual window of 20, you're fine. But if your virtual list component calls the renderer for every item during scroll events (some do), you'll drop frames.

Correct pattern: highlight once, cache the result string, then sanitize with DOMPurify before rendering:

```ts
import DOMPurify from 'dompurify';

const cache = new Map<string, string>();

function getHighlighted(code: string, lang: string): string {
  const key = `${lang}:${code}`;
  if (!cache.has(key)) {
    const raw = hljs.highlight(code, { language: lang }).value;
    cache.set(key, DOMPurify.sanitize(raw));
  }
  return cache.get(key)!;
}
```

## React Integration

Use the programmatic API — not `highlightAll()` which scans the entire DOM. Sanitize with DOMPurify before rendering into the page. Use `hljs.highlightElement()` via a ref to let the library handle DOM insertion safely:

```tsx
function CodeBlock({ code, language }: { code: string; language: string }) {
  const ref = useRef<HTMLElement>(null);

  useEffect(() => {
    if (!ref.current) return;
    ref.current.removeAttribute('data-highlighted');
    ref.current.className = `language-${language}`;
    hljs.highlightElement(ref.current);
  }, [code, language]);

  return (
    <pre>
      <code ref={ref}>{code}</code>
    </pre>
  );
}
```

This avoids raw HTML insertion entirely — highlight.js mutates the DOM element directly.

## Key Rules
- Always specify language explicitly when known — auto-detection is a fallback, not the default.
- Import `highlight.js/lib/core` and register only needed languages to avoid 800KB bundle bloat.
- Import theme CSS once at app entry, not inside components.
- Cache highlighted output; never re-highlight inside virtual list row renderers.
- In React, use `highlightElement()` on a ref rather than injecting raw HTML strings.
- When using the programmatic API to get an HTML string, always pass it through DOMPurify before any DOM insertion.
