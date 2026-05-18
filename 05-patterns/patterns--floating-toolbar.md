# Pattern: Floating Contextual Toolbar

A toolbar that appears positioned near the user's text selection and offers contextual actions (bold, link, copy). Built on the browser's `Selection` API.

## Why This Pattern

Floating toolbars reduce the distance between intent and action. Instead of reaching up to a fixed toolbar, the user acts on selected text immediately. It's the native pattern for rich text editors (Notion, Medium, Quill all use it).

## Reading the Selection

The `Selection` API gives you the range, text content, and DOM position of the current selection.

```tsx
function getSelectionInfo(): { text: string; rect: DOMRect } | null {
  const selection = window.getSelection();
  if (!selection || selection.isCollapsed || selection.rangeCount === 0) return null;

  const text = selection.toString().trim();
  if (!text) return null;

  const range = selection.getRangeAt(0);
  const rect = range.getBoundingClientRect();
  return { text, rect };
}
```

`selection.isCollapsed` is true when the cursor is placed but no text is selected — return null in that case.

## Positioning Relative to the Selection

Position the toolbar centered above the selection rectangle, clamped to the viewport.

```tsx
function useToolbarPosition(rect: DOMRect | null, toolbarWidth = 200, toolbarHeight = 40) {
  if (!rect) return null;

  const OFFSET = 8; // gap above selection
  const scrollY = window.scrollY;
  const scrollX = window.scrollX;

  let left = rect.left + scrollX + rect.width / 2 - toolbarWidth / 2;
  let top = rect.top + scrollY - toolbarHeight - OFFSET;

  // Clamp horizontally to viewport
  left = Math.max(8, Math.min(left, window.innerWidth + scrollX - toolbarWidth - 8));

  // Flip below if not enough space above
  if (top < scrollY + 8) {
    top = rect.bottom + scrollY + OFFSET;
  }

  return { left, top };
}
```

Always add scroll offset — `getBoundingClientRect()` returns viewport-relative coordinates, but absolutely positioned elements need document-relative coordinates.

## Showing and Hiding the Toolbar

Listen for `selectionchange` on the document and `mouseup` to capture the final position after drag.

```tsx
function FloatingToolbar({ containerRef, onBold, onLink, onCopy }: {
  containerRef: React.RefObject<HTMLElement>;
  onBold: () => void;
  onLink: (url: string) => void;
  onCopy: (text: string) => void;
}) {
  const [selection, setSelection] = useState<{ text: string; rect: DOMRect } | null>(null);
  const toolbarRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleSelectionChange = () => {
      // Small delay so rect is accurate after drag ends
      requestAnimationFrame(() => {
        const info = getSelectionInfo();
        // Only show toolbar for selections within our container
        if (info && containerRef.current?.contains(window.getSelection()?.anchorNode ?? null)) {
          setSelection(info);
        } else {
          setSelection(null);
        }
      });
    };

    document.addEventListener('selectionchange', handleSelectionChange);
    return () => document.removeEventListener('selectionchange', handleSelectionChange);
  }, [containerRef]);

  // Hide on click outside
  useEffect(() => {
    const handleMouseDown = (e: MouseEvent) => {
      if (!toolbarRef.current?.contains(e.target as Node)) {
        setSelection(null);
      }
    };
    document.addEventListener('mousedown', handleMouseDown);
    return () => document.removeEventListener('mousedown', handleMouseDown);
  }, []);

  const position = useToolbarPosition(selection?.rect ?? null);
  if (!selection || !position) return null;

  return (
    <div
      ref={toolbarRef}
      style={{ position: 'absolute', left: position.left, top: position.top, zIndex: 50 }}
      className="flex items-center gap-1 rounded-lg border bg-popover shadow-md p-1"
      // Prevent toolbar click from clearing selection
      onMouseDown={e => e.preventDefault()}
    >
      <ToolbarButton onClick={onBold} label="Bold">B</ToolbarButton>
      <ToolbarButton onClick={() => {
        const url = prompt('Enter URL');
        if (url) onLink(url);
      }} label="Add link">🔗</ToolbarButton>
      <ToolbarButton onClick={() => onCopy(selection.text)} label="Copy">Copy</ToolbarButton>
    </div>
  );
}
```

`onMouseDown={e => e.preventDefault()}` on the toolbar is the key trick — without it, clicking a toolbar button clears the selection before the click handler fires.

## Scope the Toolbar to a Container

Without `containerRef.current?.contains(...)`, the toolbar appears for any selection anywhere on the page, including in text inputs and other editors. Scope it to the specific element you want to enhance.

## Toolbar Actions

**Bold**: Wrap the selected text in `<strong>` by executing `document.execCommand('bold')` (deprecated but still works), or integrate with your rich text editor's command API.

**Link**: Prompt for URL, wrap selection with `<a>` tag. In a rich text editor, call the editor's link command.

**Copy**: `navigator.clipboard.writeText(selection.text)` — requires HTTPS.

```tsx
const handleCopy = async (text: string) => {
  await navigator.clipboard.writeText(text);
  toast.success('Copied to clipboard');
  setSelection(null); // dismiss toolbar after copy
};
```

## Key Rules

- `onMouseDown={e => e.preventDefault()}` on the toolbar prevents selection from clearing when toolbar is clicked
- Add scroll offset to `getBoundingClientRect()` results — they are viewport-relative, not document-relative
- Use `requestAnimationFrame` inside `selectionchange` handler — the rect is not accurate until the frame after the event
- Scope with `containerRef.contains(anchorNode)` — don't show for selections outside your target area
- Clamp position horizontally and flip vertically if near viewport edges
- Dismiss on `mousedown` outside, not `click` — dismissing on click is too late and causes flicker
