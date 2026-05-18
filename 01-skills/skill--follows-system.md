# Skill: Follows / Subscriptions System

## Overview

User-to-user or user-to-content following. Powers activity feeds, notifications, and content personalization. Key consideration: fan-out on write vs fan-out on read for activity feeds (at scale, pre-compute timelines rather than querying all followed users on each feed load).

## Database Schema

```sql
CREATE TABLE follows (
  follower_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id)
);

CREATE INDEX follows_followee_idx ON follows (followee_id);  -- Who follows this user?
CREATE INDEX follows_follower_idx ON follows (follower_id);  -- Who does this user follow?
```

## Follow / Unfollow

```ts
async function follow(followerId: string, followeeId: string): Promise<void> {
  if (followerId === followeeId) throw new Error('Cannot follow yourself')

  await db.insert(follows)
    .values({ followerId, followeeId })
    .onConflictDoNothing()  // Idempotent — second follow is a no-op

  // Notify the followee
  await createNotification({
    userId: followeeId,
    type: 'new_follower',
    actorId: followerId,
  })
}

async function unfollow(followerId: string, followeeId: string): Promise<void> {
  await db.delete(follows)
    .where(and(eq(follows.followerId, followerId), eq(follows.followeeId, followeeId)))
}

async function isFollowing(followerId: string, followeeId: string): Promise<boolean> {
  const row = await db.query.follows.findFirst({
    where: and(eq(follows.followerId, followerId), eq(follows.followeeId, followeeId)),
  })
  return !!row
}
```

## Follower Counts (Cached)

Querying counts on every profile page is expensive at scale. Denormalize counts:

```sql
ALTER TABLE users ADD COLUMN followers_count INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN following_count INTEGER DEFAULT 0;
```

```ts
// Update atomically on follow
await db.transaction(async tx => {
  await tx.insert(follows).values({ followerId, followeeId }).onConflictDoNothing()
  await tx.update(users)
    .set({ followersCount: sql`followers_count + 1` })
    .where(eq(users.id, followeeId))
  await tx.update(users)
    .set({ followingCount: sql`following_count + 1` })
    .where(eq(users.id, followerId))
})
```

## Feed Generation (Fan-Out on Read)

For small/mid-scale apps, generate the feed on request:

```ts
async function getFeed(userId: string, cursor?: string, limit = 20) {
  // Get who the user follows
  const following = await db.query.follows.findMany({
    where: eq(follows.followerId, userId),
    columns: { followeeId: true },
  })
  const followeeIds = following.map(f => f.followeeId)

  if (followeeIds.length === 0) return { posts: [], nextCursor: null }

  // Get recent posts from followed users
  const posts = await db.query.posts.findMany({
    where: and(
      inArray(posts.userId, followeeIds),
      cursor ? lt(posts.createdAt, new Date(cursor)) : undefined,
    ),
    orderBy: [desc(posts.createdAt)],
    limit: limit + 1,  // Fetch one extra to detect next page
    with: { author: true },
  })

  const hasMore = posts.length > limit
  return {
    posts: posts.slice(0, limit),
    nextCursor: hasMore ? posts[limit - 1].createdAt.toISOString() : null,
  }
}
```

## Mutual Follow Detection

```ts
async function getMutualStatus(viewerUserId: string, targetUserId: string) {
  const [viewerFollowsTarget, targetFollowsViewer] = await Promise.all([
    isFollowing(viewerUserId, targetUserId),
    isFollowing(targetUserId, viewerUserId),
  ])

  return {
    isFollowing: viewerFollowsTarget,
    isFollowedBy: targetFollowsViewer,
    isMutual: viewerFollowsTarget && targetFollowsViewer,
  }
}
```

## Suggested Users to Follow

```sql
-- Friends of friends not yet followed
SELECT DISTINCT f2.followee_id, u.name, u.avatar_url
FROM follows f1
JOIN follows f2 ON f2.follower_id = f1.followee_id
JOIN users u ON u.id = f2.followee_id
WHERE f1.follower_id = $1                        -- People the user follows
  AND f2.followee_id != $1                       -- Not the user themselves
  AND NOT EXISTS (                               -- Not already following
    SELECT 1 FROM follows WHERE follower_id = $1 AND followee_id = f2.followee_id
  )
LIMIT 10;
```

## Key Rules

- Primary key on `(follower_id, followee_id)` prevents duplicate follows at DB level.
- `ON DELETE CASCADE` removes follows when either user is deleted.
- Fan-out on read (query at read time) is fine up to ~10K follows per user. Beyond that, pre-compute timelines.
- Denormalize counts — don't run `COUNT(*)` on every profile page request.
