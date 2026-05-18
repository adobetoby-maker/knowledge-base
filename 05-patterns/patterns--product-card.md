# Product Card — E-commerce

## Image Hover: Second Image

Show an alternate product image on hover using CSS opacity transition, not a JS swap. Both images are in the DOM; the secondary image sits on top with `opacity: 0`. This avoids the blank flash from lazy-loading a new `src` on hover.

```tsx
<div className="relative overflow-hidden aspect-square">
  <img src={primary} alt={name} className="w-full h-full object-cover" />
  {secondary && (
    <img
      src={secondary}
      alt=""  // decorative — primary already has alt
      className="absolute inset-0 w-full h-full object-cover opacity-0 transition-opacity duration-300 group-hover:opacity-100"
    />
  )}
</div>
```

Preload the secondary image: add `<link rel="prefetch">` for images above the fold, or use a tiny invisible `<img>` with `loading="lazy"` in the card to let the browser prefetch on card mount.

## Price Display

Show sale price prominently; original price smaller and struck through. Never show both at the same visual weight — the discount must be instantly legible.

```tsx
{salePrice ? (
  <div className="flex items-baseline gap-2">
    <span className="text-lg font-semibold text-red-600">{fmt(salePrice)}</span>
    <span className="text-sm text-muted-foreground line-through">{fmt(price)}</span>
    <span className="text-xs bg-red-100 text-red-700 px-1 rounded">
      -{Math.round((1 - salePrice / price) * 100)}%
    </span>
  </div>
) : (
  <span className="text-lg font-semibold">{fmt(price)}</span>
)}
```

## Quick-Add Button

The quick-add button lives on the card image — visible only on hover (desktop) or always visible (mobile). It should fire `addToCart` and show a brief checkmark confirmation, then revert. Don't navigate; don't open a drawer. For products with variants (size/color), quick-add should open a compact variant picker popover, not navigate to the PDP.

```tsx
<button
  onClick={handleQuickAdd}
  className="absolute bottom-2 inset-x-2 opacity-0 group-hover:opacity-100 transition-opacity"
  aria-label={`Add ${name} to cart`}
>
  {added ? <Check className="w-4 h-4" /> : 'Add to cart'}
</button>
```

## Wishlist Heart

Toggle button — `aria-pressed` reflects current state. Persist to server for logged-in users, to `localStorage` for guests. The heart fills on save; outline when not saved.

```tsx
<button
  aria-label={saved ? `Remove ${name} from wishlist` : `Save ${name} to wishlist`}
  aria-pressed={saved}
  onClick={toggleWishlist}
  className="absolute top-2 right-2"
>
  <Heart className={cn("w-5 h-5", saved && "fill-red-500 text-red-500")} />
</button>
```

## Star Rating Display

Show filled/half/empty stars. Use a visual display only — not interactive on the card (interaction belongs on the PDP). Pair with review count so the rating has context.

```tsx
<div className="flex items-center gap-1" aria-label={`${rating} out of 5 stars, ${reviewCount} reviews`}>
  {Array.from({ length: 5 }, (_, i) => (
    <Star key={i} filled={i < Math.floor(rating)} half={i === Math.floor(rating) && rating % 1 >= 0.5} />
  ))}
  <span className="text-xs text-muted-foreground">({reviewCount})</span>
</div>
```

## Skeleton Loading State

Match the skeleton structure exactly to the card — same aspect ratio image placeholder, two lines of text at realistic widths, price line. Mismatched skeletons cause layout shift on load.

```tsx
function ProductCardSkeleton() {
  return (
    <div className="animate-pulse">
      <div className="aspect-square bg-muted rounded-lg" />
      <div className="mt-2 h-4 bg-muted rounded w-3/4" />
      <div className="mt-1 h-3 bg-muted rounded w-1/2" />
      <div className="mt-2 h-5 bg-muted rounded w-1/3" />
    </div>
  )
}
```

## Key Rules

- Both images in DOM; use CSS opacity transition — never swap `src` on hover.
- Sale price visually dominant; original price struck-through at smaller weight.
- Quick-add shows checkmark confirmation; navigates to PDP only if variants require selection.
- Wishlist uses `aria-pressed`; fills the heart, doesn't navigate.
- Rating display is read-only on the card; include review count for context.
- Skeleton matches card layout exactly to prevent cumulative layout shift.
