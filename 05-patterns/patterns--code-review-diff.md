# Pattern: Side-by-Side Code Diff Viewer

## Why This Pattern Matters

A diff viewer is only useful if it's scannable. Line numbers, clear color coding, and inline comment anchoring are not cosmetic choices — they're the functional core. A diff without line numbers forces reviewers to count manually. Comments that aren't anchored to lines float and lose context when the diff updates.

## Computing Hunks with the `diff` Library

Use the `diff` package to compute structured hunks rather than rendering raw unified diff strings.

```ts
import { diffLines } from 'diff';

const changes = diffLines(originalCode, modifiedCode);
// Each change: { value: string, added?: boolean, removed?: boolean, count?: number }
```

Map changes to a flat line array for both sides, tracking which lines are additions, removals, or unchanged. This is necessary for side-by-side rendering because both panes need independent line numbers.

```ts
function buildSideBySideLines(changes: Change[]) {
  const left: Line[] = [], right: Line[] = [];
  let leftN = 1, rightN = 1;
  for (const change of changes) {
    const lines = change.value.split('\n').filter((_, i, a) => i < a.length - 1 || a[i]);
    if (change.removed) {
      lines.forEach(text => { left.push({ n: leftN++, text, type: 'removed' }); right.push({ type: 'empty' }); });
    } else if (change.added) {
      lines.forEach(text => { left.push({ type: 'empty' }); right.push({ n: rightN++, text, type: 'added' }); });
    } else {
      lines.forEach(text => { left.push({ n: leftN++, text, type: 'unchanged' }); right.push({ n: rightN++, text, type: 'unchanged' }); });
    }
  }
  return { left, right };
}
```

## Line-Level Highlighting

Color rule: added = green background, removed = red background, unchanged = transparent. Use subtle colors — `bg-green-50` / `bg-red-50` in light mode. The line number gutter uses a slightly deeper shade of the same color for added/removed lines.

```tsx
const lineClass = {
  added: 'bg-green-50 dark:bg-green-950',
  removed: 'bg-red-50 dark:bg-red-950',
  unchanged: '',
  empty: 'bg-muted/30',
};
```

Never use bold text to indicate changes — color alone suffices and bold disrupts code readability.

## Line Numbers on Both Sides

Both the left (original) and right (modified) panes have independent line number columns. Empty rows (where the other side has an insertion) show a blank gutter, not a number. Keep gutter width fixed (`w-12 text-right pr-3 select-none text-muted-foreground text-xs`).

Use a monospace font for both gutter and code content. Sync scroll vertically between both panes — use a shared `onScroll` handler that sets `scrollTop` on the other pane.

## Inline Comment Threads

Anchor comments to a specific line on a specific side (left=original, right=modified). Store comment position as `{ side: 'left' | 'right', lineNumber: number }`.

Render a comment indicator icon in the gutter of commented lines. Clicking the gutter of any line opens an inline comment compose box between that row and the next. Existing thread comments expand inline — no separate panel.

```tsx
<tr key={i}>
  <td className="gutter">{line.n || ''}</td>
  <td className="code">
    <code>{line.text}</code>
    <button
      className="opacity-0 group-hover:opacity-100 absolute right-2"
      onClick={() => openCommentThread(side, line.n)}
    >+</button>
  </td>
</tr>
{threadForLine && <CommentThread thread={threadForLine} />}
```

## Collapsing Unchanged Sections

Long diffs with many unchanged lines are unreadable. Collapse runs of ≥5 unchanged lines into a "Show N lines" expander. Reveal them inline when clicked — don't re-render the entire diff.

## Key Rules

- Use `diffLines` from the `diff` library, not string manipulation
- Side-by-side requires independent left/right line number sequences
- Empty rows in the gutter show blank, not "0" or a dash
- Added = green, removed = red — apply to both gutter and code cell
- Inline comments anchor to `{ side, lineNumber }`, not character offset
- Sync vertical scroll between panes on the same `onScroll` event
- Collapse runs of ≥5 unchanged lines with an expand control
