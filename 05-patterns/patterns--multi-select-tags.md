# Pattern: Multi-Select with Tag Chips

An input field that converts entries into removable tag chips. Users add tags by typing and pressing Enter/comma, remove them by clicking X or pressing Backspace, and navigate existing tags with arrow keys.

## Why It Matters

Multi-value inputs that just show a plain comma list feel fragile—users can't tell what's a value vs. separator. Tags make each value a discrete, removable unit. The keyboard contract must be airtight: Backspace-to-delete is muscle memory, and breaking it (deleting characters instead) forces mouse usage.

## State Model

```ts
interface MultiTagState {
  tags: string[];
  inputValue: string;
  focusedTagIndex: number | null; // null = focus is on input
}
```

Keep focused tag index in state, not just a ref, so the focused chip can apply a visible focus ring via className.

## Full Component

```tsx
function MultiTagInput({
  value,
  onChange,
  placeholder = 'Add tags...',
  maxTags,
  delimiter = /,|Enter/,
}: MultiTagInputProps) {
  const [inputValue, setInputValue] = useState('');
  const [focusedTag, setFocusedTag] = useState<number | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const id = useId();

  function addTag(raw: string) {
    const trimmed = raw.trim().toLowerCase();
    if (!trimmed || value.includes(trimmed)) return;
    if (maxTags && value.length >= maxTags) return;
    onChange([...value, trimmed]);
    setInputValue('');
  }

  function removeTag(index: number) {
    onChange(value.filter((_, i) => i !== index));
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Enter' || e.key === ',') {
      e.preventDefault();
      addTag(inputValue);
      return;
    }

    // Backspace on empty input → focus last tag (first press), then delete it (second press)
    if (e.key === 'Backspace' && inputValue === '') {
      e.preventDefault();
      if (focusedTag !== null) {
        removeTag(focusedTag);
        // Focus the new last tag, or input if none remain
        const newLast = value.length - 2;
        if (newLast >= 0) setFocusedTag(newLast);
        else { setFocusedTag(null); inputRef.current?.focus(); }
      } else if (value.length > 0) {
        setFocusedTag(value.length - 1);
      }
      return;
    }

    // Arrow keys navigate between tags
    if (e.key === 'ArrowLeft' && inputValue === '') {
      e.preventDefault();
      if (focusedTag === null) setFocusedTag(value.length - 1);
      else setFocusedTag(i => Math.max(0, (i ?? 0) - 1));
    }
    if (e.key === 'ArrowRight') {
      e.preventDefault();
      if (focusedTag !== null) {
        if (focusedTag === value.length - 1) { setFocusedTag(null); inputRef.current?.focus(); }
        else setFocusedTag(i => (i ?? 0) + 1);
      }
    }
    if (e.key === 'Escape') { setFocusedTag(null); inputRef.current?.focus(); }
  }

  const atLimit = maxTags != null && value.length >= maxTags;

  return (
    <div
      className="multi-tag-input"
      onClick={() => inputRef.current?.focus()}
      role="group"
      aria-labelledby={`${id}-label`}
    >
      {value.map((tag, i) => (
        <span
          key={tag}
          className={`tag ${focusedTag === i ? 'tag--focused' : ''}`}
          aria-label={`${tag}, remove`}
        >
          {tag}
          <button
            type="button"
            onClick={e => { e.stopPropagation(); removeTag(i); }}
            aria-label={`Remove ${tag}`}
            tabIndex={-1}
          >
            ×
          </button>
        </span>
      ))}

      {atLimit ? (
        <span className="tag-limit-badge" aria-live="polite">
          {maxTags} max
        </span>
      ) : (
        <input
          ref={inputRef}
          id={id}
          type="text"
          value={inputValue}
          onChange={e => { setInputValue(e.target.value); setFocusedTag(null); }}
          onKeyDown={handleKeyDown}
          onBlur={() => { if (inputValue.trim()) addTag(inputValue); }}
          placeholder={value.length === 0 ? placeholder : ''}
          aria-label="Add tag"
          className="multi-tag-input__field"
        />
      )}
    </div>
  );
}
```

## Adding via Comma

Comma adds a tag mid-word, so users can type `react,typescript,` to add three quickly. Handle it in `keydown` with `e.preventDefault()` to stop the comma from being inserted into `inputValue`.

Some implementations also split the input on paste:

```ts
function handlePaste(e: React.ClipboardEvent) {
  e.preventDefault();
  const text = e.clipboardData.getData('text');
  const parts = text.split(/[,\n]+/).map(s => s.trim()).filter(Boolean);
  const toAdd = parts.filter(p => !value.includes(p));
  const available = maxTags ? maxTags - value.length : Infinity;
  onChange([...value, ...toAdd.slice(0, available)]);
}
```

## Backspace Two-Stage Delete

Single Backspace on empty input: **highlight** the last tag (don't delete yet). Second Backspace: **delete** it. This two-stage pattern prevents accidental deletion—the first press shows intent, the second confirms it. The focused tag gets a distinct visual ring, not just a color change.

## Max Tag Limit

When the limit is reached, hide the input entirely and show a count badge instead. Don't just disable the input—hiding it signals clearly that no more tags can be added. Restore the input after a tag is removed.

## Key Rules

- **Two-stage Backspace**: first press focuses last tag, second deletes it.
- **Blur adds the current input** as a tag—users shouldn't lose partial input by clicking away.
- **Arrow keys navigate tags** when input is empty—ArrowRight exits back to input.
- **Comma triggers add**—prevent the character from appearing in input with `e.preventDefault()`.
- **Hide input at max**, don't disable it—a visible count badge communicates the limit.
- **Duplicate prevention**: silently ignore (no error) when a tag already exists.
- **X buttons are `tabIndex={-1}`**—tag deletion is via keyboard through the input's Backspace, not via tabbing to each X.
