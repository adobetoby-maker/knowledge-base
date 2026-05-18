# Pattern: File Manager Grid

## Overview
A file manager must support the same mental model as a desktop OS: click to select, double-click to open, shift-click for ranges, right-click for context. Deviating from these conventions forces relearning on something users already know. View preference (grid vs list) is a user preference that should persist — toggling it every session is friction. Keyboard support (Delete to trash, Enter to open) is essential for power users.

## Implementation

### View Toggle with Persistence
```tsx
type ViewMode = 'grid' | 'list'
const VIEW_KEY = 'file-manager-view'

function useViewMode() {
  const [view, setView] = useState<ViewMode>(
    () => (localStorage.getItem(VIEW_KEY) as ViewMode) ?? 'grid'
  )
  const toggle = (mode: ViewMode) => {
    setView(mode)
    localStorage.setItem(VIEW_KEY, mode)
  }
  return { view, toggle }
}
```

### Selection State
```tsx
function useFileSelection(files: FileItem[]) {
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const lastSelected = useRef<string | null>(null)

  const handleClick = (id: string, event: React.MouseEvent) => {
    if (event.shiftKey && lastSelected.current) {
      // Range select
      const ids = files.map((f) => f.id)
      const a = ids.indexOf(lastSelected.current)
      const b = ids.indexOf(id)
      const range = ids.slice(Math.min(a, b), Math.max(a, b) + 1)
      setSelected((prev) => new Set([...prev, ...range]))
    } else if (event.metaKey || event.ctrlKey) {
      // Toggle individual
      setSelected((prev) => {
        const next = new Set(prev)
        next.has(id) ? next.delete(id) : next.add(id)
        return next
      })
    } else {
      setSelected(new Set([id]))
    }
    lastSelected.current = id
  }

  const clearSelection = () => setSelected(new Set())

  return { selected, handleClick, clearSelection }
}
```

### Keyboard Handlers
```tsx
function useFileKeyboard({
  files,
  selected,
  onOpen,
  onTrash,
}: {
  files: FileItem[]
  selected: Set<string>
  onOpen: (id: string) => void
  onTrash: (ids: string[]) => void
}) {
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Delete' || e.key === 'Backspace') {
        if (selected.size > 0) {
          e.preventDefault()
          onTrash([...selected])
        }
      }
      if (e.key === 'Enter') {
        if (selected.size === 1) {
          onOpen([...selected][0])
        }
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [selected, onOpen, onTrash])
}
```

### Context Menu
```tsx
function FileContextMenu({
  file,
  onOpen,
  onRename,
  onTrash,
  onDownload,
}: ContextMenuProps) {
  return (
    <menu
      role="menu"
      className="absolute z-50 bg-white border shadow-lg rounded-md py-1 min-w-40"
    >
      {[
        { label: 'Open', action: () => onOpen(file.id), shortcut: '↵' },
        { label: 'Rename', action: () => onRename(file.id), shortcut: 'F2' },
        { label: 'Download', action: () => onDownload(file.id) },
        null, // separator
        { label: 'Move to Trash', action: () => onTrash([file.id]), shortcut: '⌫', danger: true },
      ].map((item, i) =>
        item === null ? (
          <hr key={i} className="my-1 border-gray-200" />
        ) : (
          <li key={item.label} role="none">
            <button
              role="menuitem"
              onClick={item.action}
              className={[
                'w-full flex justify-between px-3 py-1.5 text-sm hover:bg-gray-100',
                item.danger ? 'text-red-600' : 'text-gray-800',
              ].join(' ')}
            >
              <span>{item.label}</span>
              {item.shortcut && (
                <span className="text-gray-400 text-xs ml-4">{item.shortcut}</span>
              )}
            </button>
          </li>
        )
      )}
    </menu>
  )
}
```

### File Item (Grid)
```tsx
function FileGridItem({
  file,
  selected,
  onClick,
  onDoubleClick,
  onContextMenu,
}: FileItemProps) {
  return (
    <div
      role="option"
      aria-selected={selected}
      tabIndex={0}
      onClick={onClick}
      onDoubleClick={onDoubleClick}
      onContextMenu={onContextMenu}
      className={[
        'flex flex-col items-center gap-2 p-3 rounded-lg cursor-pointer select-none',
        selected ? 'bg-blue-100 ring-2 ring-blue-400' : 'hover:bg-gray-100',
      ].join(' ')}
    >
      <FileIcon type={file.type} className="w-12 h-12" />
      <span className="text-xs text-center truncate max-w-full">{file.name}</span>
      <span className="text-xs text-gray-400">{formatFileSize(file.size)}</span>
    </div>
  )
}
```

### Drag to Folder
```tsx
// Use HTML5 drag API — no library needed for basic drag-to-folder
function useDragToFolder(onMove: (fileId: string, folderId: string) => void) {
  return {
    getDragProps: (fileId: string) => ({
      draggable: true,
      onDragStart: (e: React.DragEvent) => e.dataTransfer.setData('fileId', fileId),
    }),
    getDropProps: (folderId: string) => ({
      onDragOver: (e: React.DragEvent) => e.preventDefault(),
      onDrop: (e: React.DragEvent) => {
        const fileId = e.dataTransfer.getData('fileId')
        if (fileId) onMove(fileId, folderId)
      },
    }),
  }
}
```

## Key Rules
- Single-click selects, double-click opens — never swap these; they match OS convention
- Shift+click for range selection is required; Ctrl/Cmd+click for individual toggle is required
- View mode (grid/list) persists in `localStorage` — never reset it on navigation
- Right-click opens a context menu; never use it for selection only
- Delete key moves to trash (reversible), not permanent delete without confirmation
- Show file size and modified date in list view; abbreviate in grid view (size only)
- `role="listbox"` on container + `role="option"` + `aria-selected` on each item — screen readers understand list selection
- Drag-to-folder must show visual drop target indicator while dragging (ring or background change on the folder)
