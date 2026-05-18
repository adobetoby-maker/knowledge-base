# QA: Mobile / Responsive Checklist

## Overview

Mobile QA covers: viewport behavior, touch targets, safe area insets, keyboard behavior, and common iOS Safari bugs. Test at 375px (iPhone SE), 390px (iPhone 14), and 428px (iPhone 14 Plus). Test on real iOS Safari — it behaves differently from Chrome on Mac.

## Viewport Meta Tag

```html
<!-- Required for responsive behavior -->
<meta name="viewport" content="width=device-width, initial-scale=1" />

<!-- Prevents iOS from scaling on form focus (older iOS)
     NOT recommended for accessibility — don't use user-scalable=no -->
```

## Touch Target Sizes

```
☐ Minimum touch target: 44×44px (Apple HIG) or 48×48dp (Android)
☐ Adequate spacing between adjacent touch targets (≥ 8px)
```

```tsx
// BAD — icon button is only 16×16px visually
<button className="p-0"><CloseIcon className="w-4 h-4" /></button>

// GOOD — expanded touch area with padding
<button className="p-3"><CloseIcon className="w-4 h-4" /></button>
// Or use min-w/min-h:
<button className="min-w-[44px] min-h-[44px] flex items-center justify-center">
  <CloseIcon className="w-4 h-4" />
</button>
```

## Safe Area Insets (iPhone Notch / Home Bar)

```css
/* Bottom nav must be above home bar */
.bottom-nav {
  padding-bottom: env(safe-area-inset-bottom);
}

/* Fixed headers must not overlap with status bar */
.sticky-header {
  padding-top: env(safe-area-inset-top);
}
```

```tsx
// With Tailwind CSS (requires tailwindcss-safe-area plugin)
<div className="pb-safe">
<div className="pt-safe">
```

## iOS Keyboard Behavior

```tsx
// iOS Safari scrolls to focused input — can shift fixed elements
// Detect keyboard open via visualViewport
useEffect(() => {
  function handleResize() {
    const keyboardOpen = window.visualViewport!.height < window.innerHeight * 0.75
    document.documentElement.style.setProperty(
      '--keyboard-height',
      keyboardOpen ? `${window.innerHeight - window.visualViewport!.height}px` : '0px'
    )
  }

  window.visualViewport?.addEventListener('resize', handleResize)
  return () => window.visualViewport?.removeEventListener('resize', handleResize)
}, [])
```

## Common iOS Safari Bugs

```css
/* Fix: 100vh includes Safari address bar on iOS */
.full-screen {
  height: 100dvh;  /* dvh = dynamic viewport height — updates with address bar */
}

/* Fix: prevent pull-to-refresh on scroll containers that shouldn't bounce */
.scroll-container {
  overscroll-behavior: none;
}

/* Fix: momentum scrolling in overflow containers on iOS */
.scroll-container {
  -webkit-overflow-scrolling: touch;
}
```

## Input Types for Mobile

```tsx
// Use correct input types to trigger the right keyboard
<input type="email" />      // Email keyboard (@, .com)
<input type="tel" />        // Phone keyboard (digits, -)
<input type="number" />     // Number keyboard
<input type="search" />     // Search keyboard (Return shows "Search")
<input type="url" />        // URL keyboard (/, .com)

// inputMode for visual keyboard without semantic change
<input type="text" inputMode="numeric" pattern="[0-9]*" />  // Digit keyboard
<input type="text" inputMode="decimal" />                   // Decimal keyboard
```

## Responsive Images

```tsx
// Provide multiple sizes for responsive images
<Image
  src="/hero.jpg"
  alt="Hero"
  width={1200}
  height={600}
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
  // Next.js generates srcSet automatically based on sizes
/>
```

## Overflow Scroll

```tsx
// Horizontal scroll containers must hide scrollbar on mobile (visible on desktop)
<div className="overflow-x-auto scrollbar-hide">
  {/* horizontal content */}
</div>

// Text truncation on small screens
<span className="truncate max-w-[200px]">{longTitle}</span>
```

## Mobile QA Checklist

```
☐ Viewport meta tag present
☐ No horizontal scroll on main content at 375px
☐ All buttons/links ≥ 44px touch target
☐ Fixed elements above iPhone home indicator (pb-safe)
☐ Full-screen elements use 100dvh not 100vh
☐ Keyboard doesn't obscure active input on iOS
☐ Correct input types for mobile keyboards
☐ Test on real iOS Safari (not just Chrome DevTools emulation)
☐ Pull-to-refresh prevented on scroll containers where appropriate
☐ No text overflow or truncation losing important content
```

## Key Rules

- `100dvh` replaces `100vh` for full-screen layouts — `100vh` includes the Safari address bar and causes content to overflow.
- `env(safe-area-inset-bottom)` padding is required for any fixed bottom bar — without it, content hides behind the iPhone home indicator.
- Test with iOS Safari on a physical device — Chrome DevTools device mode doesn't replicate iOS keyboard behavior, `100dvh`, or safe area insets.
- `inputMode` is orthogonal to `type` — use `inputMode="numeric"` on a `type="text"` field to get the number keyboard without browser number input styling.
- Touch targets smaller than 44px fail Apple's HIG and cause frustration — add padding, not width/height, to avoid affecting layout.
