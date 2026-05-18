# Pattern: User Avatar Component

## What This Solves

User avatars appear in headers, comments, data tables, and member lists. The challenges are: gracefully falling back when the image URL is missing or broken, generating consistent initials-based placeholders, maintaining visual variety without randomness, handling multiple sizes uniformly, and showing online presence status.

## Deterministic Color from Name/ID

Random colors per render make avatars flicker between server and client. Hash the user's name or ID to a fixed color from a palette:

```ts
const AVATAR_COLORS = [
  'bg-red-500',    'bg-orange-500', 'bg-amber-500',
  'bg-green-500',  'bg-teal-500',   'bg-cyan-500',
  'bg-blue-500',   'bg-indigo-500', 'bg-violet-500',
  'bg-pink-500',
]

function hashToColor(str: string): string {
  let hash = 0
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i)
    hash |= 0  // convert to 32-bit int
  }
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length]
}

function getInitials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .map(n => n[0].toUpperCase())
    .slice(0, 2)
    .join('')
}
```

Pass the user's `id` to `hashToColor` rather than `name` so renaming a user doesn't change their avatar color.

## Size Variants

Define sizes as a variant map rather than ad-hoc className strings:

```ts
const sizeMap = {
  xs: 'h-5 w-5 text-[9px]',
  sm: 'h-6 w-6 text-[10px]',
  md: 'h-8 w-8 text-xs',
  lg: 'h-10 w-10 text-sm',
  xl: 'h-14 w-14 text-base',
  '2xl': 'h-20 w-20 text-xl',
} as const

type AvatarSize = keyof typeof sizeMap
```

## The Component

```tsx
import Image from 'next/image'

interface UserAvatarProps {
  user: {
    id: string
    name: string
    avatar_url?: string | null
  }
  size?: AvatarSize
  online?: boolean
  loading?: boolean
}

export function UserAvatar({
  user,
  size = 'md',
  online,
  loading = false,
}: UserAvatarProps) {
  const [imgError, setImgError] = useState(false)
  const sizeClass = sizeMap[size]
  const color = hashToColor(user.id)
  const initials = getInitials(user.name)
  const showImage = user.avatar_url && !imgError

  if (loading) {
    return (
      <div
        className={cn(
          sizeClass,
          'rounded-full bg-muted animate-pulse shrink-0'
        )}
        aria-hidden="true"
      />
    )
  }

  return (
    <div className="relative inline-flex shrink-0">
      <div
        className={cn(
          sizeClass,
          'rounded-full overflow-hidden shrink-0',
          !showImage && cn(color, 'flex items-center justify-center font-medium text-white')
        )}
        title={user.name}
      >
        {showImage ? (
          <Image
            src={user.avatar_url!}
            alt={user.name}
            width={80}
            height={80}
            className="object-cover w-full h-full"
            onError={() => setImgError(true)}
          />
        ) : (
          <span aria-hidden="true">{initials}</span>
        )}
      </div>

      {/* Online presence indicator */}
      {online !== undefined && (
        <span
          className={cn(
            'absolute bottom-0 right-0 block rounded-full ring-2 ring-background',
            size === 'xs' || size === 'sm' ? 'h-1.5 w-1.5' : 'h-2.5 w-2.5',
            online ? 'bg-green-500' : 'bg-muted-foreground'
          )}
          aria-label={online ? `${user.name} is online` : `${user.name} is offline`}
        />
      )}
    </div>
  )
}
```

## Image Error Handling

The `onError` callback on the `<Image>` sets local state to hide the broken image and show initials instead. This handles:
- 404 avatar URLs (user deleted their photo)
- CORS-blocked image URLs
- Expired signed storage URLs

Store `imgError` in local component state — do not propagate it to global state.

## Avatar Group (Overlap Stack)

For showing multiple avatars in a compact stack (e.g., "3 users viewing this document"):

```tsx
function AvatarGroup({ users, max = 4 }: { users: User[]; max?: number }) {
  const visible = users.slice(0, max)
  const overflow = users.length - max

  return (
    <div className="flex items-center -space-x-2">
      {visible.map((user) => (
        <UserAvatar
          key={user.id}
          user={user}
          size="sm"
          className="ring-2 ring-background"
        />
      ))}
      {overflow > 0 && (
        <div className="h-6 w-6 rounded-full bg-muted border-2 border-background flex items-center justify-center text-[10px] font-medium text-muted-foreground">
          +{overflow}
        </div>
      )}
    </div>
  )
}
```

## Key Rules

- Hash the user's `id` (not `name`) to derive the fallback color — stable across renames
- Handle `onError` on the image to fall back to initials — never show a broken image icon
- Only show the presence dot when `online` prop is explicitly provided; omit it entirely if undefined
- Use a skeleton (`animate-pulse`) when `loading={true}`, not a spinner
- Use `ring-2 ring-background` on stacked avatars so overlapping edges show a clean separation
- Keep initials to 2 characters maximum — 3-word names should still produce 2 initials
