# Pattern: Chat Message Bubble

## Overview
Always-visible timestamps and per-message avatars make dense chat threads unreadable and waste vertical space. The pattern addresses this by grouping consecutive messages from the same sender (collapsing redundant avatars), showing timestamps on hover rather than inline, and keeping reaction and status UI out of the normal flow. These decisions are why chat UIs look clean in production but naive implementations look like email threads.

## Message Grouping

```ts
// Group consecutive messages from the same sender
// A "group" ends when: sender changes, or gap > 5 minutes between messages

function groupMessages(messages: Message[]): MessageGroup[] {
  const groups: MessageGroup[] = [];
  const GAP_MS = 5 * 60 * 1000; // 5 minutes

  for (const msg of messages) {
    const lastGroup = groups[groups.length - 1];
    const timeSinceLast = lastGroup
      ? msg.sentAt.getTime() - lastGroup.messages[lastGroup.messages.length - 1].sentAt.getTime()
      : Infinity;

    if (lastGroup && lastGroup.senderId === msg.senderId && timeSinceLast < GAP_MS) {
      lastGroup.messages.push(msg);
    } else {
      groups.push({
        senderId: msg.senderId,
        senderName: msg.senderName,
        senderAvatar: msg.senderAvatar,
        messages: [msg],
      });
    }
  }
  return groups;
}
```

## Bubble Component

```tsx
function MessageGroup({ group, currentUserId }: Props) {
  const isSelf = group.senderId === currentUserId;

  return (
    // Align the entire group left (others) or right (self)
    <div className={`message-group ${isSelf ? 'message-group--self' : 'message-group--other'}`}>
      {/* Avatar only once per group, aligned to the bottom of the group */}
      {!isSelf && (
        <img
          src={group.senderAvatar}
          alt={group.senderName}
          className="message-group__avatar"
        />
      )}

      <div className="message-group__bubbles">
        {/* Show sender name only for groups from others in group chats */}
        {!isSelf && <span className="message-group__name">{group.senderName}</span>}

        {group.messages.map((msg, i) => (
          <MessageBubble
            key={msg.id}
            message={msg}
            isSelf={isSelf}
            // First bubble in group: show top corners; last: show bottom corners
            position={
              i === 0 && group.messages.length === 1 ? 'only'
              : i === 0 ? 'first'
              : i === group.messages.length - 1 ? 'last'
              : 'middle'
            }
          />
        ))}
      </div>
    </div>
  );
}

function MessageBubble({ message, isSelf, position }: BubbleProps) {
  const [showTimestamp, setShowTimestamp] = useState(false);

  return (
    <div
      className={`bubble bubble--${isSelf ? 'self' : 'other'} bubble--${position}`}
      // Show timestamp on hover/focus — not always visible
      onMouseEnter={() => setShowTimestamp(true)}
      onMouseLeave={() => setShowTimestamp(false)}
    >
      <p className="bubble__text">{message.text}</p>

      {/* Timestamp tooltip — positioned above or below depending on position in group */}
      {showTimestamp && (
        <span className="bubble__timestamp" role="tooltip">
          {formatTime(message.sentAt)}
        </span>
      )}

      {/* Status icons — only on the last message in a self group */}
      {isSelf && position === 'last' && (
        <MessageStatus status={message.status} />
      )}

      {/* Reactions rendered below the bubble, not inside it */}
      {message.reactions.length > 0 && (
        <ReactionBar reactions={message.reactions} messageId={message.id} />
      )}
    </div>
  );
}
```

## Bubble Shape via CSS

```css
/* Border radius changes based on group position */
/* This creates the "connected" bubble chain look */
.bubble {
  border-radius: 18px;
  padding: 8px 14px;
  max-width: 70%;
}

/* First bubble: normal top corners, small bottom corner on the sender's side */
.bubble--self.bubble--first { border-bottom-right-radius: 4px; }
.bubble--self.bubble--middle { border-top-right-radius: 4px; border-bottom-right-radius: 4px; }
.bubble--self.bubble--last { border-top-right-radius: 4px; }

.bubble--other.bubble--first { border-bottom-left-radius: 4px; }
.bubble--other.bubble--middle { border-top-left-radius: 4px; border-bottom-left-radius: 4px; }
.bubble--other.bubble--last { border-top-left-radius: 4px; }
```

## Message Status

```tsx
// Sent → Delivered → Read — only show the highest status
function MessageStatus({ status }: { status: 'sending' | 'sent' | 'delivered' | 'read' }) {
  const icons = {
    sending: '○',   // Clock or spinner
    sent: '✓',      // Single check
    delivered: '✓✓', // Double check, grey
    read: '✓✓',     // Double check, blue
  };
  return (
    <span
      className={`msg-status msg-status--${status}`}
      aria-label={status}
    >
      {icons[status]}
    </span>
  );
}
```

## Key Rules
- Group consecutive same-sender messages — collapse avatar to once per group
- Show timestamps on hover/tap, not always-visible — they consume vertical space and add noise
- Show message status icons (sent/delivered/read) only on the last message in a self group
- Use CSS border-radius variants for grouped bubble shapes — the connected chain is a visual cue
- Render reactions below bubbles, not inside them — reactions grow the container unpredictably
- In group chats, show the sender name only above the first bubble of a group, not every bubble
- Align self messages right, others left — never center-align chat bubbles
