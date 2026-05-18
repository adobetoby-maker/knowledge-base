# Pattern: Feature Announcement

## Why This Pattern Matters

Feature announcements drive adoption of new functionality users already paid for. But spammy modals erode trust fast. The goal is: surface the right announcement to the right user exactly once, make dismissal feel safe, and give a clear path to try the feature.

## "What's New" Changelog Modal

A persistent entry point (bell icon or "What's new" in the header nav) opens a modal listing recent releases. Each entry has: version/date, short headline, 1–2 sentence description, optional screenshot/gif, and a CTA button ("Try it", "See docs"). This is always user-initiated — never auto-opens on every visit.

Track read state per user in the database: `feature_announcements(user_id, announcement_id, seen_at)`. Show an unread badge count on the entry point. Clear it when the modal opens, not when each item is clicked.

## Per-Feature Spotlight Announcement

For high-value features that most users haven't discovered, show a one-time spotlight — a modal or highlighted tooltip — on the first relevant page visit after the feature ships.

Store dismissal in `localStorage` keyed by feature slug and version:

```ts
const STORAGE_KEY = 'announcement:v2-ai-suggestions:dismissed';

function useFeatureAnnouncement(key: string) {
  const [show, setShow] = useState(false);

  useEffect(() => {
    const dismissed = localStorage.getItem(key);
    if (!dismissed) setShow(true);
  }, [key]);

  const dismiss = () => {
    localStorage.setItem(key, Date.now().toString());
    setShow(false);
  };

  return { show, dismiss };
}
```

Include the version in the key so the announcement re-triggers if a feature has a significant v2.

## Dismiss vs "Don't Show Again"

For modals that auto-open: provide both "Dismiss" (closes this session — re-shows next visit) and "Don't show again" (persists dismissal). This respects users who want to look at it later. In practice, most users only need "Got it" / "Don't show again" — keep it simple.

For changelog modals (user-initiated): no "don't show again" needed — dismissal is just closing the modal. Mark items as read instead.

## Deep Link to the New Feature

Every announcement CTA must navigate directly to the feature, not the home page. If the feature is in a specific settings section or UI tab, route there and optionally highlight the element with a brief ring animation on mount.

```tsx
<Button onClick={() => {
  dismiss();
  router.push('/dashboard?tab=ai-suggestions&highlight=true');
}}>
  Try it now
</Button>
```

On the destination page, check `searchParams.get('highlight')` and apply a 2-second ring pulse to the relevant component, then clear the param.

## Timing and Frequency

- Auto-open spotlights: max one per session, max once per 7 days per feature unless permanently dismissed
- Never auto-open a modal on the first page load of a new session during onboarding — it competes with critical first-run UX
- Changelog badge: update in real-time if user is active when a new announcement is published (use a polling interval or Supabase realtime)

## Key Rules

- Store dismissal in `localStorage` with version-keyed slug — not just feature name
- Never auto-open more than one announcement modal per page load
- Always provide a direct deep link to the feature, not just the home page
- Changelog is user-initiated (entry point in nav) — spotlights are one-time auto-show
- "Don't show again" persists; "Dismiss" is session-only
- Re-trigger announcements by incrementing the version in the storage key
- Don't show spotlights during active onboarding flows
