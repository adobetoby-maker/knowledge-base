# Pattern: Code / Text Diff Display

## Overview
Showing the entire file in a diff viewer buries the actual changes in unchanged context. Collapsing runs of unchanged lines (keeping 3 lines of context around each hunk) makes changes scannable without losing positional awareness. Side-by-side and unified views serve different use cases — side-by-side shows logical correspondence, unified is better on narrow screens. Syntax highlighting must run on the post-diff text, not pre-diff, because diff markers interfere with tokenizers.

## Computing the Diff

```ts
// Use a library for the diff algorithm (Myers diff) — don't implement it
// Popular: diff (npm), fast-diff, jsdiff
// Output is an array of change objects: { type: 'add'|'del'|'eq', value: string }

import { diffLines } from 'diff';

interface DiffLine {
  type: 'add' | 'del' | 'eq';
  content: string;
  lineNumberOld: number | null;
  lineNumberNew: number | null;
}

function computeLineDiff(oldText: string, newText: string): DiffLine[] {
  const changes = diffLines(oldText, newText);
  const lines: DiffLine[] = [];
  let oldLine = 1;
  let newLine = 1;

  for (const change of changes) {
    const parts = change.value.split('\n');
    // diffLines includes a trailing empty string if value ends with \n
    if (parts[parts.length - 1] === '') parts.pop();

    for (const content of parts) {
      if (change.added) {
        lines.push({ type: 'add', content, lineNumberOld: null, lineNumberNew: newLine++ });
      } else if (change.removed) {
        lines.push({ type: 'del', content, lineNumberOld: oldLine++, lineNumberNew: null });
      } else {
        lines.push({ type: 'eq', content, lineNumberOld: oldLine++, lineNumberNew: newLine++ });
      }
    }
  }
  return lines;
}
```

## Collapse Unchanged Lines

```ts
const CONTEXT_LINES = 3; // Lines of context around each changed hunk

function collapseUnchanged(lines: DiffLine[]): (DiffLine | CollapsedHunk)[] {
  const changedIndices = new Set(
    lines.flatMap((l, i) => l.type !== 'eq' ? [i] : [])
  );

  // Expand context window around each changed line
  const visible = new Set<number>();
  for (const idx of changedIndices) {
    for (let i = Math.max(0, idx - CONTEXT_LINES); i <= Math.min(lines.length - 1, idx + CONTEXT_LINES); i++) {
      visible.add(i);
    }
  }

  const result: (DiffLine | CollapsedHunk)[] = [];
  let i = 0;
  while (i < lines.length) {
    if (visible.has(i)) {
      result.push(lines[i]);
      i++;
    } else {
      // Collect contiguous hidden lines into a single collapsed hunk
      let end = i;
      while (end < lines.length && !visible.has(end)) end++;
      result.push({ type: 'collapsed', count: end - i, startIndex: i });
      i = end;
    }
  }
  return result;
}
```

## Diff Viewer Component

```tsx
function DiffViewer({ oldCode, newCode, language }: DiffViewerProps) {
  const [view, setView] = useState<'unified' | 'split'>('unified');
  const [expandedHunks, setExpandedHunks] = useState(new Set<number>());
  const lines = useMemo(() => computeLineDiff(oldCode, newCode), [oldCode, newCode]);
  const collapsed = useMemo(() => collapseUnchanged(lines), [lines]);

  return (
    <div className="diff-viewer">
      <div className="diff-viewer__toolbar">
        <div className="diff-viewer__toggle">
          <button onClick={() => setView('unified')} aria-pressed={view === 'unified'}>Unified</button>
          <button onClick={() => setView('split')} aria-pressed={view === 'split'}>Split</button>
        </div>
        <CopyChangedButton lines={lines} />
      </div>

      <div className={`diff-viewer__body diff-viewer__body--${view}`}>
        {collapsed.map((item, i) =>
          'type' in item && item.type === 'collapsed' ? (
            <CollapsedHunkRow
              key={i}
              count={item.count}
              onExpand={() => {
                setExpandedHunks(s => new Set([...s, item.startIndex]));
              }}
            />
          ) : (
            <DiffLineRow key={i} line={item as DiffLine} view={view} language={language} />
          )
        )}
      </div>
    </div>
  );
}

function CollapsedHunkRow({ count, onExpand }: { count: number; onExpand: () => void }) {
  return (
    <div className="diff-hunk-collapsed">
      <button onClick={onExpand}>... {count} unchanged lines ...</button>
    </div>
  );
}
```

## Line Rendering

```tsx
// When using a syntax highlighter that returns HTML tokens, always sanitize
// before rendering. Use DOMPurify or a trusted highlighter (e.g. highlight.js,
// Shiki) that escapes output. Never pass raw user code as unsafe HTML.

function DiffLineRow({ line, view, language }: { line: DiffLine; view: 'unified' | 'split'; language: string }) {
  // Apply syntax highlighting to the content AFTER extracting from diff
  // Highlight the raw content string, not content with diff markers prepended
  // useSyntaxHighlight should return sanitized token spans, not raw HTML
  const tokens = useSyntaxHighlight(line.content, language);

  const bgColor = {
    add: 'var(--diff-add-bg, #e6ffec)',
    del: 'var(--diff-del-bg, #ffebe9)',
    eq: 'transparent',
  }[line.type];

  if (view === 'unified') {
    return (
      <div className={`diff-line diff-line--${line.type}`} style={{ background: bgColor }}>
        <span className="diff-line__gutter old">{line.lineNumberOld ?? ''}</span>
        <span className="diff-line__gutter new">{line.lineNumberNew ?? ''}</span>
        <span className="diff-line__marker">
          {line.type === 'add' ? '+' : line.type === 'del' ? '-' : ' '}
        </span>
        {/* Render tokens as React elements — no raw HTML injection */}
        <code className="diff-line__code">{tokens}</code>
      </div>
    );
  }

  // Split view: old on left, new on right
  return (
    <div className="diff-line-split">
      <div className={`diff-cell ${line.type === 'del' || line.type === 'eq' ? `diff-cell--${line.type}` : 'diff-cell--empty'}`}>
        {(line.type === 'del' || line.type === 'eq') && (
          <>
            <span className="diff-line__gutter">{line.lineNumberOld}</span>
            <code>{tokens}</code>
          </>
        )}
      </div>
      <div className={`diff-cell ${line.type === 'add' || line.type === 'eq' ? `diff-cell--${line.type}` : 'diff-cell--empty'}`}>
        {(line.type === 'add' || line.type === 'eq') && (
          <>
            <span className="diff-line__gutter">{line.lineNumberNew}</span>
            <code>{tokens}</code>
          </>
        )}
      </div>
    </div>
  );
}
```

## Copy Changed Lines

```ts
function CopyChangedButton({ lines }: { lines: DiffLine[] }) {
  function copy() {
    const changed = lines
      .filter(l => l.type !== 'eq')
      .map(l => `${l.type === 'add' ? '+' : '-'} ${l.content}`)
      .join('\n');
    navigator.clipboard.writeText(changed);
  }
  return <button onClick={copy}>Copy changes</button>;
}
```

## Key Rules
- Collapse unchanged lines to 3-line context hunks — don't show the entire file
- Show line numbers for both old and new files — positions shift after additions/deletions
- Apply syntax highlighting to extracted content, not to diff-marker-prepended strings
- If a syntax highlighter returns HTML strings, sanitize with DOMPurify before rendering
- Prefer syntax highlighters that return React elements or token arrays (Shiki, Prism React Renderer) to avoid HTML injection entirely
- Side-by-side view: additions on right panel only, deletions on left panel only
- `+` and `-` markers use green/red background, not just text color — colorblind-safe
- Provide "Copy changed lines only" button — users frequently need just the patch content
- Use a proven diff library (Myers algorithm) — don't implement diff from scratch
