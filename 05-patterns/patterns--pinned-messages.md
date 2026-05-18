# Pattern: Pinned Messages

## Overview
Pinned messages need a permission layer because pinning/unpinning changes what everyone sees. Without it, any participant can bury important announcements by pinning noise. The banner must be dismissible per-session without removing the pin, because a permanent banner that can't be cleared becomes visual clutter that everyone ignores. Scroll-to-message requires knowing the message's position in a potentially virtualized list.

## Data Model

```sql
-- Pin state lives on the message, not in a separate table
-- One pinned_at + pinned_by is sufficient for most apps
ALTER TABLE messages ADD COLUMN pinned_at TIMESTAMPTZ;
ALTER TABLE messages ADD COLUMN pinned_by UUID REFERENCES users(id);

-- For ordered multiple pins, a separate table makes sense
CREATE TABLE pinned_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id),
  message_id UUID NOT NULL REFERENCES messages(id),
  pinned_by UUID NOT NULL REFERENCES users(id),
  pinned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  display_order INT NOT NULL DEFAULT 0,
  UNIQUE(conversation_id, message_id)
);
```

## Pin/Unpin with Permission Check

```ts
async function pinMessage(
  conversationId: string,
  messageId: string,
  actorId: string
) {
  // Check permission before any write
  const actor = await db.conversationParticipants.findUnique({
    where: { conversationId_userId: { conversationId, userId: actorId } },
  });
  if (!actor || actor.role !== 'admin') {
    throw new Error('Only admins can pin messages');
  }

  await db.pinnedMessages.upsert({
    where: { conversationId_messageId: { conversationId, messageId } },
    create: { conversationId, messageId, pinnedBy: actorId, displayOrder: 0 },
    update: {}, // Already pinned — idempotent
  });

  // Broadcast pin event via websocket so all participants see the banner appear
  broadcastEvent(conversationId, { type: 'message_pinned', messageId, pinnedBy: actorId });
}

async function unpinMessage(conversationId: string, messageId: string, actorId: string) {
  const actor = await db.conversationParticipants.findUnique({
    where: { conversationId_userId: { conversationId, userId: actorId } },
  });
  if (!actor || actor.role !== 'admin') {
    throw new Error('Only admins can unpin messages');
  }

  await db.pinnedMessages.delete({
    where: { conversationId_messageId: { conversationId, messageId } },
  });

  broadcastEvent(conversationId, { type: 'message_unpinned', messageId });
}
```

## Pinned Messages Banner

```tsx
function PinnedMessagesBanner({ conversationId }: Props) {
  const pins = usePinnedMessages(conversationId);
  const [dismissed, setDismissed] = useSessionState<Set<string>>('dismissed-pins', new Set());
  const [activeIndex, setActiveIndex] = useState(0);

  // Filter out session-dismissed pins — they're still pinned, just hidden for this session
  const visible = pins.filter(p => !dismissed.has(p.id));
  if (visible.length === 0) return null;

  const current = visible[activeIndex % visible.length];

  return (
    <div className="pinned-banner" role="complementary" aria-label="Pinned messages">
      <PinIcon />
      {/* Count badge when multiple pins exist */}
      {visible.length > 1 && (
        <button onClick={() => setActiveIndex(i => (i + 1) % visible.length)} className="pin-count">
          {activeIndex + 1} / {visible.length}
        </button>
      )}
      {/* Click banner to scroll to the message in the thread */}
      <button
        className="pinned-banner__text"
        onClick={() => scrollToMessage(current.messageId)}
      >
        <span className="pinned-banner__label">Pinned</span>
        <span className="pinned-banner__preview">{current.textPreview}</span>
      </button>
      {/* Dismiss for this session only — does not unpin */}
      <button
        onClick={() => setDismissed(s => new Set([...s, current.id]))}
        aria-label="Dismiss pinned message banner"
      >
        ✕
      </button>
    </div>
  );
}
```

## Scroll to Message

```ts
// Scroll-to-message works differently depending on whether list is virtualized
// For virtualized lists, you need the virtualizer's scrollToIndex

function scrollToMessage(messageId: string) {
  // Non-virtualized: use DOM directly
  const el = document.getElementById(`msg-${messageId}`);
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    // Highlight briefly so the user knows which message they landed on
    el.classList.add('msg--highlight');
    setTimeout(() => el.classList.remove('msg--highlight'), 2000);
    return;
  }

  // Message not in DOM (scrolled out of virtual window): load and jump
  // This requires the virtualizer to support scrollToIndex by message ID
  virtualizerRef.current?.scrollToMessage(messageId);
}
```

## Unpin Confirmation

```tsx
// Only ask for confirmation on unpin — the action affects all participants
function UnpinConfirm({ messageId, onConfirm, onCancel }: Props) {
  return (
    <div className="unpin-confirm" role="dialog">
      <p>Unpin this message for everyone?</p>
      <button onClick={onConfirm}>Unpin</button>
      <button onClick={onCancel}>Cancel</button>
    </div>
  );
}
```

## Key Rules
- Gate pin/unpin behind a role check (admin only) — enforce server-side, not just client-side
- Broadcast pin/unpin events via websocket — all participants must see the banner change in real-time
- Banner dismiss is session-only — it hides the banner for this user this session, does not unpin
- Cycle through multiple pins with prev/next; show "N / total" count badge
- Clicking the banner scrolls to the message in the thread and briefly highlights it
- Require confirmation before unpinning — it's a multi-user action that's easy to misfire
- Store `pinned_by` and `pinned_at` for audit purposes
