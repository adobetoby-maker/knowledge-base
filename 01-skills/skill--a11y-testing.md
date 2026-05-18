# Skill: Accessibility Testing

## Overview
Automated accessibility testing catches structural violations early — missing labels, invalid ARIA, low contrast — but automation only finds ~30% of real accessibility issues. Manual keyboard navigation testing, screen reader verification, and user testing with assistive technology are required for WCAG 2.1 AA compliance. Build automated checks into CI so violations never merge undetected.

## Automated Testing with jest-axe

Install: `npm install --save-dev jest-axe @testing-library/jest-dom`

```ts
import { axe, toHaveNoViolations } from 'jest-axe'
import { render } from '@testing-library/react'

expect.extend(toHaveNoViolations)

test('form has no accessibility violations', async () => {
  const { container } = render(<ContactForm />)
  const results = await axe(container)
  expect(results).toHaveNoViolations()
})
```

Run axe after any user interaction that changes the DOM (open modal, tab to next step) — not just on initial render.

## Playwright Accessibility Checks

```ts
import { checkA11y, injectAxe } from 'axe-playwright'

test('page passes axe', async ({ page }) => {
  await page.goto('/checkout')
  await injectAxe(page)
  await checkA11y(page, undefined, {
    axeOptions: { runOnly: ['wcag2a', 'wcag2aa'] },
    detailedReport: true,
  })
})
```

## Keyboard Navigation Testing

```ts
import userEvent from '@testing-library/user-event'

test('modal can be closed with Escape', async () => {
  const user = userEvent.setup()
  render(<Modal isOpen />)

  // Tab to close button
  await user.tab()
  expect(document.activeElement).toHaveAttribute('aria-label', 'Close')

  // Dismiss with Escape
  await user.keyboard('{Escape}')
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
})
```

Tab order must follow visual order. Focus must be trapped inside modals. Focus must return to trigger element on close.

## Color Contrast Check

WCAG AA: 4.5:1 for normal text, 3:1 for large text (18px+ or 14px+ bold).

```ts
// Using color2k or polished
import { getLuminance } from 'polished'

function contrastRatio(color1: string, color2: string): number {
  const l1 = getLuminance(color1)
  const l2 = getLuminance(color2)
  const lighter = Math.max(l1, l2)
  const darker = Math.min(l1, l2)
  return (lighter + 0.05) / (darker + 0.05)
}

test('text contrast meets WCAG AA', () => {
  expect(contrastRatio('#1a1a1a', '#ffffff')).toBeGreaterThan(4.5)
})
```

Automate contrast checks with `axe-core` rule `color-contrast` — but verify with real fonts and sizes.

## Screen Reader Testing

Manual testing required — automation cannot replace this.

- **NVDA + Firefox** (Windows): most common screen reader globally
- **JAWS + Chrome** (Windows): enterprise standard
- **VoiceOver + Safari** (macOS/iOS): required for iOS users
- **TalkBack** (Android): mobile

Test flows: form completion, navigation via headings (`H` key in NVDA/JAWS), list navigation, modal open/close, error announcements.

Live regions (`aria-live="polite"` or `assertive`) announce dynamic content. Test that error messages are announced when form submission fails.

## WCAG 2.1 AA Baseline Rules

| Criterion | Level | What it means |
|---|---|---|
| 1.1.1 Non-text Content | A | Images need alt text |
| 1.3.1 Info and Relationships | A | Structure conveyed via markup, not just visual |
| 1.4.3 Contrast (minimum) | AA | 4.5:1 normal, 3:1 large text |
| 2.1.1 Keyboard | A | All functionality keyboard-accessible |
| 2.4.3 Focus Order | A | Focus order matches reading order |
| 2.4.7 Focus Visible | AA | Keyboard focus always visible |
| 4.1.2 Name, Role, Value | A | UI components have accessible names |
| 4.1.3 Status Messages | AA | Status announced without focus change |

## What Automation Misses

- Meaningful vs. decorative image distinction
- Whether alt text is actually descriptive
- Logical heading hierarchy in context
- Whether focus management feels natural
- Cognitive load and reading complexity
- Touch target size (WCAG 2.5.5: 44×44px minimum)

## Key Rules
- Run `jest-axe` on every component render test, not just dedicated a11y tests
- Never suppress axe violations with `disableRules` without a documented reason
- Every interactive element needs an accessible name (`aria-label`, `aria-labelledby`, or visible text)
- Test with actual keyboard — tab through every interactive flow before shipping
- WCAG AA is the legal baseline in most jurisdictions; AAA is aspirational
- Dynamic content changes (toasts, errors, loading states) must use `aria-live` regions
