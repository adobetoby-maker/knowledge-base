# Pattern: Feedback Widget

A persistent feedback button that opens a survey overlay with NPS scale, emoji reaction picker, free text followup, and submission to an analytics endpoint.

## Widget Placement and Persistence

The widget button is fixed to the viewport — it floats over all content. Position it bottom-right or bottom-left. Use `z-50` and avoid colliding with chat widgets, cookie banners, or Intercom.

```tsx
function FeedbackWidget() {
  const [isOpen, setIsOpen] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  return (
    <>
      <button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-6 right-6 z-50 flex items-center gap-2 rounded-full bg-primary px-4 py-2 text-sm font-medium text-primary-foreground shadow-lg hover:bg-primary/90 transition-all"
        aria-label="Share feedback"
      >
        <MessageSquareIcon size={16} />
        Feedback
      </button>

      {isOpen && (
        <FeedbackOverlay
          onClose={() => setIsOpen(false)}
          onSubmit={async (data) => {
            await submitFeedback(data);
            setSubmitted(true);
          }}
          submitted={submitted}
        />
      )}
    </>
  );
}
```

## NPS Scale Component

The NPS (Net Promoter Score) is a 0–10 scale: "How likely are you to recommend us?" Respondents are Detractors (0–6), Passives (7–8), or Promoters (9–10).

```tsx
function NpsScale({ value, onChange }: { value: number | null; onChange: (n: number) => void }) {
  return (
    <fieldset>
      <legend className="text-sm font-medium mb-3">
        How likely are you to recommend us to a friend? (0 = not at all, 10 = definitely)
      </legend>
      <div className="flex gap-1">
        {Array.from({ length: 11 }, (_, i) => (
          <button
            key={i}
            type="button"
            onClick={() => onChange(i)}
            className={cn(
              'flex-1 py-2 rounded text-sm font-medium border transition-colors',
              value === i
                ? 'bg-primary text-primary-foreground border-primary'
                : 'bg-background hover:bg-muted',
              i <= 6 && 'hover:border-red-300',
              i >= 9 && 'hover:border-green-300'
            )}
            aria-label={`Score ${i}`}
            aria-pressed={value === i}
          >
            {i}
          </button>
        ))}
      </div>
      <div className="flex justify-between text-xs text-muted-foreground mt-1">
        <span>Not likely</span>
        <span>Very likely</span>
      </div>
    </fieldset>
  );
}
```

## Emoji Reaction Picker

Emoji reactions are faster to complete than text fields. Use them as a quick sentiment capture before the optional free text.

```tsx
const REACTIONS = [
  { emoji: '😍', label: 'Love it', value: 'love' },
  { emoji: '😊', label: 'Happy', value: 'happy' },
  { emoji: '😐', label: 'Neutral', value: 'neutral' },
  { emoji: '😕', label: 'Confused', value: 'confused' },
  { emoji: '😤', label: 'Frustrated', value: 'frustrated' },
];

function EmojiPicker({ value, onChange }: { value: string | null; onChange: (v: string) => void }) {
  return (
    <div className="flex gap-2 justify-center" role="group" aria-label="How are you feeling?">
      {REACTIONS.map(r => (
        <button
          key={r.value}
          type="button"
          onClick={() => onChange(r.value)}
          title={r.label}
          aria-label={r.label}
          aria-pressed={value === r.value}
          className={cn(
            'text-2xl p-2 rounded-lg transition-all',
            value === r.value ? 'bg-primary/15 scale-125' : 'hover:bg-muted hover:scale-110'
          )}
        >
          {r.emoji}
        </button>
      ))}
    </div>
  );
}
```

## Conditional Free Text Followup

Show the text field only when a low score or negative reaction is selected — it reduces friction for happy users while capturing detail from unhappy ones.

```tsx
const showTextFollowup = npsScore !== null && npsScore <= 6 ||
                          reaction === 'confused' || reaction === 'frustrated';

{showTextFollowup && (
  <div className="space-y-1">
    <Label htmlFor="feedback-text" className="text-sm">
      {npsScore !== null && npsScore <= 6
        ? 'What could we do better?'
        : 'Tell us more about what happened'}
    </Label>
    <Textarea
      id="feedback-text"
      value={freeText}
      onChange={e => setFreeText(e.target.value)}
      placeholder="Your feedback helps us improve..."
      rows={3}
    />
  </div>
)}
```

## Submission to Analytics Endpoint

Send to your analytics endpoint and optionally to a third-party service. Don't block the UI on it — fire and forget with a timeout.

```tsx
async function submitFeedback(data: FeedbackData) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);

  try {
    await fetch('/api/feedback', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...data,
        url: window.location.href,
        userAgent: navigator.userAgent,
        timestamp: new Date().toISOString(),
      }),
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
}
```

Always include `url` and `timestamp` — without context, feedback is hard to act on.

## Key Rules

- Fixed position with z-50 — the widget must never be covered by page content
- NPS uses `aria-pressed` on each score button — it's a toggle, not a radio, so `aria-pressed` is correct
- Show the free text field conditionally based on score/reaction — don't show it by default, it increases abandonment
- Submit with a 5-second timeout and abort — analytics failures should never block the user
- Always capture URL and timestamp — decontextualized feedback is nearly useless
- Show a success state after submission to confirm it was received
