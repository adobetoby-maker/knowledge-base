# plugin--react-virtuoso

react-virtuoso is a virtual list library for React that renders only the visible portion of a list, regardless of total size. Unlike react-window or react-virtual, it handles **dynamic item heights** natively without requiring you to specify heights upfront.

## Basic Usage

```tsx
import { Virtuoso } from 'react-virtuoso';

<Virtuoso
  data={items}
  itemContent={(index, item) => (
    <div style={{ padding: '8px 16px' }}>
      <strong>{item.name}</strong>
      <p>{item.description}</p>
    </div>
  )}
  style={{ height: '600px' }}
/>
```

The container must have a defined height — `height: '100%'` works if the parent has a height, but `100vh` on a flex child may need `minHeight: 0` to prevent overflow. react-virtuoso measures each rendered item and updates its internal size map, which is why variable heights work without configuration.

## endReached for Infinite Scroll

```tsx
const [items, setItems] = useState<Item[]>(initialItems);
const [loading, setLoading] = useState(false);

<Virtuoso
  data={items}
  endReached={async () => {
    if (loading) return;
    setLoading(true);
    const more = await fetchMoreItems(items.length);
    setItems((prev) => [...prev, ...more]);
    setLoading(false);
  }}
  overscan={200}        // px of pre-rendered buffer below viewport
  itemContent={(index, item) => <ItemRow item={item} />}
  components={{
    Footer: () => loading ? <Spinner /> : null,
  }}
/>
```

`endReached` fires when the user scrolls within `overscan` pixels of the bottom. The guard (`if (loading) return`) prevents duplicate fetches. Append to `data` (not replace) — Virtuoso diffs the array and preserves scroll position. Replacing the entire `data` array resets scroll to the top.

## scrollToIndex for Jump Navigation

```tsx
const virtuosoRef = useRef<VirtuosoHandle>(null);

// Jump to item 50, smoothly
virtuosoRef.current?.scrollToIndex({ index: 50, behavior: 'smooth', align: 'start' });

// Jump to bottom
virtuosoRef.current?.scrollToIndex({ index: items.length - 1, align: 'end' });

<Virtuoso ref={virtuosoRef} data={items} itemContent={...} />
```

`scrollToIndex` is an imperative API on the ref handle. `align: 'start'` positions the item at the top of the visible area; `'center'` centers it; `'end'` puts it at the bottom. For items that haven't been rendered yet (below the fold), Virtuoso estimates the scroll position and corrects it after the item renders — the scroll may appear to "snap" for the first jump to a far-off index.

## GroupedVirtuoso for Sectioned Lists

```tsx
import { GroupedVirtuoso } from 'react-virtuoso';

// groupCounts[i] = number of items in group i
const groupCounts = sections.map((s) => s.items.length);

<GroupedVirtuoso
  groupCounts={groupCounts}
  groupContent={(groupIndex) => (
    <div style={{ background: '#f0f0f0', padding: '4px 16px', fontWeight: 'bold' }}>
      {sections[groupIndex].title}
    </div>
  )}
  itemContent={(itemIndex, groupIndex) => {
    // itemIndex is global (0 to totalItems-1), not local to group
    const item = allItems[itemIndex];
    return <ItemRow item={item} />;
  }}
/>
```

Group headers are sticky by default — they pin to the top of the viewport while scrolling through their group. `itemIndex` is the absolute index across all items, not relative to the group — compute the item from a flat array or do the offset math manually.

## Dynamic Item Heights

react-virtuoso is specifically designed for content that varies in height (chat messages, feed posts, comment threads). Items are measured after they render using `ResizeObserver`. No configuration needed — just don't constrain item heights with fixed `height` CSS if the content is variable.

For items with very different sizes, increase `overscan` to pre-render more items and reduce the visual pop of items appearing above/below. Default overscan is 200px; for chat UIs with long messages, 600px is more comfortable.

**Reverse scroll (chat-style):**
```tsx
<Virtuoso
  data={messages}
  followOutput="smooth"   // keeps scroll pinned to bottom when new items arrive
  initialTopMostItemIndex={messages.length - 1}  // start at bottom
  itemContent={(i, msg) => <Message message={msg} />}
/>
```

## Key Rules

- **Container needs a defined height** — without it, the virtual window collapses to 0
- **Append to `data`, never replace** — replacing resets scroll position
- **`endReached` needs a loading guard** — it fires repeatedly until items expand the scroll range
- **`itemIndex` in GroupedVirtuoso is global** — not relative to the group
- **`followOutput="smooth"`** for chat/log UIs — keeps the view pinned to new content
- `scrollToIndex` on first jump to unrendered items will approximate then correct — don't treat a slight visual snap as a bug
