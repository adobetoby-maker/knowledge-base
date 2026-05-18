# Pattern: User Profile Card

A user profile card displaying avatar, name, bio, stats, and social links. Supports avatar fallback to initials, hover quick-actions, and optimistic follow/unfollow.

## Avatar with Initials Fallback

Images fail. Always provide a fallback that derives initials from the user's name and assigns a deterministic color so the same user always gets the same color.

```tsx
function Avatar({ user, size = 'md' }: { user: User; size?: 'sm' | 'md' | 'lg' }) {
  const [imgError, setImgError] = useState(false);

  const initials = user.name
    .split(' ')
    .map(n => n[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();

  // Deterministic color from user id — same user always same color
  const colors = ['bg-red-500', 'bg-orange-500', 'bg-amber-500', 'bg-green-500',
                  'bg-teal-500', 'bg-blue-500', 'bg-violet-500', 'bg-pink-500'];
  const colorIndex = user.id.charCodeAt(0) % colors.length;
  const bgColor = colors[colorIndex];

  const sizeClasses = { sm: 'w-8 h-8 text-xs', md: 'w-12 h-12 text-sm', lg: 'w-16 h-16 text-base' };

  if (!user.avatarUrl || imgError) {
    return (
      <div className={cn('rounded-full flex items-center justify-center font-semibold text-white', bgColor, sizeClasses[size])}>
        {initials}
      </div>
    );
  }

  return (
    <img
      src={user.avatarUrl}
      alt={user.name}
      className={cn('rounded-full object-cover', sizeClasses[size])}
      onError={() => setImgError(true)}
    />
  );
}
```

Never use a generic silhouette fallback — initials feel personal. The color derivation from `charCodeAt(0)` is crude but consistent; use a proper hash for better distribution if needed.

## Card Layout

```tsx
function ProfileCard({ user, currentUserId }: { user: User; currentUserId: string }) {
  const [showActions, setShowActions] = useState(false);
  const isOwnProfile = user.id === currentUserId;

  return (
    <div
      className="relative rounded-xl border bg-card p-6 space-y-4 group"
      onMouseEnter={() => setShowActions(true)}
      onMouseLeave={() => setShowActions(false)}
    >
      {/* Hover quick-action overlay */}
      {!isOwnProfile && (
        <div className={cn(
          'absolute top-3 right-3 flex gap-2 transition-opacity',
          showActions ? 'opacity-100' : 'opacity-0 pointer-events-none'
        )}>
          <IconButton icon={<MessageIcon />} label="Message" onClick={() => openDM(user.id)} />
          <IconButton icon={<ShareIcon />} label="Share profile" onClick={() => shareProfile(user)} />
        </div>
      )}

      {/* Header */}
      <div className="flex items-start gap-4">
        <Avatar user={user} size="lg" />
        <div className="min-w-0">
          <h3 className="font-semibold truncate">{user.name}</h3>
          <p className="text-sm text-muted-foreground">@{user.handle}</p>
        </div>
      </div>

      {/* Bio */}
      {user.bio && (
        <p className="text-sm text-foreground/80 line-clamp-3">{user.bio}</p>
      )}

      {/* Stats */}
      <div className="flex gap-6 text-sm">
        <Stat label="Posts" value={user.postCount} />
        <Stat label="Followers" value={user.followerCount} />
        <Stat label="Following" value={user.followingCount} />
      </div>

      {/* Social links */}
      {user.links && <SocialLinks links={user.links} />}

      {/* Follow button */}
      {!isOwnProfile && <FollowButton userId={user.id} initialFollowing={user.isFollowing} />}
    </div>
  );
}
```

## Optimistic Follow/Unfollow

Optimistic updates make follow feel instant. Revert on error.

```tsx
function FollowButton({ userId, initialFollowing }: { userId: string; initialFollowing: boolean }) {
  const [following, setFollowing] = useState(initialFollowing);
  const [isLoading, setIsLoading] = useState(false);

  const toggle = async () => {
    const newValue = !following;
    setFollowing(newValue); // optimistic

    setIsLoading(true);
    try {
      await fetch(`/api/users/${userId}/follow`, {
        method: newValue ? 'POST' : 'DELETE',
      });
    } catch {
      setFollowing(!newValue); // revert
      toast.error('Failed to update follow status');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Button
      onClick={toggle}
      variant={following ? 'outline' : 'default'}
      size="sm"
      disabled={isLoading}
      className="w-full"
    >
      {following ? 'Following' : 'Follow'}
    </Button>
  );
}
```

## Hover Quick Actions

Hover actions use `opacity` + `pointer-events-none` rather than `display: none` so they can animate in. The `group` class on the card and `group-hover:opacity-100` as an alternative to JS-driven state is cleaner:

```tsx
// CSS-only alternative — no JS state needed:
<div className="absolute top-3 right-3 flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity focus-within:opacity-100">
```

The `focus-within:opacity-100` is critical — keyboard users tabbing to the action buttons should also reveal them.

## Stats Formatting

Large numbers need formatting:

```tsx
function Stat({ label, value }: { label: string; value: number }) {
  const formatted = value >= 1000
    ? `${(value / 1000).toFixed(1)}k`
    : value.toString();

  return (
    <div className="text-center">
      <div className="font-semibold">{formatted}</div>
      <div className="text-xs text-muted-foreground">{label}</div>
    </div>
  );
}
```

## Key Rules

- Always implement an initials fallback — `onError` on `<img>` handles CDN failures silently
- Deterministic color from user ID ensures the same user always gets the same avatar color
- Hide own follow button: `isOwnProfile` check prevents following yourself
- `pointer-events-none` on hidden hover actions prevents accidental clicks on invisible buttons
- Add `focus-within:opacity-100` to hover action overlays — keyboard users need them too
- Optimistic follow: update state before the network call, revert on catch
