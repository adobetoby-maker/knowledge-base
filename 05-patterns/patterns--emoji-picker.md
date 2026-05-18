# Pattern: Emoji Picker

## Overview

Inline emoji selection for reactions, comments, or status fields. Key consideration: rendering all emojis (3700+ in Emoji 15) requires virtualization. Don't build the emoji list yourself — use `emoji-mart` or similar.

## emoji-mart Integration

```tsx
import Picker from '@emoji-mart/react'
import data from '@emoji-mart/data'

function EmojiPickerButton({
  onSelect,
}: {
  onSelect: (emoji: string) => void
}) {
  const [open, setOpen] = useState(false)
  const buttonRef = useRef<HTMLButtonElement>(null)
  const pickerRef = useRef<HTMLDivElement>(null)

  // Close on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (
        !buttonRef.current?.contains(e.target as Node) &&
        !pickerRef.current?.contains(e.target as Node)
      ) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  return (
    <div className="relative inline-block">
      <button
        ref={buttonRef}
        onClick={() => setOpen(o => !o)}
        className="p-1.5 hover:bg-gray-100 rounded text-lg"
        aria-label="Add emoji"
        aria-expanded={open}
      >
        😊
      </button>
      {open && (
        <div
          ref={pickerRef}
          className="absolute z-50 bottom-full mb-1"
          style={{ right: 0 }}
        >
          <Picker
            data={data}
            onEmojiSelect={(emoji: { native: string }) => {
              onSelect(emoji.native)
              setOpen(false)
            }}
            theme="light"
            previewPosition="none"
            skinTonePosition="none"
            maxFrequentRows={2}
          />
        </div>
      )}
    </div>
  )
}
```

## Emoji Reactions

For reaction counts (like GitHub PR reactions):

```tsx
interface Reaction {
  emoji: string
  count: number
  reacted: boolean  // Did current user react?
}

function EmojiReactions({ reactions, onReact }: {
  reactions: Reaction[]
  onReact: (emoji: string) => void
}) {
  return (
    <div className="flex flex-wrap gap-1 items-center">
      {reactions.map(r => (
        <button
          key={r.emoji}
          onClick={() => onReact(r.emoji)}
          className={`flex items-center gap-1 px-2 py-0.5 rounded-full text-sm border transition-colors ${
            r.reacted
              ? 'bg-blue-50 border-blue-300 text-blue-700'
              : 'bg-gray-50 border-gray-200 hover:bg-gray-100'
          }`}
        >
          <span>{r.emoji}</span>
          <span>{r.count}</span>
        </button>
      ))}
      <EmojiPickerButton onSelect={emoji => onReact(emoji)} />
    </div>
  )
}
```

## Database Storage

Store emojis as Unicode characters (native string), not shortcodes:

```sql
CREATE TABLE reactions (
  id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji   TEXT NOT NULL,  -- Store as native: '👍' not ':thumbsup:'
  UNIQUE(post_id, user_id, emoji)
);
```

Count reactions grouped by emoji:

```sql
SELECT emoji, COUNT(*) as count,
  bool_or(user_id = $1) as reacted
FROM reactions
WHERE post_id = $2
GROUP BY emoji
ORDER BY count DESC;
```

## Key Rules

- `@emoji-mart/data` is ~1MB — lazy-load the picker with `React.lazy` / `dynamic` import.
- Store native Unicode emoji (`👍`), not shortcodes (`:thumbsup:`) — shortcodes vary between platforms.
- The `UNIQUE(post_id, user_id, emoji)` constraint prevents duplicate reactions at DB level.
- Position the picker using `bottom-full` (open upward) when near the bottom of the viewport; check available space and flip direction.
