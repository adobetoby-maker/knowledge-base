# Pattern: Auto-Resize Textarea

## Overview

A textarea that grows with its content avoids the awkward scrollbar-inside-a-form problem. The browser doesn't expose a "natural height" property, so the technique is: set `overflow: hidden`, then read `scrollHeight` (how tall the element would need to be to show all content without scrolling) and apply it as `height`. The `overflow: hidden` is mandatory — without it, `scrollHeight` equals the current height, not the content height, so shrinking never works.

## The Hook

```ts
import { useLayoutEffect, useRef } from 'react'

function useAutoResize(value: string, minHeight = 40, maxHeight = 400) {
  const ref = useRef<HTMLTextAreaElement>(null)

  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return

    // Reset to min height first so scrollHeight reflects content, not previous height
    el.style.height = `${minHeight}px`
    const scrollH = el.scrollHeight
    el.style.height = `${Math.min(scrollH, maxHeight)}px`
    // Only show scrollbar when capped at maxHeight
    el.style.overflowY = scrollH > maxHeight ? 'auto' : 'hidden'
  }, [value, minHeight, maxHeight])

  return ref
}
```

`useLayoutEffect` runs synchronously after DOM mutations but before the browser paints. Using `useEffect` here causes a visible flash — the textarea renders at old height, then jumps to the new height. For layout measurement, always use `useLayoutEffect`.

## Component

```tsx
interface AutoResizeTextareaProps extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {
  value: string
  minHeight?: number
  maxHeight?: number
}

function AutoResizeTextarea({
  value,
  minHeight = 40,
  maxHeight = 400,
  style,
  ...props
}: AutoResizeTextareaProps) {
  const ref = useAutoResize(value, minHeight, maxHeight)

  return (
    <textarea
      ref={ref}
      value={value}
      style={{
        ...style,
        overflow: 'hidden',       // Required — see note above
        resize: 'none',            // Disable manual resize handle; it fights the auto-resize
        minHeight,
      }}
      {...props}
    />
  )
}
```

## Triggering Resize on External Value Changes

When a parent resets the textarea value (e.g., "clear form" button), the `value` prop changes but the user didn't type anything, so no `onChange` fires. The `useLayoutEffect` dependency on `value` handles this correctly — any value change, internal or external, triggers a resize.

This is why passing `value` as the dependency (not a ref or event) is the right approach.

## CSS-Only Alternative (Limited)

The `field-sizing: content` CSS property achieves this without JavaScript in modern browsers:

```css
textarea {
  field-sizing: content;
  min-height: 40px;
  max-height: 400px;
  overflow-y: auto;
}
```

Browser support as of 2025: Chrome 123+, Firefox 128+, Safari 17.4+. Use this for new projects targeting modern browsers; keep the JS hook for broader compatibility or when you need programmatic control.

## Inside a react-hook-form

```tsx
function MessageField() {
  const { register, watch } = useForm<{ message: string }>()
  const value = watch('message') ?? ''
  const { ref: rhfRef, ...rest } = register('message')

  const sizeRef = useAutoResize(value)

  return (
    <textarea
      {...rest}
      ref={(el) => {
        sizeRef.current = el
        rhfRef(el)   // rhf also needs the ref for validation
      }}
      style={{ overflow: 'hidden', resize: 'none' }}
    />
  )
}
```

Merge the two refs by calling both in the ref callback.

## Key Rules

- `overflow: hidden` on the textarea is not optional — without it, `scrollHeight` won't shrink when content is deleted.
- Reset height to `minHeight` before reading `scrollHeight` on every update, or the element won't shrink.
- Use `useLayoutEffect`, not `useEffect`, to avoid layout flash.
- `resize: none` prevents users from manually resizing in a way that conflicts with the auto-size logic.
- The `maxHeight` cap should re-enable `overflow-y: auto` at that point so the textarea doesn't overflow its container.
- When using with react-hook-form, merge the size ref and the register ref in the callback ref pattern.
