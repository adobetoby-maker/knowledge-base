# Pattern: Variant Picker

## Overview

Product variant selection (size, color, material). Key behaviors: show all options, indicate which combinations are available/sold out, update URL when variant changes for shareability, and show the selected variant's price/image. The core challenge is handling the multi-dimensional availability matrix.

## Data Model

```ts
interface ProductVariant {
  id: string
  size: string | null
  color: string | null
  material: string | null
  priceCents: number
  compareAtCents: number | null
  inStock: boolean
  stockCount: number
  imageUrl: string | null
}

interface Product {
  id: string
  name: string
  images: string[]
  variants: ProductVariant[]
}

// Extract unique option values
function getOptions(variants: ProductVariant[]) {
  return {
    sizes: [...new Set(variants.map(v => v.size).filter(Boolean))],
    colors: [...new Set(variants.map(v => v.color).filter(Boolean))],
  }
}
```

## Availability Matrix

Determine which options are available given current selection:

```ts
function getAvailability(
  variants: ProductVariant[],
  selected: { size?: string; color?: string }
): { sizes: Record<string, boolean>; colors: Record<string, boolean> } {
  const options = getOptions(variants)

  return {
    sizes: Object.fromEntries(
      options.sizes.map(size => {
        const available = variants.some(v =>
          v.size === size &&
          (!selected.color || v.color === selected.color) &&
          v.inStock
        )
        return [size, available]
      })
    ),
    colors: Object.fromEntries(
      options.colors.map(color => {
        const available = variants.some(v =>
          v.color === color &&
          (!selected.size || v.size === selected.size) &&
          v.inStock
        )
        return [color, available]
      })
    ),
  }
}

function getSelectedVariant(
  variants: ProductVariant[],
  selected: { size?: string; color?: string }
): ProductVariant | null {
  return variants.find(v =>
    (!selected.size || v.size === selected.size) &&
    (!selected.color || v.color === selected.color)
  ) ?? null
}
```

## Component

```tsx
export function VariantPicker({ product }: { product: Product }) {
  const router = useRouter()
  const searchParams = useSearchParams()

  const [selected, setSelected] = useState<{ size?: string; color?: string }>({
    size: searchParams.get('size') ?? undefined,
    color: searchParams.get('color') ?? undefined,
  })

  const options = getOptions(product.variants)
  const availability = getAvailability(product.variants, selected)
  const selectedVariant = getSelectedVariant(product.variants, selected)

  const handleSelect = (type: 'size' | 'color', value: string) => {
    const next = { ...selected, [type]: selected[type] === value ? undefined : value }
    setSelected(next)

    // Update URL without navigation
    const params = new URLSearchParams()
    if (next.size) params.set('size', next.size)
    if (next.color) params.set('color', next.color)
    router.replace(`?${params}`, { scroll: false })
  }

  return (
    <div className="space-y-4">
      {options.sizes.length > 0 && (
        <div>
          <label className="text-sm font-medium text-gray-700 mb-2 block">
            Size{selected.size ? `: ${selected.size}` : ''}
          </label>
          <div className="flex flex-wrap gap-2">
            {options.sizes.map(size => (
              <VariantButton
                key={size}
                label={size}
                selected={selected.size === size}
                available={availability.sizes[size ?? ''] ?? false}
                onClick={() => handleSelect('size', size!)}
              />
            ))}
          </div>
        </div>
      )}

      {options.colors.length > 0 && (
        <div>
          <label className="text-sm font-medium text-gray-700 mb-2 block">
            Color{selected.color ? `: ${selected.color}` : ''}
          </label>
          <div className="flex flex-wrap gap-2">
            {options.colors.map(color => (
              <ColorSwatch
                key={color}
                color={color}
                selected={selected.color === color}
                available={availability.colors[color ?? ''] ?? false}
                onClick={() => handleSelect('color', color!)}
              />
            ))}
          </div>
        </div>
      )}

      {selectedVariant && (
        <div className="text-2xl font-bold">
          ${(selectedVariant.priceCents / 100).toFixed(2)}
          {selectedVariant.compareAtCents && (
            <span className="text-sm text-gray-400 line-through ml-2">
              ${(selectedVariant.compareAtCents / 100).toFixed(2)}
            </span>
          )}
        </div>
      )}
    </div>
  )
}

function VariantButton({ label, selected, available, onClick }: {
  label: string
  selected: boolean
  available: boolean
  onClick: () => void
}) {
  return (
    <button
      onClick={onClick}
      disabled={!available}
      className={cn(
        'px-4 py-2 text-sm border rounded-md transition-colors',
        selected && 'border-black bg-black text-white',
        !selected && available && 'border-gray-300 hover:border-gray-500',
        !available && 'border-gray-200 text-gray-300 cursor-not-allowed line-through'
      )}
    >
      {label}
    </button>
  )
}
```

## Key Rules

- Show sold-out options as disabled (crossed out) rather than hidden — users need to know the size exists.
- Update URL on variant selection for shareable product links (`?size=M&color=blue`).
- When a selected option becomes unavailable due to another selection, auto-deselect it rather than showing "this combination is unavailable."
- Display the variant's specific price, not just the base product price — prices vary by variant.
- Size guides link near the size picker — reduces returns and improves conversion.
