# Pattern: Thread Reply (Slack-Style)

## Overview

Thread replies are a secondary comment layer on a parent message. Key behaviors: clicking "Reply" opens a thread panel, thread count shown on parent, collapsible thread preview, and notification to participants. The data model is a simple parent_id foreign key — not a recursive tree (threads are one level deep).

## Data Model

```sql
CREATE TABLE messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id  uuid NOT NULL REFERENCES channels(id),
  user_id     uuid NOT NULL REFERENCES users(id),
  body        text NOT NULL,
  parent_id   uuid REFERENCES messages(id),  -- NULL = top-level, set = thread reply
  thread_count int NOT NULL DEFAULT 0,
  latest_thread_reply_at timestamptz,
  created_at  timestamptz DEFAULT now()
);

CREATE INDEX messages_parent_idx ON messages(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX messages_channel_idx ON messages(channel_id) WHERE parent_id IS NULL;
```

The channel feed only shows top-level messages (`WHERE parent_id IS NULL`). Thread replies are fetched separately.

## Updating Thread Count

```sql
-- Trigger: update parent's thread_count when reply is added
CREATE OR REPLACE FUNCTION update_thread_count()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.parent_id IS NOT NULL THEN
    UPDATE messages
    SET
      thread_count = thread_count + 1,
      latest_thread_reply_at = NEW.created_at
    WHERE id = NEW.parent_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_message_insert
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION update_thread_count();
```

## Thread Panel Component

```tsx
interface ThreadPanelProps {
  parentMessage: Message
  onClose: () => void
}

export function ThreadPanel({ parentMessage, onClose }: ThreadPanelProps) {
  const { data: replies, refetch } = useQuery({
    queryKey: ['thread', parentMessage.id],
    queryFn: () => fetchThreadReplies(parentMessage.id),
  })

  return (
    <div className="flex flex-col h-full border-l">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b">
        <h3 className="font-semibold">Thread</h3>
        <button onClick={onClose} aria-label="Close thread" className="p-1 rounded hover:bg-gray-100">×</button>
      </div>

      {/* Parent message */}
      <div className="px-4 py-3 border-b bg-gray-50">
        <MessageItem message={parentMessage} isParent />
      </div>

      {/* Replies */}
      <div className="flex-1 overflow-y-auto px-4 py-3 space-y-4">
        {replies?.map(reply => (
          <MessageItem key={reply.id} message={reply} />
        ))}
      </div>

      {/* Reply input */}
      <div className="px-4 py-3 border-t">
        <ReplyInput parentId={parentMessage.id} onReply={refetch} />
      </div>
    </div>
  )
}
```

## Thread Count Badge on Parent

```tsx
function ThreadCountBadge({ message, onOpen }: { message: Message; onOpen: () => void }) {
  if (message.threadCount === 0) return null

  return (
    <button
      onClick={onOpen}
      className="flex items-center gap-1.5 text-xs text-blue-600 hover:underline mt-1"
    >
      <MessageSquareIcon className="w-3 h-3" />
      <span>{message.threadCount} {message.threadCount === 1 ? 'reply' : 'replies'}</span>
      {message.latestThreadReplyAt && (
        <span className="text-gray-400">
          Last reply {formatRelativeTime(message.latestThreadReplyAt)}
        </span>
      )}
    </button>
  )
}
```

## Real-Time Thread Updates

```tsx
function useThreadRealtime(parentId: string, onNewReply: () => void) {
  useEffect(() => {
    const channel = supabase
      .channel(`thread:${parentId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        filter: `parent_id=eq.${parentId}`,
      }, () => onNewReply())
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [parentId, onNewReply])
}
```

## Thread Participants for Notifications

```ts
async function notifyThreadParticipants(parentId: string, newReplyUserId: string, body: string) {
  // Get all unique users who replied to this thread (excluding current user)
  const participants = await db.selectDistinct({ userId: messages.userId })
    .from(messages)
    .where(and(
      eq(messages.parentId, parentId),
      ne(messages.userId, newReplyUserId),
    ))

  // Also notify the original message author if not already included
  const parent = await db.query.messages.findFirst({ where: eq(messages.id, parentId) })
  if (parent && parent.userId !== newReplyUserId) {
    participants.push({ userId: parent.userId })
  }

  await sendThreadNotifications(
    [...new Set(participants.map(p => p.userId))],
    { parentId, body: body.slice(0, 100) }
  )
}
```

## Key Rules

- Threads are one level deep — never allow replies to replies. This matches Slack's model and avoids recursive tree complexity.
- `thread_count` is a denormalized counter on the parent — don't count with a query on every render. Update via trigger.
- Channel feed queries filter `WHERE parent_id IS NULL` — thread replies are not shown in the main feed.
- Open the thread panel in a side panel, not a modal — threads need context from the main message view.
- Notify all thread participants on new replies, not just the parent author — users subscribe to threads by replying.
