# Skill: Comment System

## Overview

Threaded comments with replies, edit/delete, optimistic updates, and real-time sync. Applicable to blog posts, tickets, invoices, or any entity.

## Database Schema

```sql
CREATE TABLE comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,   -- 'post', 'ticket', 'invoice'
  entity_id   UUID NOT NULL,
  parent_id   UUID REFERENCES comments(id) ON DELETE CASCADE,  -- NULL = top-level
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  body        TEXT NOT NULL CHECK (length(body) > 0 AND length(body) <= 10000),
  edited_at   TIMESTAMPTZ,
  deleted_at  TIMESTAMPTZ,     -- soft delete — preserve thread structure
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ON comments (entity_type, entity_id, created_at);
CREATE INDEX ON comments (parent_id) WHERE parent_id IS NOT NULL;

ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anyone can read non-deleted comments"
  ON comments FOR SELECT USING (deleted_at IS NULL);

CREATE POLICY "authenticated users can insert"
  ON comments FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "owners can update their comments"
  ON comments FOR UPDATE USING (auth.uid() = user_id);
```

## Fetching Threaded Comments

```ts
// Flat list — build tree client-side (better for pagination)
async function getComments(entityType: string, entityId: string) {
  const { data } = await supabase
    .from('comments')
    .select(`
      id, body, parent_id, edited_at, created_at,
      user:user_id (id, email, user_metadata)
    `)
    .eq('entity_type', entityType)
    .eq('entity_id', entityId)
    .is('deleted_at', null)
    .order('created_at', { ascending: true })

  return buildTree(data ?? [])
}

function buildTree(comments: Comment[]): CommentNode[] {
  const map = new Map<string, CommentNode>()
  const roots: CommentNode[] = []

  for (const c of comments) {
    map.set(c.id, { ...c, replies: [] })
  }
  for (const c of comments) {
    const node = map.get(c.id)!
    if (c.parent_id) {
      map.get(c.parent_id)?.replies.push(node)
    } else {
      roots.push(node)
    }
  }
  return roots
}
```

Build the tree client-side from a flat array — simpler than recursive SQL CTEs and easier to paginate. Only go 2-3 levels deep in the UI regardless of database depth.

## Comment Component

```tsx
'use client'
import { useState } from 'react'
import { formatDistanceToNow } from 'date-fns'

function CommentItem({
  comment,
  depth = 0,
  onReply,
  onEdit,
  onDelete,
  currentUserId,
}: CommentItemProps) {
  const [replying, setReplying] = useState(false)
  const [editing, setEditing] = useState(false)
  const isOwner = comment.user.id === currentUserId

  return (
    <div className={`${depth > 0 ? 'ml-8 mt-2' : 'mt-4'} group`}>
      <div className="flex gap-3">
        <Avatar user={comment.user} size="sm" />
        <div className="flex-1">
          <div className="flex items-baseline gap-2">
            <span className="text-sm font-medium">{comment.user.user_metadata.name}</span>
            <span className="text-xs text-gray-400">
              {formatDistanceToNow(new Date(comment.created_at), { addSuffix: true })}
              {comment.edited_at && ' (edited)'}
            </span>
          </div>

          {editing ? (
            <CommentEditor
              initialValue={comment.body}
              onSubmit={(body) => { onEdit(comment.id, body); setEditing(false) }}
              onCancel={() => setEditing(false)}
            />
          ) : (
            <p className="mt-1 text-sm text-gray-700 whitespace-pre-wrap">{comment.body}</p>
          )}

          <div className="mt-1 flex gap-3 opacity-0 group-hover:opacity-100 transition-opacity">
            {depth < 2 && (
              <button onClick={() => setReplying(!replying)} className="text-xs text-gray-500 hover:text-gray-700">
                Reply
              </button>
            )}
            {isOwner && (
              <>
                <button onClick={() => setEditing(true)} className="text-xs text-gray-500 hover:text-gray-700">
                  Edit
                </button>
                <button onClick={() => onDelete(comment.id)} className="text-xs text-red-500 hover:text-red-700">
                  Delete
                </button>
              </>
            )}
          </div>

          {replying && (
            <CommentEditor
              placeholder="Write a reply..."
              onSubmit={(body) => { onReply(comment.id, body); setReplying(false) }}
              onCancel={() => setReplying(false)}
            />
          )}
        </div>
      </div>

      {comment.replies.map((reply) => (
        <CommentItem
          key={reply.id}
          comment={reply}
          depth={depth + 1}
          onReply={onReply}
          onEdit={onEdit}
          onDelete={onDelete}
          currentUserId={currentUserId}
        />
      ))}
    </div>
  )
}
```

## Optimistic Updates with Server Actions

```ts
'use server'
import { revalidatePath } from 'next/cache'

export async function addComment(entityType: string, entityId: string, body: string, parentId?: string) {
  const supabase = createServerActionClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const { data, error } = await supabase.from('comments').insert({
    entity_type: entityType,
    entity_id: entityId,
    user_id: user.id,
    body: body.trim(),
    parent_id: parentId ?? null,
  }).select('id').single()

  if (error) throw error
  revalidatePath(`/posts/${entityId}`)
  return data
}

export async function deleteComment(commentId: string) {
  const supabase = createServerActionClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  // Soft delete — preserves replies
  await supabase
    .from('comments')
    .update({ deleted_at: new Date().toISOString(), body: '[deleted]' })
    .eq('id', commentId)
    .eq('user_id', user.id)  // RLS also enforces this, but be explicit

  revalidatePath('/')
}
```

## Real-Time Comments

```ts
// Subscribe to new comments on an entity
useEffect(() => {
  const channel = supabase
    .channel(`comments:${entityId}`)
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'comments',
      filter: `entity_id=eq.${entityId}`,
    }, (payload) => {
      // Append to comment list (fetch full data including user)
      fetchComment(payload.new.id).then(addToTree)
    })
    .subscribe()

  return () => { supabase.removeChannel(channel) }
}, [entityId])
```

## Soft Delete Convention

When a comment has replies, soft-delete by setting `deleted_at` and replacing `body` with `'[deleted]'`. Preserve the row so replies remain anchored. Only hard-delete leaf comments with no replies.
