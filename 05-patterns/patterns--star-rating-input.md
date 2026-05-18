# Pattern: Star Rating Input

## Overview

Star ratings have two modes: display (read-only) and input (interactive). The input mode needs hover state, keyboard nav (arrow keys), and a half-star variant. The hidden input pattern keeps it form-compatible with React Hook Form and native HTML forms.

## Basic Interactive Stars

```tsx
import { useState } from 'react'

interface StarRatingProps {
  value: number          // 0–5
  onChange: (value: number) => void
  max?: number
  readOnly?: boolean
}

export function StarRating({ value, onChange, max = 5, readOnly = false }: StarRatingProps) {
  const [hovered, setHovered] = useState<number | null>(null)
  const display = hovered ?? value

  return (
    <div
      className="flex gap-0.5"
      role="radiogroup"
      aria-label="Rating"
      onMouseLeave={() => setHovered(null)}
    >
      {Array.from({ length: max }, (_, i) => i + 1).map((star) => (
        <button
          key={star}
          type="button"
          role="radio"
          aria-checked={value === star}
          aria-label={`${star} star${star !== 1 ? 's' : ''}`}
          disabled={readOnly}
          className="p-0.5 disabled:cursor-default"
          onClick={() => !readOnly && onChange(star)}
          onMouseEnter={() => !readOnly && setHovered(star)}
        >
          <Star
            filled={star <= display}
            className={readOnly ? 'text-amber-400' : 'text-amber-400 hover:scale-110 transition-transform'}
          />
        </button>
      ))}
    </div>
  )
}

function Star({ filled, className }: { filled: boolean; className?: string }) {
  return (
    <svg viewBox="0 0 20 20" width={20} height={20} className={className}>
      <path
        d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"
        fill={filled ? 'currentColor' : 'none'}
        stroke="currentColor"
        strokeWidth={1.5}
      />
    </svg>
  )
}
```

## React Hook Form Integration

```tsx
import { Controller, useForm } from 'react-hook-form'
import { z } from 'zod'
import { zodResolver } from '@hookform/resolvers/zod'

const reviewSchema = z.object({
  rating: z.number().min(1, 'Please select a rating').max(5),
  comment: z.string().min(10),
})

export function ReviewForm() {
  const { control, handleSubmit, formState: { errors } } = useForm({
    resolver: zodResolver(reviewSchema),
    defaultValues: { rating: 0, comment: '' },
  })

  return (
    <form onSubmit={handleSubmit(console.log)}>
      <Controller
        control={control}
        name="rating"
        render={({ field }) => (
          <div>
            <StarRating value={field.value} onChange={field.onChange} />
            {errors.rating && (
              <p className="text-red-500 text-sm mt-1">{errors.rating.message}</p>
            )}
          </div>
        )}
      />
    </form>
  )
}
```

## Keyboard Navigation

```tsx
function StarRatingKeyboard({ value, onChange, max = 5 }: StarRatingProps) {
  function onKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'ArrowRight' || e.key === 'ArrowUp') {
      e.preventDefault()
      onChange(Math.min(max, value + 1))
    }
    if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') {
      e.preventDefault()
      onChange(Math.max(0, value - 1))
    }
    if (e.key === 'Home') onChange(1)
    if (e.key === 'End') onChange(max)
  }

  return (
    <div
      tabIndex={0}
      role="slider"
      aria-valuemin={0}
      aria-valuemax={max}
      aria-valuenow={value}
      aria-label="Rating"
      onKeyDown={onKeyDown}
      className="flex gap-0.5 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 rounded"
    >
      {/* stars */}
    </div>
  )
}
```

## Half-Star Display (Read-Only)

```tsx
function HalfStarRating({ value, max = 5 }: { value: number; max?: number }) {
  return (
    <div className="flex gap-0.5" aria-label={`${value} out of ${max} stars`}>
      {Array.from({ length: max }, (_, i) => {
        const fillAmount = Math.min(1, Math.max(0, value - i))
        // 0 = empty, 0.5 = half, 1 = full
        return <StarPartial key={i} fill={fillAmount} />
      })}
    </div>
  )
}

function StarPartial({ fill }: { fill: number }) {
  const gradientId = useId()
  return (
    <svg viewBox="0 0 20 20" width={16} height={16}>
      <defs>
        <linearGradient id={gradientId}>
          <stop offset={`${fill * 100}%`} stopColor="#f59e0b" />
          <stop offset={`${fill * 100}%`} stopColor="transparent" />
        </linearGradient>
      </defs>
      <path
        d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"
        fill={`url(#${gradientId})`}
        stroke="#f59e0b"
        strokeWidth={1.5}
      />
    </svg>
  )
}
```

## Display with Count

```tsx
function RatingSummary({ average, count }: { average: number; count: number }) {
  return (
    <div className="flex items-center gap-2">
      <HalfStarRating value={average} />
      <span className="font-semibold text-sm">{average.toFixed(1)}</span>
      <span className="text-gray-500 text-sm">({count.toLocaleString()} reviews)</span>
    </div>
  )
}
```

## Key Rules

- `role="radiogroup"` with individual `role="radio"` buttons is the correct ARIA pattern — not a slider for click-to-pick semantics, but use `role="slider"` with `ArrowKey` nav when continuous values matter.
- Never use `value === 0` as "unrated" and `value === 0` as "zero stars" simultaneously — use `null` for unset, `0` is a valid rating if you have one.
- Hover preview must reset on `onMouseLeave` of the container, not individual stars — cursor moving between stars would flash.
- Half-star display uses a per-star linearGradient via `useId()` — a shared gradient ID breaks when multiple rating components render on the same page.
- Store ratings as integers in the DB (1–5) rather than floats — averages are computed at query time.
