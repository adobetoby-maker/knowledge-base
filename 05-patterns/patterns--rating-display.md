# Pattern: Read-Only Star Rating Display

A visual star rating showing a numeric score (e.g., 4.3/5) plus an aggregate review count. The complexity is: partial stars via SVG clip paths, structured data markup for search engines, and an accessible text alternative that doesn't rely on the visual stars.

## Why It Matters

Star ratings are skimmed, not read. A "4.3 out of 5 stars, 146 reviews" communicates quality faster than any prose. Google also reads `schema.org/AggregateRating` markup and uses it for rich snippets in search results—adding the structured data is free SEO.

## Partial Stars via SVG Clip Path

Each star is an SVG that uses a `<clipPath>` to reveal exactly the right fraction. A 4.3 rating renders four full stars and one star that is 30% filled.

```tsx
function Star({ fill }: { fill: number }) {
  // fill: 0 = empty, 0.5 = half, 1 = full
  const id = useId();
  const pct = `${Math.max(0, Math.min(1, fill)) * 100}%`;

  return (
    <svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true">
      <defs>
        <clipPath id={id}>
          <rect x="0" y="0" width={pct} height="20" />
        </clipPath>
      </defs>
      {/* Empty star background */}
      <path
        d="M10 1l2.5 5.5H18l-4.5 4 1.75 6L10 13.25 4.75 16.5 6.5 10.5 2 6.5h5.5z"
        fill="currentColor"
        className="star-empty"
      />
      {/* Filled star overlaid, clipped to fill% */}
      <path
        d="M10 1l2.5 5.5H18l-4.5 4 1.75 6L10 13.25 4.75 16.5 6.5 10.5 2 6.5h5.5z"
        fill="currentColor"
        className="star-filled"
        clipPath={`url(#${id})`}
      />
    </svg>
  );
}
```

`useId()` ensures each `<clipPath>` has a unique ID—duplicate IDs in SVG cause all stars to share the same clip path, breaking partial fills.

## Full Rating Component

```tsx
interface RatingDisplayProps {
  rating: number;    // e.g., 4.3
  count: number;     // e.g., 146
  max?: number;      // default 5
  showCount?: boolean;
}

function RatingDisplay({ rating, count, max = 5, showCount = true }: RatingDisplayProps) {
  const stars = Array.from({ length: max }, (_, i) => {
    const diff = rating - i;
    if (diff >= 1) return 1;       // full star
    if (diff > 0) return diff;     // partial star (e.g., 0.3)
    return 0;                      // empty star
  });

  const formattedRating = rating.toFixed(1);

  return (
    <div className="rating-display">
      {/* Accessible text — screen readers read this, ignore stars */}
      <span className="sr-only">
        Rated {formattedRating} out of {max} stars
        {showCount && `, based on ${count} reviews`}
      </span>

      {/* Visual stars — aria-hidden so screen readers skip them */}
      <div className="rating-stars" aria-hidden="true">
        {stars.map((fill, i) => <Star key={i} fill={fill} />)}
      </div>

      {/* Numeric display */}
      <span className="rating-value" aria-hidden="true">{formattedRating}</span>

      {showCount && (
        <span className="rating-count" aria-hidden="true">
          ({count.toLocaleString()})
        </span>
      )}
    </div>
  );
}
```

The `sr-only` span carries the full accessible description. Everything else is `aria-hidden="true"` because the visual representation duplicates it redundantly for screen readers.

## schema.org AggregateRating Markup

Add structured data to the page via JSON-LD. The `schema` object is serialized from known-safe values only—never from user-supplied strings.

```tsx
function RatingSchema({ rating, count, itemName }: { rating: number; count: number; itemName: string }) {
  // Values are serialized from typed primitives, not user HTML
  const schema = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'Product',  // or LocalBusiness, Recipe, etc.
    name: itemName,
    aggregateRating: {
      '@type': 'AggregateRating',
      ratingValue: rating.toFixed(1),
      reviewCount: count,
      bestRating: '5',
      worstRating: '1',
    },
  });

  // In Next.js, inject via next/head or the metadata API instead of inline script
  return null; // structured data injected by page-level metadata
}
```

In Next.js App Router, inject JSON-LD via `generateMetadata` or by returning a `<script>` element from the RSC layer where the content is fully controlled. Never pass unescaped user input into a JSON-LD script block.

## Color Conventions

```css
.star-empty  { color: #d1d5db; }   /* gray-300 */
.star-filled { color: #f59e0b; }   /* amber-400 */
```

Some designs use an outlined stroke for empty stars—that requires a different SVG path (outline star) behind the filled one rather than overlapping the same path with different colors.

## Compact Variant

For inline use (next to a product name, in a table):

```tsx
function RatingCompact({ rating, count }: { rating: number; count: number }) {
  return (
    <span className="rating-compact" aria-label={`${rating.toFixed(1)} stars, ${count} reviews`}>
      <StarIcon className="star-icon" aria-hidden />
      <span>{rating.toFixed(1)}</span>
      <span className="count">({count})</span>
    </span>
  );
}
```

For the compact variant, a single filled star icon + numeric is more legible at small sizes than five partial stars.

## Key Rules

- **`useId()` per star**—duplicate `clipPath` IDs break partial fills in SVG.
- **One `sr-only` span** with the full text—mark all visual elements `aria-hidden`.
- **JSON-LD schema.org markup** for Google rich snippets—use `AggregateRating` nested in the content type.
- **`ratingValue`, `reviewCount`, `bestRating`, `worstRating`** are all required by Google's validator.
- **Clip path approach**: two overlapping star paths with the top one clipped to fill%—not background-image or emoji.
- **Compact variant**: single star + number for inline/table use—five stars at 14px are illegible.
- **`toLocaleString()`** on review count for proper thousands separator (1,146 not 1146).
- **JSON-LD values from typed primitives only**—never interpolate user-supplied strings into script blocks.
