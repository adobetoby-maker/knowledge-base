# Pattern: Emoji Reaction System

## Overview
Reactions need optimistic updates because the server roundtrip makes toggle feedback feel sluggish. Counting by emoji rather than listing every user who reacted is the right aggregation level — rendering a list of names per emoji is expensive and the tooltip handles the "who reacted" detail. Showing the most-used emojis first in the picker cuts interaction time because users reach for 👍 and ❤️ far more than obscure symbols.

## Data Model

```sql
-- One row per user per emoji per target — unique constraint prevents duplicates
CREATE TABLE reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type TEXT NOT NULL,   -- 'message', 'comment', 'post'
  target_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id),
  emoji TEXT NOT NULL,         -- Store unicode emoji, not a shortcode
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(target_id, user_id, emoji) -- Prevents double-reaction same emoji
);

CREATE INDEX reactions_target_idx ON reactions(target_id);
```

## Aggregated Count Query

```sql
-- Query reactions aggregated by emoji, with a flag for current user's reactions
-- Do this in one query, not N+1
SELECT
  emoji,
  COUNT(*) as count,
  BOOL_OR(user_id = $currentUserId) as reacted_by_me,
  ARRAY_AGG(u.display_name ORDER BY r.created_at LIMIT 10) as reactor_names
FROM reactions r
JOIN users u ON u.id = r.user_id
WHERE target_id = $targetId
GROUP BY emoji
ORDER BY count DESC;
```

## Toggle Reaction (Optimistic)

```ts
function useReactions(targetId: string, targetType: string) {
  const [reactions, setReactions] = useState<ReactionGroup[]>([]);

  function toggleReaction(emoji: string) {
    // Find if current user already reacted with this emoji
    const group = reactions.find(r => r.emoji === emoji);
    const alreadyReacted = group?.reactedByMe ?? false;

    // Optimistic update — mutate local state immediately
    setReactions(prev => {
      if (alreadyReacted) {
        // Remove: decrement count and clear reactedByMe
        return prev
          .map(r => r.emoji === emoji ? { ...r, count: r.count - 1, reactedByMe: false } : r)
          .filter(r => r.count > 0); // Remove emoji group if count hits 0
      } else {
        // Add: create group or increment
        const exists = prev.find(r => r.emoji === emoji);
        if (exists) {
          return prev.map(r => r.emoji === emoji ? { ...r, count: r.count + 1, reactedByMe: true } : r);
        }
        return [...prev, { emoji, count: 1, reactedByMe: true, reactorNames: [] }];
      }
    });

    // Fire server request in background
    fetch(`/api/reactions`, {
      method: alreadyReacted ? 'DELETE' : 'POST',
      body: JSON.stringify({ targetId, targetType, emoji }),
      headers: { 'Content-Type': 'application/json' },
    }).catch(() => {
      // On failure, reload reactions from server to restore truth
      refetchReactions(targetId);
    });
  }

  return { reactions, toggleReaction };
}
```

## Reaction Bar Component

```tsx
function ReactionBar({ targetId, reactions, onToggle }: Props) {
  const [pickerOpen, setPickerOpen] = useState(false);

  return (
    <div className="reaction-bar">
      {reactions.map(group => (
        <ReactionChip
          key={group.emoji}
          group={group}
          onToggle={() => onToggle(group.emoji)}
        />
      ))}
      <button
        className="reaction-add"
        onClick={() => setPickerOpen(true)}
        aria-label="Add reaction"
      >
        + 😊
      </button>
      {pickerOpen && (
        <EmojiReactionPicker
          onSelect={emoji => { onToggle(emoji); setPickerOpen(false); }}
          onClose={() => setPickerOpen(false)}
        />
      )}
    </div>
  );
}

function ReactionChip({ group, onToggle }: { group: ReactionGroup; onToggle: () => void }) {
  return (
    <button
      className={`reaction-chip ${group.reactedByMe ? 'reaction-chip--active' : ''}`}
      onClick={onToggle}
      // Tooltip shows who reacted — hover/focus interaction only
      title={group.reactorNames.slice(0, 5).join(', ') + (group.count > 5 ? ` +${group.count - 5} more` : '')}
    >
      <span>{group.emoji}</span>
      <span className="reaction-chip__count">{group.count}</span>
    </button>
  );
}
```

## Picker with Most-Used First

```tsx
const FREQUENTLY_USED = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '✅'];

function EmojiReactionPicker({ onSelect, onClose }: PickerProps) {
  // Load full emoji list lazily — it's large
  const [fullList] = useLazyEmojis();

  return (
    <div className="emoji-picker" role="dialog" aria-label="Choose reaction">
      {/* Most-used section first — covers 90%+ of use cases without scrolling */}
      <div className="emoji-picker__frequent">
        {FREQUENTLY_USED.map(e => (
          <button key={e} onClick={() => onSelect(e)}>{e}</button>
        ))}
      </div>
      <hr />
      <div className="emoji-picker__full">
        {fullList?.map(e => (
          <button key={e.unified} onClick={() => onSelect(e.native)}>{e.native}</button>
        ))}
      </div>
    </div>
  );
}
```

## Key Rules
- Use optimistic updates — toggle reaction in local state immediately, then sync to server
- On server error, refetch reactions from source of truth — don't leave stale optimistic state
- Aggregate by emoji in a single query with a `reacted_by_me` boolean per emoji
- Show reactor names in a tooltip on the chip, not always-visible text
- Show most-used emojis first in the picker — don't make users scroll to reach 👍
- Store the unicode emoji directly, not a shortcode — shortcodes are not standardized
- Unique constraint on `(target_id, user_id, emoji)` in the DB — prevents server-side duplicates
