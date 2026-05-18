# Pattern: Count-Up Number Animation

## Overview

Animate a number counting up from 0 to its target value when it enters the viewport. Used on landing pages for stats like "10,000+ customers" or "$2.4M saved". Trigger on viewport entry using IntersectionObserver, respect `prefers-reduced-motion`, and format the final value identically to the animated value to prevent layout shift.

## Hook

```tsx
function useCountUp(target: number, duration = 1500) {
  const [current, setCurrent] = useState(0)
  const startTimeRef = useRef<number | null>(null)
  const rafRef = useRef<number>(0)
  const prefersReduced = useRef(
    typeof window !== 'undefined'
      ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
      : false
  )

  const start = useCallback(() => {
    if (prefersReduced.current) {
      setCurrent(target)
      return
    }

    startTimeRef.current = null

    const animate = (timestamp: number) => {
      if (!startTimeRef.current) startTimeRef.current = timestamp
      const elapsed = timestamp - startTimeRef.current
      const progress = Math.min(elapsed / duration, 1)

      // Ease-out cubic
      const eased = 1 - Math.pow(1 - progress, 3)
      setCurrent(Math.round(eased * target))

      if (progress < 1) {
        rafRef.current = requestAnimationFrame(animate)
      }
    }

    rafRef.current = requestAnimationFrame(animate)
  }, [target, duration])

  useEffect(() => () => cancelAnimationFrame(rafRef.current), [])

  return { current, start }
}
```

## Component with IntersectionObserver

```tsx
interface StatProps {
  value: number
  suffix?: string    // '+', '%', 'K', etc.
  prefix?: string    // '$', etc.
  label: string
  duration?: number
}

export function AnimatedStat({ value, suffix = '', prefix = '', label, duration = 1500 }: StatProps) {
  const { current, start } = useCountUp(value, duration)
  const ref = useRef<HTMLDivElement>(null)
  const started = useRef(false)

  useEffect(() => {
    if (!ref.current) return
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !started.current) {
          started.current = true
          start()
          observer.disconnect()
        }
      },
      { threshold: 0.5 }
    )
    observer.observe(ref.current)
    return () => observer.disconnect()
  }, [start])

  return (
    <div ref={ref} className="text-center">
      <div className="text-4xl font-bold tabular-nums">
        {prefix}{current.toLocaleString()}{suffix}
      </div>
      <div className="text-sm text-gray-600 mt-1">{label}</div>
    </div>
  )
}
```

## Formatted Numbers (K/M Abbreviation)

```tsx
function formatStatValue(value: number, current: number): string {
  if (value >= 1_000_000) {
    return (current / 1_000_000).toFixed(1) + 'M'
  }
  if (value >= 1_000) {
    return Math.round(current / 1_000) + 'K'
  }
  return current.toLocaleString()
}

// Usage: show "10K" animating up, not "10,000"
<div>{prefix}{formatStatValue(value, current)}{suffix}</div>
```

## Stats Row

```tsx
const stats = [
  { value: 10000, suffix: '+', label: 'Customers' },
  { value: 2400000, prefix: '$', label: 'Processed daily', duration: 2000 },
  { value: 99.9, suffix: '%', label: 'Uptime' },
  { value: 45, label: 'Countries' },
]

export function StatsSection() {
  return (
    <section className="py-16 border-y">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-8 max-w-4xl mx-auto px-4">
        {stats.map(stat => (
          <AnimatedStat key={stat.label} {...stat} />
        ))}
      </div>
    </section>
  )
}
```

## Key Rules

- Trigger on viewport entry (not on mount) — stats on landing pages are often below the fold.
- `started.current` ref prevents re-triggering on scroll jitter; `observer.disconnect()` after first trigger.
- `tabular-nums` on the number element prevents horizontal layout shift as digits change width.
- `prefers-reduced-motion: reduce` — skip animation entirely, show final value immediately.
- Ease-out (not linear) — the number accelerates at start and decelerates at end, which reads as satisfying rather than mechanical.
- Match the format of the animated value to the static value — don't show "10000" animating and then snap to "10K" at the end.
