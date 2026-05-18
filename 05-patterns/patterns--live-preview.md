# Pattern: Live Preview Pane

A split-pane layout where an editor updates a preview in real time. Covers debouncing expensive renders, iframe sandbox for HTML preview, error boundaries, and the split-pane layout.

## Why Debounce is Critical

Updating the preview on every keystroke triggers potentially expensive operations: parsing markdown, running code transformations, or re-rendering complex layouts. At 100ms per operation and 10 keystrokes/sec, you've used all CPU time just on previews. Debounce to 300–500ms — the user won't notice the lag but the CPU will thank you.

```tsx
import { useDeferredValue } from 'react';
// OR use a manual debounce hook

function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}

function LivePreview() {
  const [source, setSource] = useState('');
  const debouncedSource = useDebounce(source, 350);
  // Only the debounced value drives the preview
  return (
    <SplitPane>
      <Editor value={source} onChange={setSource} />
      <Preview source={debouncedSource} />
    </SplitPane>
  );
}
```

React 18's `useDeferredValue` is an alternative — it defers rendering until the browser is idle rather than a fixed timeout. Use `useDeferredValue` for pure rendering work; use a debounce hook when the expensive work happens outside React (fetch calls, library parsing).

## Split-Pane Layout

```tsx
function SplitPane({ children }: { children: [React.ReactNode, React.ReactNode] }) {
  const [splitPct, setSplitPct] = useState(50);
  const containerRef = useRef<HTMLDivElement>(null);

  const handleDividerDrag = (e: React.MouseEvent) => {
    e.preventDefault();
    const container = containerRef.current;
    if (!container) return;

    const onMouseMove = (e: MouseEvent) => {
      const rect = container.getBoundingClientRect();
      const pct = ((e.clientX - rect.left) / rect.width) * 100;
      setSplitPct(Math.max(20, Math.min(80, pct))); // clamp 20%–80%
    };
    const onMouseUp = () => {
      document.removeEventListener('mousemove', onMouseMove);
      document.removeEventListener('mouseup', onMouseUp);
    };
    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
  };

  return (
    <div ref={containerRef} className="flex h-full overflow-hidden">
      <div style={{ width: `${splitPct}%` }} className="overflow-auto">{children[0]}</div>
      <div
        className="w-1 bg-border cursor-col-resize hover:bg-primary/50 flex-shrink-0"
        onMouseDown={handleDividerDrag}
      />
      <div style={{ width: `${100 - splitPct}%` }} className="overflow-auto">{children[1]}</div>
    </div>
  );
}
```

Clamp the split between 20% and 80% to prevent panels from becoming unusable.

## iframe Sandbox for HTML Preview

When the preview renders arbitrary HTML (as in a code playground or email template editor), use an iframe with `sandbox` to prevent:
- Script execution (`allow-scripts` off by default)
- Form submissions
- Navigation away from the parent
- Access to parent `window`

```tsx
function HtmlPreview({ html }: { html: string }) {
  const iframeRef = useRef<HTMLIFrameElement>(null);

  useEffect(() => {
    const iframe = iframeRef.current;
    if (!iframe) return;

    // srcdoc is safer than writing to contentDocument directly
    iframe.srcdoc = html;
  }, [html]);

  return (
    <iframe
      ref={iframeRef}
      sandbox="allow-same-origin"  // NO allow-scripts unless you need JS execution
      className="w-full h-full border-0"
      title="Preview"
    />
  );
}
```

`srcdoc` replaces the entire iframe document. For markdown previews (not arbitrary HTML), render to a React component instead — no iframe needed.

## Error Boundary Around the Preview

Preview errors (invalid markdown, broken component, syntax error) should never crash the editor. Wrap the preview pane in an error boundary.

```tsx
class PreviewErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { hasError: boolean; error: Error | null }
> {
  state = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidUpdate(prevProps: { children: React.ReactNode }) {
    // Reset on new content — the new content might be valid
    if (prevProps.children !== this.props.children) {
      this.setState({ hasError: false, error: null });
    }
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="p-4 text-sm text-destructive font-mono bg-destructive/5">
          <p className="font-semibold mb-1">Preview error</p>
          <pre className="whitespace-pre-wrap text-xs">{this.state.error?.message}</pre>
        </div>
      );
    }
    return this.props.children;
  }
}
```

The `componentDidUpdate` reset is essential — without it, the error state persists after the user fixes the problem.

## Showing Stale Indicator

While the debounce is pending, indicate that the preview is stale:

```tsx
function Preview({ source, debouncedSource }: { source: string; debouncedSource: string }) {
  const isStale = source !== debouncedSource;
  return (
    <div className="relative h-full">
      {isStale && (
        <div className="absolute top-2 right-2 text-xs text-muted-foreground bg-background/80 px-2 py-1 rounded">
          Updating…
        </div>
      )}
      <PreviewErrorBoundary>
        <ActualPreview source={debouncedSource} />
      </PreviewErrorBoundary>
    </div>
  );
}
```

## Key Rules

- Debounce at 300–500ms before expensive preview computation; `useDeferredValue` for pure React rendering
- Clamp the divider split between 20%–80% to prevent panels from collapsing
- Use `iframe sandbox` for arbitrary HTML — never render user-supplied HTML directly in the React tree
- Use `srcdoc` not `src="about:blank"` + `contentDocument.write()` — it's simpler and avoids security issues
- Error boundaries must reset on `componentDidUpdate` when children change — otherwise a fixed error stays broken
- Show a "Updating…" indicator during the debounce period so the user knows the preview is catching up
