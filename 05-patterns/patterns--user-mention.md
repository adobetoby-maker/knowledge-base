# Pattern: @Mention System in Text Inputs

## Problem

@mention systems need to detect the `@` trigger as the user types, display a user search popover, insert the selected mention as a token (not just raw text), and store mentions as structured data alongside the raw string for backend processing (notifications, permission checks, etc).

## Detecting the @ Trigger

Watch the cursor position, not just the text, to detect an in-progress mention:

```ts
type MentionState = {
  active: boolean;
  query: string;
  startIndex: number;  // character index where @ was typed
};

function detectMention(
  text: string,
  cursorPos: number
): MentionState | null {
  // Walk backwards from cursor to find a @ that starts a word
  const before = text.slice(0, cursorPos);
  const match = before.match(/@(\w*)$/);   // @ followed by word chars, at end of string

  if (!match) return null;
  const startIndex = before.lastIndexOf('@');
  return {
    active: true,
    query: match[1],           // text after @, before cursor
    startIndex,
  };
}
```

WHY walk backwards from cursor: the user may be editing text in the middle of a longer string. The match must end at the cursor position, not anywhere in the text.

## Inserting the Mention Token

When a user is selected from the popover, replace the `@query` substring with the formatted mention and add a trailing space:

```ts
function insertMention(
  text: string,
  mention: MentionState,
  user: { id: string; name: string }
): { text: string; cursorPos: number } {
  const before = text.slice(0, mention.startIndex);
  const after = text.slice(mention.startIndex + mention.query.length + 1); // +1 for @
  const token = `@${user.name} `;
  const newText = before + token + after;
  const newCursor = before.length + token.length;
  return { text: newText, cursorPos: newCursor };
}
```

After inserting, focus the textarea and programmatically set the cursor position:

```ts
textareaRef.current!.setSelectionRange(newCursor, newCursor);
```

## Storing Structured Mention Data

The raw text `"Hey @Alice can you check this?"` is insufficient for the backend — you need user IDs for notifications. Store mentions as a parallel array:

```ts
type Mention = { userId: string; name: string; startIndex: number };

type CommentState = {
  text: string;
  mentions: Mention[];
};
```

Build the mentions array when inserting:

```ts
function addMentionToState(
  state: CommentState,
  user: { id: string; name: string },
  insertionIndex: number
): CommentState {
  const newMention: Mention = {
    userId: user.id,
    name: user.name,
    startIndex: insertionIndex,
  };
  return {
    ...state,
    mentions: [...state.mentions, newMention],
  };
}
```

On submit, send both `text` and `mentions` to the server. The server uses `mentions` for notification fan-out.

## Full Component Sketch

```tsx
function MentionTextarea({ onSubmit }: Props) {
  const [text, setText] = useState('');
  const [mentions, setMentions] = useState<Mention[]>([]);
  const [mentionState, setMentionState] = useState<MentionState | null>(null);
  const [users, setUsers] = useState<User[]>([]);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  function handleChange(e: React.ChangeEvent<HTMLTextAreaElement>) {
    const val = e.target.value;
    const cursor = e.target.selectionStart;
    setText(val);

    const detected = detectMention(val, cursor);
    setMentionState(detected);

    if (detected && detected.query.length > 0) {
      searchUsers(detected.query).then(setUsers);
    }
  }

  function handleSelect(user: User) {
    if (!mentionState) return;
    const { text: newText, cursorPos } = insertMention(text, mentionState, user);
    setText(newText);
    setMentions(m => [...m, { userId: user.id, name: user.name, startIndex: mentionState.startIndex }]);
    setMentionState(null);

    // Restore focus + cursor
    requestAnimationFrame(() => {
      textareaRef.current?.focus();
      textareaRef.current?.setSelectionRange(cursorPos, cursorPos);
    });
  }

  return (
    <div className="relative">
      <textarea
        ref={textareaRef}
        value={text}
        onChange={handleChange}
        onKeyDown={e => { if (e.key === 'Escape') setMentionState(null); }}
      />
      {mentionState?.active && users.length > 0 && (
        <MentionPopover users={users} onSelect={handleSelect} />
      )}
    </div>
  );
}
```

## Key Rules

- Detect mention by matching `/@(\w*)$/` against text before the cursor — position-aware detection prevents false matches
- Insert mention token and immediately set cursor position after the inserted text using `setSelectionRange`
- Store mentions as structured data (`{ userId, name, startIndex }`) alongside raw text — raw text alone is insufficient for notification delivery
- Close the popover on Escape; dismiss if `@` is deleted or cursor moves before the `@`
- Use `requestAnimationFrame` before `setSelectionRange` to ensure the DOM has updated after `setState`
