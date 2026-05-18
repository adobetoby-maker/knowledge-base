# Review: UI/UX Review Checklist

## Overview
UI bugs are invisible in code review — you can't see broken touch targets, illegible labels, or confusing empty states by reading JSX. A systematic visual review with real device testing catches the issues that slip through functional testing. The majority of UI accessibility and usability failures are mechanical and checkable.

## Implementation / Key Points

### Touch Targets (Mobile)
```css
/* Minimum 44×44px per Apple HIG and WCAG 2.5.5 */
button, a, [role="button"] {
  min-height: 44px;
  min-width: 44px;
}
```
Interactive elements smaller than 44×44px are error-prone on touch. Icons without padding are the most common violation. Check: icon-only buttons, inline text links, checkbox/radio labels.

### Form Labels
```html
<!-- Bad: label disappears on focus, screen readers may miss connection -->
<input placeholder="Email address" />

<!-- Good: visible label always present -->
<label for="email">Email address</label>
<input id="email" placeholder="jane@example.com" />

<!-- Also acceptable: visually hidden but accessible -->
<label class="sr-only" for="email">Email address</label>
<input id="email" placeholder="Email address" />
```
Placeholders as sole labels fail when: user types (placeholder disappears), browser autofills (label gone), screen reader context is needed.

### Error Messages
```typescript
// Bad: tells user something went wrong, not what to do
"Invalid input"
"Error occurred"
"Failed"

// Good: specific and actionable
"Enter a valid email address (e.g., name@example.com)"
"Password must be at least 8 characters"
"Card declined — check the card number or use a different card"
```
Error messages should answer: what's wrong, and what should I do? "Invalid" with no guidance is not a UI — it's a failure message.

### Loading States
Every async action needs a loading indicator:
```typescript
// Checklist for any button that triggers async work:
// [ ] Button disabled during loading (prevents double-submit)
// [ ] Visual indicator (spinner, skeleton, progress bar)
// [ ] Error state handled (not just success path)
// [ ] Optimistic update or genuine loading — pick one, not neither
```
A form that doesn't visually respond after submit causes double-submits and user confusion.

### Empty States
Empty states are part of the UI, not an afterthought:
```typescript
// Common empty state contexts to design explicitly:
// - Empty list (no orders yet)
// - No search results
// - Error loading data
// - First-time user (no content)

// Each empty state should have:
// - Explanation of why it's empty
// - Call to action (when applicable)
// - NOT just a blank white space
```

### Mobile Layout at 375px
```bash
# Chrome DevTools: Cmd+Shift+M → set to 375px width (iPhone SE / base tier)
# Check:
# - Text doesn't overflow container
# - Buttons are full-width or properly sized
# - Navigation is accessible
# - Tables/grids don't cause horizontal scroll
# - Modals fit viewport
```
375px is the smallest common viewport. If it works at 375px, it works everywhere.

### Color Contrast
```
# WCAG AA minimums:
# - Normal text (< 18px / 14px bold): 4.5:1 ratio
# - Large text (≥ 18px / 14px bold): 3:1 ratio
# - UI components, icons: 3:1 ratio

# Test with: browser DevTools Accessibility panel, or
# https://webaim.org/resources/contrastchecker/
```
Gray text on white backgrounds and light-colored buttons on white are common failures.

### Full Checklist
- [ ] Touch targets ≥ 44×44px
- [ ] Every form input has a visible label (not just placeholder)
- [ ] Error messages describe the problem and the fix
- [ ] Loading state for every button/action that triggers async work
- [ ] Button disabled during loading (no double-submit)
- [ ] Error state designed and tested
- [ ] Empty states have content (not blank)
- [ ] Layout tested at 375px mobile width
- [ ] Color contrast passes WCAG AA (4.5:1 for text)
- [ ] Focus ring visible on keyboard navigation
- [ ] No horizontal scroll at any standard viewport

## Key Rules
- Touch targets below 44×44px are accessibility failures, not just UX issues
- Placeholder text cannot replace a label — it disappears and breaks screen readers
- Every error message must tell the user what to do, not just that something failed
- Every async action needs a loading state — no response after submit confuses users into double-submitting
- Test at 375px viewport width — smallest common iPhone size
- Empty states are part of the design; blank white space is not an acceptable empty state
