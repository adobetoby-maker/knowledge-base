# Pattern: Code Snippet Display Block

## Overview
A code block is one of the most-used elements in developer-facing products, documentation sites, and AI chat interfaces. It requires three capabilities that plain `<pre>` elements lack: syntax highlighting for readability, copy-to-clipboard for usability, and controlled overflow for long lines. The choice between server-side (Shiki) and client-side (Prism) syntax highlighting is architectural: Shiki produces zero-runtime HTML; Prism runs in the browser and must be code-split carefully.

## Implementation

### Server-Side (SSR/SSG) with Shiki
```ts
// lib/highlight.ts — runs at build time or in Server Components
import { codeToHtml } from 'shiki';

export async function highlight(code: string, lang: string): Promise<string> {
  // codeToHtml output is safe: it comes from our code, not user input
  return codeToHtml(code, {
    lang,
    theme: 'github-dark',
  });
}
```

```tsx
// Server Component
async function CodeBlock({ code, lang, showLineNumbers = false }) {
  const html = await highlight(code, lang);
  return (
    <CodeShell
      html={html}
      lang={lang}
      code={code}
      showLineNumbers={showLineNumbers}
    />
  );
}
```

### Client Shell Component
```tsx
'use client';

function CodeShell({
  html,    // Trusted: generated server-side from our own highlighter
  lang,
  code,
  showLineNumbers,
}: {
  html: string;
  lang: string;
  code: string;
  showLineNumbers: boolean;
}) {
  const [copied, setCopied] = useState(false);
  const [wordWrap, setWordWrap] = useState(false);

  const copy = async () => {
    await navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div style={{ position: 'relative', borderRadius: 8, overflow: 'hidden' }}>
      {/* Language badge */}
      <span style={{
        position: 'absolute', top: 8, right: 88,
        fontSize: 11, fontFamily: 'monospace',
        opacity: 0.6, textTransform: 'lowercase',
      }}>
        {lang}
      </span>

      {/* Word-wrap toggle */}
      <button
        onClick={() => setWordWrap(w => !w)}
        title={wordWrap ? 'Disable word wrap' : 'Enable word wrap'}
        style={{ position: 'absolute', top: 6, right: 44 }}
        aria-pressed={wordWrap}
      >
        Wrap
      </button>

      {/* Copy button */}
      <button
        onClick={copy}
        aria-label={copied ? 'Copied' : 'Copy code'}
        style={{ position: 'absolute', top: 6, right: 8 }}
      >
        {copied ? 'Copied' : 'Copy'}
      </button>

      {/* Shiki output is from our own server, not user input — acceptable use */}
      {/* For user-submitted code, always sanitize with DOMPurify before rendering */}
      <div
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={{ __html: html }}
        style={{
          maxHeight: 480,
          overflowY: 'auto',
          overflowX: wordWrap ? 'hidden' : 'auto',
        }}
        data-word-wrap={wordWrap}
      />
    </div>
  );
}
```

### CSS
```css
[data-word-wrap="true"] pre {
  white-space: pre-wrap;
  word-break: break-all;
}

[data-word-wrap="false"] pre {
  white-space: pre;
}
```

### Optional: Line Numbers via Shiki Transformers
```ts
import { transformerNotationLineNumbers } from '@shikiijs/transformers';

codeToHtml(code, {
  lang,
  theme: 'github-dark',
  transformers: [transformerNotationLineNumbers()],
});
```

### Client-Side Fallback (Prism)
Use when Shiki is not viable (pure client rendering, dynamic code generation):
```tsx
import { useEffect, useRef } from 'react';

function PrismBlock({ code, lang }) {
  const ref = useRef<HTMLElement>(null);

  useEffect(() => {
    import('prismjs').then(Prism => {
      import(`prismjs/components/prism-${lang}`).then(() => {
        if (ref.current) Prism.highlightElement(ref.current);
      });
    });
  }, [code, lang]);

  return <pre><code ref={ref} className={`language-${lang}`}>{code}</code></pre>;
}
```

## Key Rules
- Prefer Shiki for server-rendered or statically generated code — zero client JS, better theming.
- Never send the Shiki bundle to the client — it's large; it belongs in a Server Component or build step.
- When rendering user-submitted code with innerHTML, sanitize first with DOMPurify or similar before passing to the highlighter. Shiki's output from trusted code is safe; the input may not be.
- The copy button must reset to "Copy" after 2 seconds — shorter feels uncertain, longer is annoying.
- Clip max-height at ~480px — showing 500 lines inline breaks page flow.
- Word-wrap is a user preference toggle, not a default — code authors write long lines intentionally.
- Always provide `aria-label` on the copy button that reflects the current state — screen readers won't read the visual change otherwise.
