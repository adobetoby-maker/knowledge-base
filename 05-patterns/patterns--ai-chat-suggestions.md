# Pattern: AI-Powered Chat Suggestion Chips

## Why This Pattern Matters

Suggestion chips reduce the blank-input problem — users who don't know what to ask next get momentum. Done poorly, they're distracting noise during active conversation. The key constraint: chips must appear only when the user is idle, disappear the moment a response starts streaming, and never block the input.

## When to Show Suggestions

Show chips when:
- The assistant has just finished a response (streaming complete)
- The user's input field is empty
- No new user message is pending

Hide chips when:
- Streaming is in progress
- The user has started typing (input is non-empty)
- The conversation is at the very start (no context to generate from)

```tsx
const showSuggestions =
  !isStreaming &&
  inputValue.trim() === '' &&
  messages.length >= 2; // needs context
```

## Generating Suggestions

Generate 3 suggestions from conversation context using a fast model (Haiku-class). Fire the suggestion request as soon as streaming ends — don't wait for user action.

```ts
async function generateSuggestions(messages: Message[]) {
  const last5 = messages.slice(-5);
  const response = await ai.complete({
    model: 'claude-haiku-4-5',
    system: 'Generate 3 short follow-up questions the user might want to ask next. Return JSON: { suggestions: string[] }. Each suggestion max 60 characters.',
    messages: last5,
  });
  return JSON.parse(response).suggestions as string[];
}
```

Keep a `suggestionsRef` to cancel/ignore stale results if a new message is sent before the generation completes:

```ts
const genId = useRef(0);

async function refreshSuggestions() {
  const id = ++genId.current;
  const suggestions = await generateSuggestions(messages);
  if (id === genId.current) setSuggestions(suggestions);
}
```

## Clicking a Suggestion

Clicking fills the input — it does not auto-submit. This gives the user a chance to edit the suggestion before sending. It feels more natural and avoids surprise submissions.

```tsx
<button
  onClick={() => {
    setInputValue(suggestion);
    inputRef.current?.focus();
  }}
  className="rounded-full border px-3 py-1 text-sm hover:bg-muted transition-colors"
>
  {suggestion}
</button>
```

If auto-submit is desired for a specific product reason, add `onDoubleClick` for submit and note the pattern explicitly — don't make single-click auto-submit.

## Layout

Render chips in a horizontally scrollable row below the input, above the send button. Use `flex flex-wrap gap-2` for desktop; allow horizontal scroll on mobile with `overflow-x-auto whitespace-nowrap`. Animate in with a fade (150ms opacity transition) — never pop in abruptly.

## Keyboard Accessibility

Suggestion chips must be focusable. Tab navigates into the chip row after the input. Arrow keys move between chips. Enter/Space selects. Escape returns focus to the input.

```tsx
<div role="group" aria-label="Suggested follow-ups">
  {suggestions.map((s, i) => (
    <button
      key={i}
      role="option"
      aria-label={`Suggested: ${s}`}
      onKeyDown={e => {
        if (e.key === 'ArrowRight') suggestionsRef.current?.[i + 1]?.focus();
        if (e.key === 'ArrowLeft') suggestionsRef.current?.[i - 1]?.focus();
        if (e.key === 'Escape') inputRef.current?.focus();
      }}
    >
      {s}
    </button>
  ))}
</div>
```

## Key Rules

- Chips appear only when streaming is complete AND input is empty
- Chips disappear the instant streaming begins (not after it ends)
- Clicking fills input but does not auto-submit
- Generate from last 5 messages max — larger context makes suggestions too broad
- Cancel stale generation requests with a generation ID counter
- Fade in on appear; instant hide when streaming starts
- Full keyboard accessibility: Arrow keys between chips, Escape returns to input
