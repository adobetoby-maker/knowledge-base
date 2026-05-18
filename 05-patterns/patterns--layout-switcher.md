# Pattern: Grid/List View Layout Toggle

## Problem

Users expect to switch between grid (card) and list (row) views on content-heavy pages. The preference should persist, the toggle buttons need proper ARIA state, layout transitions should be smooth, and the default should be sensible for the device type — mobile users generally prefer list view.

## Persistence with localStorage

```ts
type LayoutView = 'grid' | 'list';

function useLayoutView(storageKey = 'layout-view'): [LayoutView, (v: LayoutView) => void] {
  const [view, setViewState] = useState<LayoutView>(() => {
    // Default based on device type: mobile → list, desktop → grid
    const savedView = typeof window !== 'undefined'
      ? (localStorage.getItem(storageKey) as LayoutView | null)
      : null;

    if (savedView) return savedView;
    return window.innerWidth < 768 ? 'list' : 'grid';
  });

  function setView(v: LayoutView) {
    setViewState(v);
    localStorage.setItem(storageKey, v);
  }

  return [view, setView];
}
```

WHY default to list on mobile: grid cards in a 2-column layout on a 375px screen are often too cramped to read. List view provides a clear single-column layout that works better for touch targets and reading.

## Toggle Button Component

```tsx
function LayoutToggle({ view, onChange }: { view: LayoutView; onChange: (v: LayoutView) => void }) {
  return (
    <div role="group" aria-label="View layout">
      <button
        type="button"
        onClick={() => onChange('grid')}
        aria-pressed={view === 'grid'}
        aria-label="Grid view"
        className={`rounded-l-md border px-3 py-2 ${
          view === 'grid' ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-300'
        }`}
      >
        <GridIcon />
      </button>
      <button
        type="button"
        onClick={() => onChange('list')}
        aria-pressed={view === 'list'}
        aria-label="List view"
        className={`rounded-r-md border-t border-b border-r px-3 py-2 ${
          view === 'list' ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-300'
        }`}
      >
        <ListIcon />
      </button>
    </div>
  );
}
```

WHY `aria-pressed` on toggle buttons: these are not `role="radio"` controls — they're toggle buttons. `aria-pressed={true/false}` communicates the pressed state correctly. Screen readers announce "Grid view, pressed" vs "List view".

## Smooth Layout Transition

CSS handles the transition between grid and flex layouts. Animate via a wrapping div, not by conditionally rendering two different component trees (that would unmount/remount all children):

```tsx
function ContentLayout({ view, children }: { view: LayoutView; children: React.ReactNode }) {
  return (
    <div
      className={`
        transition-all duration-200
        ${view === 'grid'
          ? 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4'
          : 'flex flex-col gap-2'
        }
      `}
    >
      {children}
    </div>
  );
}
```

For item-level layout differences, pass `view` as a prop to each item:

```tsx
function ItemCard({ item, view }: { item: Item; view: LayoutView }) {
  if (view === 'list') {
    return (
      <div className="flex items-center gap-4 rounded-lg border p-4">
        <img src={item.thumbnail} className="h-12 w-12 rounded object-cover" />
        <div>
          <p className="font-medium">{item.title}</p>
          <p className="text-sm text-gray-500">{item.subtitle}</p>
        </div>
      </div>
    );
  }
  return (
    <div className="rounded-lg border p-4">
      <img src={item.thumbnail} className="mb-3 h-40 w-full rounded object-cover" />
      <p className="font-medium">{item.title}</p>
    </div>
  );
}
```

WHY not `display: none` on one layout and show the other: that would keep two copies of every item in the DOM. Conditional rendering in the item is cleaner.

## SSR Hydration

The `window.innerWidth` check in the initializer runs client-side only. Wrap in `typeof window !== 'undefined'` or use a `useEffect` to set the default after hydration if SSR mismatch is a concern:

```ts
const [view, setViewState] = useState<LayoutView>('grid');  // safe SSR default

useEffect(() => {
  const saved = localStorage.getItem(storageKey) as LayoutView | null;
  setViewState(saved ?? (window.innerWidth < 768 ? 'list' : 'grid'));
}, []);
```

## Key Rules

- `aria-pressed` on toggle buttons communicates current state to screen readers
- Default to `'list'` on viewports < 768px; `'grid'` on desktop
- Persist to localStorage so the preference survives page navigation and refresh
- One component tree per item, not two separate rendered trees; pass `view` as a prop
- `transition-all duration-200` on the grid wrapper provides a smooth layout shift
