# Pattern: Social Proof Banner ("X users are using this")

## Overview

Social proof banners show live or recent activity ("47 people viewing this now", "3 signed up in the last hour") to create urgency and credibility. The effectiveness comes from specificity and recency — vague claims ("thousands of users") are less persuasive than recent, concrete numbers. The implementation challenge is sourcing accurate data without hammering the database on every page load.

## Data Architecture

Don't query live counts on every page render. Aggregate at a schedule:

```ts
// Background job (cron every 60s or triggered by events)
async function updateSocialProofCache() {
  const recentSignups = await db.users.count({
    where: { createdAt: { gte: new Date(Date.now() - 30 * 60 * 1000) } }
  })
  const activeToday = await db.users.count({
    where: { lastActiveAt: { gte: startOfDay(new Date()) } }
  })

  await redis.set('social-proof', JSON.stringify({ recentSignups, activeToday, updatedAt: Date.now() }), { ex: 120 })
}

// API route (cached)
export async function GET() {
  const cached = await redis.get('social-proof')
  return Response.json(JSON.parse(cached ?? '{}'), {
    headers: { 'Cache-Control': 's-maxage=60, stale-while-revalidate=300' }
  })
}
```

This pattern ensures the social proof number is always "recent enough" (within 2 minutes) without real-time DB pressure.

## Counter Animation

Numbers that animate in on display are more eye-catching than static numbers:

```tsx
function AnimatedCount({ target, duration = 1200 }: { target: number; duration?: number }) {
  const [count, setCount] = useState(0)
  const rafRef = useRef<number>()
  const startRef = useRef<number>()

  useEffect(() => {
    function tick(timestamp: number) {
      if (!startRef.current) startRef.current = timestamp
      const elapsed = timestamp - startRef.current
      const progress = Math.min(elapsed / duration, 1)
      // Ease out
      setCount(Math.round(target * (1 - Math.pow(1 - progress, 3))))
      if (progress < 1) rafRef.current = requestAnimationFrame(tick)
    }
    rafRef.current = requestAnimationFrame(tick)
    return () => { if (rafRef.current) cancelAnimationFrame(rafRef.current) }
  }, [target, duration])

  return <>{count.toLocaleString()}</>
}
```

## Avatar Stack

Show faces instead of (or alongside) a number — faces are more persuasive:

```tsx
function AvatarStack({ users, extraCount }: {
  users: { id: string; imageUrl?: string; name: string }[]
  extraCount: number
}) {
  return (
    <div className="flex items-center -space-x-2" aria-label={`${users.length + extraCount} users`}>
      {users.slice(0, 4).map((user, i) => (
        <img
          key={user.id}
          src={user.imageUrl ?? `https://api.dicebear.com/7.x/initials/svg?seed=${user.name}`}
          alt={user.name}
          title={user.name}
          className="w-7 h-7 rounded-full border-2 border-white object-cover"
          style={{ zIndex: 4 - i }}
        />
      ))}
      {extraCount > 0 && (
        <div
          className="w-7 h-7 rounded-full border-2 border-white bg-gray-200 flex items-center justify-center text-xs font-medium"
          aria-hidden="true"
        >
          +{extraCount > 99 ? '99' : extraCount}
        </div>
      )}
    </div>
  )
}
```

## Social Proof Banner Component

```tsx
function SocialProofBanner({ variant = 'default' }: { variant?: 'default' | 'compact' }) {
  const { data } = useQuery({
    queryKey: ['social-proof'],
    queryFn: () => fetch('/api/social-proof').then((r) => r.json()),
    staleTime: 60_000,
    refetchInterval: 120_000,
  })

  if (!data?.recentSignups) return null

  return (
    <div role="status" aria-live="polite" className="flex items-center gap-2 text-sm text-gray-600">
      <AvatarStack users={data.recentUsers ?? []} extraCount={Math.max(0, data.recentSignups - 4)} />
      <span>
        <AnimatedCount target={data.recentSignups} /> people joined in the last 30 minutes
      </span>
    </div>
  )
}
```

## A/B Hook for Placement Testing

```tsx
// A/B test: show banner above vs. below the CTA
function useProofPlacement(): 'above' | 'below' {
  const [placement] = useState<'above' | 'below'>(() => {
    // Stable per user session
    const stored = sessionStorage.getItem('proof-placement')
    if (stored) return stored as 'above' | 'below'
    const val = Math.random() < 0.5 ? 'above' : 'below'
    sessionStorage.setItem('proof-placement', val)
    return val
  })
  return placement
}
```

Track conversions per placement variant in your analytics to determine which performs better.

## Key Rules

- Never query live counts per page render — cache with a 60-120 second TTL.
- Use real, recent data (last 30 min, last hour) rather than all-time counts — specificity beats scale for urgency.
- `role="status"` + `aria-live="polite"` ensures screen readers announce the number without interrupting the user.
- Don't fabricate numbers. Inflated social proof that users can sense is false destroys trust faster than no social proof.
- Counter animation duration should be 800-1200ms — shorter feels like a glitch, longer loses attention.
- On SSR, render a skeleton or nothing; fill with client-fetched data to avoid hydration mismatch.
