# Pattern: Contextual Help (Tooltips & Popovers)

## What This Solves

Form fields, settings toggles, and data metrics often need explanation that doesn't fit inline. Tooltip-only approaches fail for rich content (links, code, multi-line text) and are inaccessible on touch devices. A question-mark icon that opens a popover solves both problems — it's keyboard accessible, supports rich content, and works on mobile.

## Tooltip vs Popover

Use a **tooltip** for short, plain text (< 80 characters) that supplements a visible label. Tooltips appear on hover and focus, disappear on blur/mouseleave, and cannot contain interactive content.

Use a **popover** when:
- Content exceeds one line
- Content includes links, code snippets, or formatted text
- The trigger is a dedicated help icon (not a label itself)

Never put links inside tooltips — users cannot click them before the tooltip disappears.

## Question Mark Icon Trigger

The trigger must be a `<button>`, not a `<span>` or `<div>`. This ensures keyboard reachability via Tab and activation via Enter/Space:

```tsx
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'

interface HelpPopoverProps {
  children: React.ReactNode
  label: string  // accessible name for screen readers
}

export function HelpPopover({ children, label }: HelpPopoverProps) {
  return (
    <Popover>
      <PopoverTrigger asChild>
        <button
          type="button"
          aria-label={`Help: ${label}`}
          className="inline-flex items-center justify-center h-4 w-4 rounded-full text-muted-foreground hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <QuestionMarkCircledIcon className="h-4 w-4" />
        </button>
      </PopoverTrigger>
      <PopoverContent className="w-72 text-sm" side="top">
        {children}
      </PopoverContent>
    </Popover>
  )
}
```

Usage beside a form label:

```tsx
<div className="flex items-center gap-1.5">
  <Label htmlFor="markup">Markup rate</Label>
  <HelpPopover label="markup rate">
    <p>The percentage added to material costs before billing.</p>
    <p className="mt-2 text-muted-foreground">
      Industry standard is 20–30%.{' '}
      <a href="/docs/pricing" className="underline text-primary">Learn more →</a>
    </p>
  </HelpPopover>
</div>
```

## Rich Content in Help

Popovers can contain structured content:

```tsx
<HelpPopover label="API rate limits">
  <div className="space-y-2">
    <p className="font-medium">Rate limits by plan:</p>
    <ul className="space-y-1 text-muted-foreground">
      <li>Free: 100 req/min</li>
      <li>Pro: 1,000 req/min</li>
      <li>Enterprise: unlimited</li>
    </ul>
    <pre className="bg-muted px-2 py-1 rounded text-xs">
      X-RateLimit-Remaining: 87
    </pre>
  </div>
</HelpPopover>
```

## Keyboard Trigger Behavior

The Radix UI Popover (used by shadcn/ui) handles this correctly:
- **Tab** reaches the `?` button
- **Enter** or **Space** opens the popover
- **Escape** closes it and returns focus to the trigger
- **Tab** from inside the popover moves focus through any links/buttons in the content

Do not build this manually — Radix handles ARIA attributes (`aria-expanded`, `aria-controls`, `aria-haspopup`) and focus management automatically.

## Mobile: Show Inline Text Instead

On touch devices, hover doesn't exist. Popovers still work on mobile (tap to open), but for simple help text consider showing it inline below the field at smaller breakpoints:

```tsx
export function FormField({ label, help, children }: FormFieldProps) {
  return (
    <div className="space-y-1.5">
      <div className="flex items-center gap-1.5">
        <Label>{label}</Label>
        {/* Desktop: show as popover */}
        <span className="hidden sm:inline-flex">
          <HelpPopover label={label}>
            <p>{help}</p>
          </HelpPopover>
        </span>
      </div>
      {children}
      {/* Mobile: show inline below field */}
      {help && (
        <p className="text-xs text-muted-foreground sm:hidden">{help}</p>
      )}
    </div>
  )
}
```

This approach avoids requiring a tap to reveal help on a small screen where reading while tapping is awkward.

## Placement Strategy

Default `side="top"` so the popover doesn't obscure the field being explained. For items near the top of the viewport, use `side="bottom"`. Radix's collision detection will auto-flip when the preferred side doesn't have space.

## Key Rules

- Use a `<button type="button">` as the trigger — never a `<span>` or `<div>`
- Use popovers for multi-line or interactive help content; use tooltips only for short plain text labels
- Never put links inside a `<Tooltip>` — they cannot be clicked
- On mobile breakpoints, show help text inline below the field instead of hiding it behind a tap
- Set `aria-label="Help: [field name]"` on the trigger so screen readers announce what the help is about
- Let the library (Radix, Floating UI) handle ARIA and focus management — do not override `aria-expanded` or `aria-haspopup` manually
