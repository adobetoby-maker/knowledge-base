# UI/UX QA Checklist

## Viewport Coverage

Test every UI change at these viewports:

| Device | Width | Test method |
|--------|-------|-------------|
| Mobile | 390px | Browser devtools or `browser_resize(390, 844)` |
| Tablet | 768px | Browser devtools |
| Desktop | 1280px | Normal window |
| Large desktop | 1920px | Browser devtools |

Any component that hasn't been tested at mobile is untested.

## Visual Integrity Checks

```
[ ] No horizontal scroll on mobile (except intentional scroll containers)
[ ] Text doesn't overflow containers
[ ] Images have correct aspect ratio (not stretched/squished)
[ ] Spacing is consistent (no orphaned margins, no elements touching edges)
[ ] Colors match design system (no one-off hex values)
[ ] Icons scale correctly (not blurry at any viewport)
```

## Interactive State Checks

```
[ ] Hover states visible on desktop
[ ] Focus states visible on keyboard navigation
[ ] Active/pressed states work on mobile (touch target ≥ 44×44px)
[ ] Disabled states look visually distinct
[ ] Loading states show while data is being fetched
[ ] Empty states displayed when no data exists
[ ] Error states displayed when operations fail
```

## Forms

```
[ ] All form inputs have visible labels
[ ] Placeholder text doesn't replace labels (placeholder disappears on input)
[ ] Validation errors appear adjacent to the relevant field
[ ] Error messages are specific ("Email format invalid") not generic ("Error")
[ ] Success confirmation appears after successful submission
[ ] Submit button disabled during submission (prevents double-submit)
[ ] Form resets or redirects appropriately after success
```

## Navigation

```
[ ] Active route highlighted in navigation
[ ] Back button works correctly (no unexpected redirect loops)
[ ] Deep links load the correct page (not homepage)
[ ] 404 page exists and is styled
[ ] Loading states during navigation (Suspense fallbacks visible)
```

## Animation and Motion

Use video recording for any animated content — screenshots capture one frame:
```bash
node ~/record.js 3007              # 30-second scroll review
node ~/record.js 3007 --mobile     # mobile viewport
```

```
[ ] Animations complete smoothly (no dropped frames)
[ ] Scroll-triggered animations fire at correct positions
[ ] Hover animations don't cause layout shift
[ ] Transitions work on mobile (touch scroll triggers them correctly)
[ ] Animation plays only once if appropriate (not on every scroll past)
[ ] prefers-reduced-motion respected (no animation for users who prefer it)
```

## Typography

```
[ ] No font loading flash (FOUT) — use next/font
[ ] Line heights comfortable for reading (1.5–1.7 for body text)
[ ] Heading sizes create clear hierarchy
[ ] Text color has sufficient contrast (4.5:1 for body, 3:1 for large)
[ ] No line lengths over 80 characters on desktop (reduces readability)
```

## Cross-Browser Testing

Primary browsers to test:
1. Chrome (primary — most users)
2. Safari (important for iOS/macOS users)
3. Firefox (secondary)

Safari-specific issues:
- CSS Grid/Flexbox gaps behave differently in older Safari
- `dvh` (dynamic viewport height) units require Safari 15.4+
- Some CSS backdrop-filter effects may need `-webkit-` prefix

## Performance Sanity Check

After any visual change:
```bash
# Run PageSpeed on the affected page
# Target: LCP < 2.5s, CLS < 0.1, INP < 200ms
```

UI changes (new components, images) can accidentally push LCP from good to poor. Always check after adding above-fold content.

## The Golden Path Test

Before marking any feature complete, walk through the primary user journey end-to-end:
1. Navigate to the entry point
2. Complete the primary action
3. Verify the expected outcome
4. Check the confirmation/success state

Then test one failure case:
1. Navigate to the entry point
2. Attempt the primary action with invalid input
3. Verify the error is displayed correctly
4. Verify the form/flow is recoverable (user can fix and retry)
