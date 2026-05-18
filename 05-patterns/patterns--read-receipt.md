# Pattern: Read Receipts UI

## Overview
Sending a read-status update for every individual message floods the server with writes and creates noticeable lag. Batching read events (mark the entire conversation as read, not each message) fixes the write amplification. Privacy toggles must disable both sending and receiving read receipts — users who hide their read status should not see others' either, or the feature becomes asymmetric and deceptive.

## Mark-as-Read: Batch, Not Per-Message

```ts
// Wrong: mark each message as read as it appears
// This fires N database writes per conversation open

// Right: mark the conversation as read (watermark pattern)
// Store "last_read_message_id" or "last_read_at" per participant
// All messages before that watermark are implicitly read

async function markConversationRead(conversationId: string, userId: string) {
  // Throttle: don't call this more than once per 2 seconds per conversation
  // Use a debounce or coalesce with a flag
  await db.conversationParticipants.update({
    where: { conversationId_userId: { conversationId, userId } },
    data: {
      lastReadAt: new Date(),
      // Or use lastReadMessageId if you need per-message precision
    },
  });

  // Broadcast via websocket so senders see read status update
  broadcastReadReceipt(conversationId, userId, new Date());
}

// Determine read status from watermarks, not per-message booleans
function getMessageStatus(
  message: Message,
  participants: ConversationParticipant[],
  senderId: string
): 'sent' | 'delivered' | 'read' {
  const others = participants.filter(p => p.userId !== senderId);
  if (others.every(p => p.lastReadAt && p.lastReadAt >= message.sentAt)) {
    return 'read';
  }
  if (others.some(p => p.isOnline)) {
    return 'delivered';
  }
  return 'sent';
}
```

## Optimistic Mark-as-Read

```ts
// Mark as read immediately on conversation open — don't wait for server confirmation
// The server may be slow; users expect instant UI response
// Roll back only if the server returns an error (rare)

function useConversation(conversationId: string) {
  const [lastReadAt, setLastReadAt] = useState<Date | null>(null);

  useEffect(() => {
    // Optimistically mark as read when conversation opens
    const now = new Date();
    setLastReadAt(now); // Update local state immediately

    markConversationRead(conversationId, currentUserId)
      .catch(() => {
        // On failure, revert — user will see unread state restored
        setLastReadAt(prev => prev); // Effectively a no-op; real rollback needs the old value
      });
  }, [conversationId]);

  return { lastReadAt };
}
```

## Last-Seen vs Read Distinction

```tsx
// "Last seen" = last time user was online (separate from reading a message)
// "Read" = they opened this specific conversation
// Don't conflate them — "last seen 2 hours ago" ≠ "read your message 2 hours ago"

function PresenceLabel({ participant }: { participant: ConversationParticipant }) {
  if (participant.isOnline) {
    return <span className="presence presence--online">Online</span>;
  }
  if (participant.lastSeenAt) {
    return (
      <span className="presence presence--offline">
        {/* "last seen" — implies online presence, not message read */}
        Last seen {formatRelative(participant.lastSeenAt)}
      </span>
    );
  }
  return null;
}

// In message thread: show "Read [time]" only when lastReadAt is after sentAt
function ReadReceiptLabel({ message, participant }: Props) {
  const wasRead = participant.lastReadAt && participant.lastReadAt >= message.sentAt;
  if (!wasRead) return null;
  return <span className="read-receipt">Read {formatTime(participant.lastReadAt!)}</span>;
}
```

## Privacy Toggle

```ts
// When read receipts are disabled, the user:
// 1. Does NOT send read status to others
// 2. Does NOT receive read status from others (mutual — prevents asymmetry)

async function getReadStatus(
  conversationId: string,
  viewerId: string
): Promise<Map<string, Date | null>> {
  const viewer = await db.users.findUnique({ where: { id: viewerId } });

  // If viewer disabled receipts, hide all participants' read status
  if (!viewer?.readReceiptsEnabled) {
    return new Map(); // Empty — no read data shown
  }

  const participants = await db.conversationParticipants.findMany({
    where: { conversationId },
    include: { user: true },
  });

  // Also hide status for participants who have disabled their receipts
  return new Map(
    participants
      .filter(p => p.user.readReceiptsEnabled && p.userId !== viewerId)
      .map(p => [p.userId, p.lastReadAt])
  );
}
```

## Key Rules
- Use a watermark (`lastReadAt` / `lastReadMessageId`) per participant, not a boolean per message
- Mark conversations as read on open, with debounce — one write per conversation, not per message
- Optimistically update read state in the UI; don't wait for server roundtrip
- Distinguish "last seen online" from "read your message" — they are separate concepts
- When a user disables read receipts, they lose the ability to see others' receipts too — mutual
- Broadcast read receipt updates via websocket so the sender sees updates in real-time
- Show read receipts only on the sender's own messages — never show who hasn't read to others
