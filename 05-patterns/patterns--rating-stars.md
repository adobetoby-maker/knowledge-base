# Pattern: Star Rating Display and Input

## What This Solves

Two distinct use cases: displaying a read-only rating (reviews, product scores), and capturing a rating as user input. Both need to handle half-stars and accessibility correctly.

## Read-Only Rating Display

```tsx
// components/StarRating.tsx
import { Star, StarHalf } from 'lucide-react'
import { cn } from '@/lib/utils'

interface StarRatingProps {
  value: number        // 0–5, supports .5 increments
  max?: number
  size?: 'sm' | 'md' | 'lg'
  showValue?: boolean
  reviewCount?: number
  className?: string
}

const SIZE_MAP = {
  sm: 'h-3 w-3',
  md: 'h-4 w-4',
  lg: 'h-5 w-5',
}

export function StarRating({
  value,
  max = 5,
  size = 'md',
  showValue = false,
  reviewCount,
  className,
}: StarRatingProps) {
  const stars = Array.from({ length: max }, (_, i) => {
    const starNumber = i + 1
    if (value >= starNumber) return 'full'
    if (value >= starNumber - 0.5) return 'half'
    return 'empty'
  })

  return (
    <div className={cn('flex items-center gap-1', className)}>
      <div className="flex items-center" aria-label={`${value} out of ${max} stars`} role="img">
        {stars.map((type, i) => (
          <span key={i} className="relative">
            {type === 'full' && (
              <Star className={cn(SIZE_MAP[size], 'fill-amber-400 text-amber-400')} />
            )}
            {type === 'half' && (
              <span className="relative">
                <Star className={cn(SIZE_MAP[size], 'text-muted')} />
                <StarHalf className={cn(SIZE_MAP[size], 'fill-amber-400 text-amber-400 absolute inset-0')} />
              </span>
            )}
            {type === 'empty' && (
              <Star className={cn(SIZE_MAP[size], 'text-muted fill-muted')} />
            )}
          </span>
        ))}
      </div>
      {showValue && (
        <span className="text-sm font-medium">{value.toFixed(1)}</span>
      )}
      {reviewCount !== undefined && (
        <span className="text-sm text-muted-foreground">({reviewCount.toLocaleString()})</span>
      )}
    </div>
  )
}
```

Usage:
```tsx
<StarRating value={4.8} showValue reviewCount={146} />
// → ★★★★★ 4.8 (146)
```

## Interactive Rating Input

```tsx
// components/StarRatingInput.tsx
'use client'
import { useState } from 'react'
import { Star } from 'lucide-react'
import { cn } from '@/lib/utils'

interface StarRatingInputProps {
  value: number
  onChange: (rating: number) => void
  max?: number
  disabled?: boolean
  label?: string
}

export function StarRatingInput({
  value,
  onChange,
  max = 5,
  disabled = false,
  label = 'Rating',
}: StarRatingInputProps) {
  const [hovered, setHovered] = useState<number | null>(null)

  const displayValue = hovered ?? value

  return (
    <div>
      {label && (
        <p className="text-sm font-medium mb-1" id="star-label">{label}</p>
      )}
      <div
        className="flex gap-0.5"
        role="radiogroup"
        aria-labelledby="star-label"
      >
        {Array.from({ length: max }, (_, i) => {
          const starValue = i + 1
          const filled = starValue <= displayValue

          return (
            <button
              key={i}
              type="button"
              role="radio"
              aria-checked={value === starValue}
              aria-label={`${starValue} star${starValue !== 1 ? 's' : ''}`}
              disabled={disabled}
              className={cn(
                'p-0.5 rounded transition-transform hover:scale-110 focus:outline-none focus:ring-2 focus:ring-ring',
                disabled && 'cursor-not-allowed opacity-50'
              )}
              onClick={() => onChange(starValue)}
              onMouseEnter={() => setHovered(starValue)}
              onMouseLeave={() => setHovered(null)}
            >
              <Star
                className={cn(
                  'h-6 w-6 transition-colors',
                  filled ? 'fill-amber-400 text-amber-400' : 'text-muted-foreground fill-muted'
                )}
              />
            </button>
          )
        })}
      </div>
      {value > 0 && (
        <p className="text-xs text-muted-foreground mt-1">
          {value === 1 && 'Poor'}
          {value === 2 && 'Fair'}
          {value === 3 && 'Good'}
          {value === 4 && 'Very Good'}
          {value === 5 && 'Excellent'}
        </p>
      )}
    </div>
  )
}
```

## React Hook Form Integration

```tsx
<Controller
  control={form.control}
  name="rating"
  rules={{ required: 'Please select a rating', min: { value: 1, message: 'Rating required' } }}
  render={({ field, fieldState }) => (
    <div>
      <StarRatingInput
        value={field.value}
        onChange={field.onChange}
        label="How was your experience?"
      />
      {fieldState.error && (
        <p className="text-sm text-destructive mt-1">{fieldState.error.message}</p>
      )}
    </div>
  )}
/>
```

## Database Storage

Store as a numeric value (1–5). Use `CHECK` constraint:
```sql
ALTER TABLE reviews ADD COLUMN rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5);
```

Compute average in SQL, not JavaScript:
```sql
SELECT AVG(rating)::numeric(3,1) AS avg_rating, COUNT(*) AS review_count
FROM reviews WHERE service_id = $1;
```

## Review Schema Markup

For Google's review snippet:
```ts
const reviewSchema = {
  '@context': 'https://schema.org',
  '@type': 'LocalBusiness',
  aggregateRating: {
    '@type': 'AggregateRating',
    ratingValue: avgRating.toFixed(1),
    reviewCount: reviewCount,
    bestRating: '5',
  },
}
```
