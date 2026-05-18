# Pattern: Skeleton Loading for Forms

## Overview
Form skeletons prevent layout shift while form data loads (e.g., an edit form fetching existing values). The skeleton must approximate the real form's layout closely enough that the transition doesn't cause a jarring reflow. Over-engineering skeletons with many fields creates unnecessary code; 3-4 fields at representative widths captures the visual structure without pixel-perfect matching.

## Implementation

### Skeleton primitives

```tsx
function SkeletonLine({ width = 'w-full', height = 'h-4' }: { width?: string; height?: string }) {
  return (
    <div
      className={`${width} ${height} bg-gray-200 rounded animate-pulse`}
      aria-hidden="true"
    />
  )
}

function SkeletonField({ labelWidth = 'w-24', inputWidth = 'w-full' }: {
  labelWidth?: string
  inputWidth?: string
}) {
  return (
    <div className="space-y-1.5">
      <SkeletonLine width={labelWidth} height="h-3.5" />
      <SkeletonLine width={inputWidth} height="h-9" />
    </div>
  )
}
```

### Form skeleton component

```tsx
function UserProfileFormSkeleton() {
  return (
    <div
      className="space-y-5"
      role="status"
      aria-label="Loading profile form"
    >
      {/* Name field — full width */}
      <SkeletonField labelWidth="w-16" inputWidth="w-full" />

      {/* Email — full width */}
      <SkeletonField labelWidth="w-12" inputWidth="w-full" />

      {/* Phone — medium width (phone numbers aren't long) */}
      <SkeletonField labelWidth="w-16" inputWidth="w-64" />

      {/* Bio textarea — taller */}
      <div className="space-y-1.5">
        <SkeletonLine width="w-8" height="h-3.5" />
        <SkeletonLine width="w-full" height="h-20" />
      </div>

      {/* Submit button */}
      <SkeletonLine width="w-28" height="h-9" />
    </div>
  )
}
```

### Fade transition from skeleton to real form

```tsx
function UserProfileForm({ userId }: { userId: string }) {
  const { data: profile, isLoading } = useQuery({
    queryKey: ['profile', userId],
    queryFn: () => fetchProfile(userId),
  })

  return (
    // Relative container maintains layout height during transition
    <div className="relative">
      <div
        className="transition-opacity duration-200"
        style={{ opacity: isLoading ? 0 : 1, pointerEvents: isLoading ? 'none' : 'auto' }}
        aria-hidden={isLoading}
      >
        {profile && <RealProfileForm profile={profile} />}
      </div>

      {isLoading && (
        <div className="absolute inset-0">
          <UserProfileFormSkeleton />
        </div>
      )}
    </div>
  )
}
```

### Alternative: conditional render with minimum skeleton duration

```tsx
function EditItemForm({ itemId }: { itemId: string }) {
  const { data, isLoading, isError } = useQuery(...)
  const [minTimeElapsed, setMinTimeElapsed] = useState(false)

  // Avoid flashing skeleton for fast responses (< 150ms)
  useEffect(() => {
    const timer = setTimeout(() => setMinTimeElapsed(true), 150)
    return () => clearTimeout(timer)
  }, [])

  if (isError) return <ErrorState type="server-error" />

  // Show skeleton if still loading after the minimum threshold
  if (isLoading && minTimeElapsed) return <EditItemFormSkeleton />

  // Show nothing (or previous data via keepPreviousData) during fast loads
  if (isLoading) return null

  return <RealEditItemForm item={data} />
}
```

### Matching field widths to content

```tsx
// Approximate real field widths for realistic skeleton
const fieldWidths = {
  firstName: 'w-48',   // Short text
  lastName: 'w-48',
  email: 'w-full',     // Could be long
  phone: 'w-40',       // Fixed length
  city: 'w-56',
  state: 'w-24',
  zip: 'w-24',
  bio: 'w-full',       // Textarea — always full
}
```

## Key Rules
- Skeleton labels should be ~60-70% of a typical label width (avoid exact guessing)
- Skeleton inputs should match the approximate height of the real input (`h-9` for standard, `h-20` for textarea)
- Maximum 4-5 skeleton fields — don't skeleton every single field for a 20-field form
- Use `opacity` transition rather than `display: none` toggle to prevent layout shift
- The skeleton container must have the same width/layout as the real form to prevent reflow
- Add `role="status"` and `aria-label` so screen readers announce the loading state
- `animate-pulse` (Tailwind) or CSS `@keyframes pulse` creates the shimmer effect — keep it subtle
- Never show skeleton and real content simultaneously — absolute positioning for the overlap transition
