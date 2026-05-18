# Pattern: Nested Comments

## Overview

Threaded comments (Reddit/HN style) with reply-to depth limiting. The key decisions: max nesting depth (3 levels is typical — beyond that, collapse to a "continue thread" link), how to store the tree (adjacency list is simpler, nested sets are faster for reads), and whether to sort by time or score.

## Database Schema

Adjacency list — simple and sufficient for most apps:

```sql
CREATE TABLE comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  parent_id   UUID REFERENCES comments(id) ON DELETE CASCADE,  -- NULL = top-level
  author_id   UUID NOT NULL REFERENCES users(id),
  body        TEXT NOT NULL,
  score       INTEGER NOT NULL DEFAULT 0,
  deleted_at  TIMESTAMPTZ,     -- soft delete — preserve thread structure
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX comments_post_id_idx ON comments(post_id, created_at DESC);
CREATE INDEX comments_parent_id_idx ON comments(parent_id);
```

## Fetching a Thread (Recursive CTE)

```ts
async function getCommentTree(postId: string) {
  const rows = await db.execute(sql`
    WITH RECURSIVE thread AS (
      SELECT *, 0 AS depth, ARRAY[created_at] AS sort_path
      FROM comments
      WHERE post_id = ${postId} AND parent_id IS NULL

      UNION ALL

      SELECT c.*, t.depth + 1, t.sort_path || c.created_at
      FROM comments c
      JOIN thread t ON c.parent_id = t.id
      WHERE t.depth < 5  -- hard limit
    )
    SELECT * FROM thread
    WHERE deleted_at IS NULL OR (
      -- Keep deleted comments if they have replies
      EXISTS (SELECT 1 FROM comments WHERE parent_id = thread.id AND deleted_at IS NULL)
    )
    ORDER BY sort_path
  `)

  return buildTree(rows)
}

function buildTree(rows: CommentRow[]): CommentNode[] {
  const map = new Map<string, CommentNode>()
  const roots: CommentNode[] = []

  for (const row of rows) {
    map.set(row.id, { ...row, children: [] })
  }

  for (const row of rows) {
    const node = map.get(row.id)!
    if (row.parent_id) {
      map.get(row.parent_id)?.children.push(node)
    } else {
      roots.push(node)
    }
  }

  return roots
}
```

## React Component

```tsx
interface CommentNode {
  id: string
  authorName: string
  body: string
  score: number
  depth: number
  deletedAt: string | null
  children: CommentNode[]
}

interface CommentProps {
  comment: CommentNode
  maxDepth?: number
  onReply: (parentId: string) => void
  onVote: (id: string, direction: 1 | -1) => void
}

const MAX_DEPTH = 3

function Comment({ comment, maxDepth = MAX_DEPTH, onReply, onVote }: CommentProps) {
  const [collapsed, setCollapsed] = useState(false)
  const [replyOpen, setReplyOpen] = useState(false)

  const isDeleted = comment.deletedAt !== null
  const hasChildren = comment.children.length > 0
  const atMaxDepth = comment.depth >= maxDepth

  return (
    <div className={cn('flex gap-2', comment.depth > 0 && 'ml-6 border-l-2 border-gray-100 pl-3')}>
      {/* Thread collapse line */}
      <div className="flex-shrink-0">
        <button
          onClick={() => setCollapsed(!collapsed)}
          className="w-px h-full bg-gray-200 hover:bg-blue-300 transition-colors"
          aria-label={collapsed ? 'Expand thread' : 'Collapse thread'}
        />
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 text-sm text-gray-500 mb-1">
          {isDeleted ? (
            <span className="italic">[deleted]</span>
          ) : (
            <>
              <span className="font-medium text-gray-900">{comment.authorName}</span>
              <button onClick={() => onVote(comment.id, 1)}>↑</button>
              <span>{comment.score}</span>
              <button onClick={() => onVote(comment.id, -1)}>↓</button>
            </>
          )}
        </div>

        {!collapsed && (
          <>
            <p className="text-sm text-gray-800 mb-2">
              {isDeleted ? <em>This comment was deleted.</em> : comment.body}
            </p>

            {!isDeleted && (
              <button
                onClick={() => setReplyOpen(!replyOpen)}
                className="text-xs text-gray-500 hover:text-gray-800"
              >
                Reply
              </button>
            )}

            {replyOpen && (
              <ReplyBox
                parentId={comment.id}
                onSubmit={text => { onReply(comment.id); setReplyOpen(false) }}
                onCancel={() => setReplyOpen(false)}
              />
            )}

            {hasChildren && !atMaxDepth && (
              <div className="mt-2 space-y-2">
                {comment.children.map(child => (
                  <Comment
                    key={child.id}
                    comment={child}
                    maxDepth={maxDepth}
                    onReply={onReply}
                    onVote={onVote}
                  />
                ))}
              </div>
            )}

            {hasChildren && atMaxDepth && (
              <a href={`/thread/${comment.id}`} className="text-xs text-blue-500">
                Continue thread →
              </a>
            )}
          </>
        )}
      </div>
    </div>
  )
}
```

## Optimistic Insert

```tsx
function useAddComment(postId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (data: { parentId: string | null; body: string }) =>
      api.post('/api/comments', { postId, ...data }),

    onMutate: async (data) => {
      await queryClient.cancelQueries({ queryKey: ['comments', postId] })
      const prev = queryClient.getQueryData(['comments', postId])

      const optimistic: CommentNode = {
        id: `temp-${Date.now()}`,
        authorName: 'You',
        body: data.body,
        score: 0,
        depth: 0,  // recalculated server-side
        deletedAt: null,
        children: [],
      }

      queryClient.setQueryData(['comments', postId], (old: CommentNode[]) =>
        insertIntoTree(old, data.parentId, optimistic)
      )

      return { prev }
    },

    onError: (_, __, ctx) => {
      queryClient.setQueryData(['comments', postId], ctx?.prev)
    },

    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['comments', postId] })
    },
  })
}
```

## Key Rules

- Soft-delete comments — never hard-delete if they have replies; replace body with "[deleted]" but keep the node.
- Limit recursion depth at both DB level (CTE `WHERE depth < 5`) and UI level (collapse to "continue thread" link).
- Store `parent_id` on the comment row, not a `path` array — adjacency list is easier to insert into and works fine at comment scale.
- Score updates are separate from tree queries — vote without re-fetching the full thread.
