# Skill: Like / Upvote System

## Overview

Toggle-able reactions: likes, upvotes, hearts, or custom emoji reactions. Requires: optimistic UI, accurate counts, one vote per user per item, and real-time updates (optional).

## Database Schema

```sql
CREATE TABLE reactions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,    -- 'post', 'comment', 'product'
  entity_id   UUID NOT NULL,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction    TEXT NOT NULL DEFAULT 'like',  -- supports emoji/custom types
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (entity_type, entity_id, user_id, reaction)  -- one reaction per user per entity
);

CREATE INDEX ON reactions (entity_type, entity_id, reaction);

-- Denormalized count (optional — avoids COUNT(*) on hot read path)
ALTER TABLE posts ADD COLUMN like_count INTEGER NOT NULL DEFAULT 0;

-- Keep count in sync
CREATE OR REPLACE FUNCTION sync_reaction_count() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET like_count = like_count + 1 WHERE id = NEW.entity_id AND NEW.entity_type = 'post';
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET like_count = like_count - 1 WHERE id = OLD.entity_id AND OLD.entity_type = 'post';
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER reactions_count_sync
AFTER INSERT OR DELETE ON reactions
FOR EACH ROW EXECUTE FUNCTION sync_reaction_count();
```

The `UNIQUE` constraint is the enforcement mechanism — attempting to insert a duplicate reaction throws a `23505` error instead of creating a duplicate row.

The denormalized `like_count` eliminates a COUNT query on every page load. The trigger keeps it accurate.

## Toggle Hook

```ts
'use client'
import { useState, useOptimistic } from 'react'

interface ReactionState {
  liked: boolean
  count: number
}

export function useLike(entityType: string, entityId: string, initial: ReactionState) {
  const [optimistic, addOptimistic] = useOptimistic(
    initial,
    (state, action: 'like' | 'unlike') => ({
      liked: action === 'like',
      count: state.count + (action === 'like' ? 1 : -1),
    }),
  )

  async function toggle() {
    const action = optimistic.liked ? 'unlike' : 'like'
    addOptimistic(action)  // Instant UI update

    try {
      await toggleReaction({ entityType, entityId, reaction: 'like' })
    } catch {
      // useOptimistic auto-reverts on error in React 19
    }
  }

  return { ...optimistic, toggle }
}
```

React 19's `useOptimistic` automatically reverts to the pre-optimistic state when the server action throws. In React 18, manage rollback manually with a ref.

## Server Action

```ts
'use server'
import { revalidatePath } from 'next/cache'

export async function toggleReaction({
  entityType,
  entityId,
  reaction,
}: {
  entityType: string
  entityId: string
  reaction: string
}) {
  const supabase = createServerActionClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  // Try to delete first (unlike)
  const { count } = await supabase
    .from('reactions')
    .delete({ count: 'exact' })
    .eq('entity_type', entityType)
    .eq('entity_id', entityId)
    .eq('user_id', user.id)
    .eq('reaction', reaction)

  if (count === 0) {
    // Didn't exist — insert it (like)
    const { error } = await supabase.from('reactions').insert({
      entity_type: entityType,
      entity_id: entityId,
      user_id: user.id,
      reaction,
    })

    if (error?.code === '23505') {
      // Race condition — another request beat us. That's fine.
      return
    }
    if (error) throw error
  }
}
```

## Like Button Component

```tsx
import { useLike } from '@/hooks/useLike'
import { HeartIcon } from 'lucide-react'

export function LikeButton({
  entityType,
  entityId,
  initialLiked,
  initialCount,
}: {
  entityType: string
  entityId: string
  initialLiked: boolean
  initialCount: number
}) {
  const { liked, count, toggle } = useLike(entityType, entityId, {
    liked: initialLiked,
    count: initialCount,
  })

  return (
    <button
      onClick={toggle}
      className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm transition-colors
        ${liked
          ? 'bg-red-50 text-red-600 hover:bg-red-100'
          : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
        }`}
      aria-label={liked ? 'Unlike' : 'Like'}
      aria-pressed={liked}
    >
      <HeartIcon className={`w-4 h-4 ${liked ? 'fill-current' : ''}`} />
      <span>{count}</span>
    </button>
  )
}
```

## Checking Whether Current User Liked

When fetching posts server-side, join with reactions to get the user's reaction state:

```ts
async function getPosts(userId: string | null) {
  let query = supabase
    .from('posts')
    .select(`
      id, title, like_count,
      user_reaction:reactions!inner(id)
    `)
    .order('created_at', { ascending: false })

  // Left join — need to handle null when user hasn't liked
  if (userId) {
    query = query.eq('user_reaction.user_id', userId).eq('user_reaction.reaction', 'like')
  }

  const { data } = await query
  return (data ?? []).map((post) => ({
    ...post,
    liked: Array.isArray(post.user_reaction) && post.user_reaction.length > 0,
  }))
}
```

## Multiple Reaction Types

```ts
// Emoji reactions: 👍 ❤️ 🎉 😮 😢 😡
const REACTIONS = ['👍', '❤️', '🎉', '😮', '😢', '😡'] as const

function ReactionPicker({ entityId }: { entityId: string }) {
  const [counts, setCounts] = useState<Record<string, number>>({})

  return (
    <div className="flex gap-1 p-1 bg-white border rounded-full shadow-lg">
      {REACTIONS.map((emoji) => (
        <button
          key={emoji}
          onClick={() => toggleReaction({ entityType: 'post', entityId, reaction: emoji })}
          className="w-8 h-8 text-lg hover:scale-125 transition-transform"
        >
          {emoji}
        </button>
      ))}
    </div>
  )
}
```
