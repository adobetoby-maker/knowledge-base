# Pattern: User Card / Profile Card

## Overview

Compact user representation shown in comments, team lists, member directories, and tooltip previews. Two variants: inline (avatar + name on one line) and card (avatar + name + bio + stats). Popover cards on hover (LinkedIn-style) need stable mounting — don't use `onMouseEnter`/`onMouseLeave` directly, use Floating UI or Radix HoverCard.

## Inline User Badge

```tsx
interface UserBadgeProps {
  user: {
    id: string
    name: string
    avatarUrl: string | null
    role?: string
  }
  size?: 'sm' | 'md' | 'lg'
  showRole?: boolean
}

export function UserBadge({ user, size = 'md', showRole = false }: UserBadgeProps) {
  const avatarSizes = { sm: 'w-6 h-6', md: 'w-8 h-8', lg: 'w-10 h-10' }
  const nameSizes = { sm: 'text-xs', md: 'text-sm', lg: 'text-base' }

  return (
    <div className="flex items-center gap-2">
      <img
        src={user.avatarUrl ?? `https://api.dicebear.com/7.x/initials/svg?seed=${user.name}`}
        alt={user.name}
        className={cn('rounded-full object-cover flex-shrink-0', avatarSizes[size])}
      />
      <div className="min-w-0">
        <p className={cn('font-medium truncate', nameSizes[size])}>{user.name}</p>
        {showRole && user.role && (
          <p className="text-xs text-gray-500 truncate">{user.role}</p>
        )}
      </div>
    </div>
  )
}
```

## Profile Card (Full)

```tsx
interface ProfileCardProps {
  user: {
    id: string
    name: string
    username: string
    bio: string | null
    avatarUrl: string | null
    followersCount: number
    followingCount: number
    isFollowing: boolean
  }
  onFollow?: () => void
}

export function ProfileCard({ user, onFollow }: ProfileCardProps) {
  return (
    <div className="w-72 bg-white rounded-xl shadow-lg border overflow-hidden">
      {/* Cover (optional) */}
      <div className="h-16 bg-gradient-to-r from-blue-500 to-purple-600" />

      <div className="px-4 pb-4">
        {/* Avatar overlapping cover */}
        <img
          src={user.avatarUrl ?? '/default-avatar.png'}
          alt={user.name}
          className="w-16 h-16 rounded-full border-4 border-white -mt-8 object-cover"
        />

        <div className="mt-2 flex items-start justify-between">
          <div>
            <h3 className="font-semibold text-gray-900">{user.name}</h3>
            <p className="text-sm text-gray-500">@{user.username}</p>
          </div>
          {onFollow && (
            <button
              onClick={onFollow}
              className={cn(
                'px-4 py-1.5 text-sm font-medium rounded-full transition-colors',
                user.isFollowing
                  ? 'border border-gray-300 text-gray-700 hover:bg-gray-50'
                  : 'bg-black text-white hover:bg-gray-800'
              )}
            >
              {user.isFollowing ? 'Following' : 'Follow'}
            </button>
          )}
        </div>

        {user.bio && (
          <p className="mt-2 text-sm text-gray-700 line-clamp-3">{user.bio}</p>
        )}

        <div className="mt-3 flex gap-4 text-sm">
          <span>
            <strong>{formatCount(user.followersCount)}</strong>
            <span className="text-gray-500 ml-1">Followers</span>
          </span>
          <span>
            <strong>{formatCount(user.followingCount)}</strong>
            <span className="text-gray-500 ml-1">Following</span>
          </span>
        </div>
      </div>
    </div>
  )
}

function formatCount(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`
  return String(n)
}
```

## Hover Card (Radix)

```tsx
import * as HoverCard from '@radix-ui/react-hover-card'

export function UserHoverCard({ user, children }: {
  user: ProfileCardProps['user']
  children: React.ReactNode
}) {
  return (
    <HoverCard.Root openDelay={300} closeDelay={150}>
      <HoverCard.Trigger asChild>
        {children}
      </HoverCard.Trigger>
      <HoverCard.Portal>
        <HoverCard.Content side="top" align="start" sideOffset={8}>
          <ProfileCard user={user} />
          <HoverCard.Arrow className="fill-white" />
        </HoverCard.Content>
      </HoverCard.Portal>
    </HoverCard.Root>
  )
}

// Usage
<UserHoverCard user={commenter}>
  <button className="flex items-center gap-2 hover:underline">
    <UserBadge user={commenter} />
  </button>
</UserHoverCard>
```

## Avatar Group (Multiple Users)

```tsx
function AvatarGroup({ users, max = 5 }: { users: { name: string; avatarUrl: string | null }[]; max?: number }) {
  const visible = users.slice(0, max)
  const overflow = users.length - max

  return (
    <div className="flex -space-x-2">
      {visible.map((user, i) => (
        <img
          key={i}
          src={user.avatarUrl ?? '/default-avatar.png'}
          alt={user.name}
          title={user.name}
          className="w-8 h-8 rounded-full border-2 border-white object-cover"
          style={{ zIndex: visible.length - i }}
        />
      ))}
      {overflow > 0 && (
        <div className="w-8 h-8 rounded-full bg-gray-200 border-2 border-white flex items-center justify-center text-xs font-medium text-gray-600">
          +{overflow}
        </div>
      )}
    </div>
  )
}
```

## Key Rules

- Always provide a fallback for null avatarUrl — initials avatar (DiceBear or CSS initials) is better than a broken image.
- `line-clamp-3` on bio prevents long bios from breaking layouts.
- Radix `HoverCard` handles open delay, close delay, and pointer movement naturally — don't implement hover timing manually.
- Follow button should optimistically update `isFollowing` before the API call completes.
- Avatar overlap in groups: use `z-index` stacking with negative margin (`-space-x-2`) — leftmost avatar on top.
