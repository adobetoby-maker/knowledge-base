# Pattern: Weighted Tag Cloud

## Problem

Tag clouds encode frequency as font size. The challenge is normalizing counts to a readable size range, keeping all sizes accessible (sufficient contrast, minimum touch targets), and wiring click-to-filter behavior that's both visual and accessible.

## Size Normalization Formula

Map raw counts to a font size range (e.g., 0.75rem–2rem) using linear interpolation:

```ts
type Tag = { name: string; count: number };

function normalizeFontSize(
  count: number,
  min: number,
  max: number,
  minSize = 0.75,
  maxSize = 2.0
): number {
  if (min === max) return (minSize + maxSize) / 2;  // all tags equal frequency
  return minSize + ((count - min) / (max - min)) * (maxSize - minSize);
}

function enrichTags(tags: Tag[]) {
  const counts = tags.map(t => t.count);
  const min = Math.min(...counts);
  const max = Math.max(...counts);
  return tags.map(t => ({
    ...t,
    fontSize: normalizeFontSize(t.count, min, max),
  }));
}
```

WHY linear: logarithmic scaling (common in some implementations) compresses variation too much when counts span a wide range. Linear is more legible for users.

## Click-to-Filter

Track active filters as a `Set` — supports multi-select naturally:

```tsx
function TagCloud({ tags }: { tags: Tag[] }) {
  const [active, setActive] = useState<Set<string>>(new Set());

  function toggle(name: string) {
    setActive(prev => {
      const next = new Set(prev);
      next.has(name) ? next.delete(name) : next.add(name);
      return next;
    });
  }

  const enriched = enrichTags(tags);

  return (
    <div
      role="group"
      aria-label="Filter by tag"
      className="flex flex-wrap gap-2"
    >
      {enriched.map(tag => (
        <button
          key={tag.name}
          onClick={() => toggle(tag.name)}
          aria-pressed={active.has(tag.name)}
          aria-label={`${tag.name}, ${tag.count} items`}
          style={{ fontSize: `${tag.fontSize}rem` }}
          className={`rounded-full px-3 py-1 font-medium transition-colors min-h-[2rem] ${
            active.has(tag.name)
              ? 'bg-indigo-600 text-white'
              : 'bg-gray-100 text-gray-800 hover:bg-gray-200'
          }`}
        >
          {tag.name}
        </button>
      ))}
    </div>
  );
}
```

## Accessible Color Contrast at All Sizes

WCAG 2.1 requires 4.5:1 for normal text, 3:1 for large text (≥18pt / 24px). At small font sizes (0.75–1rem) you must use high-contrast color pairs:

- Inactive: `text-gray-800` on `bg-gray-100` — approximately 8:1, safe at all sizes
- Active: `text-white` on `bg-indigo-600` — approximately 6:1, safe
- Avoid light-colored text on light backgrounds at small sizes — this is where tag clouds commonly fail WCAG

WHY `aria-label` includes the count: screen readers reading "JavaScript" give no frequency context. "JavaScript, 47 items" is informative.

WHY `min-h-[2rem]`: at `font-size: 0.75rem` the natural click target is too small for touch. The min-height ensures a 32px touch target.

## Sorting

Render by descending count (most common first) OR by name alphabetically — never by random or insertion order. Random order makes the cloud look broken:

```ts
const sorted = [...enriched].sort((a, b) => b.count - a.count);
```

## Key Rules

- Normalize font sizes via linear interpolation between a min/max rem range
- Handle `min === max` edge case (all tags equal frequency) — return midpoint
- `aria-label` on each button includes both tag name and count
- `aria-pressed` communicates active/inactive state to screen readers
- Minimum touch target `min-h-[2rem]` required at small font sizes
- High-contrast colors required at all size levels — `text-gray-100` on a white background fails at any font size
