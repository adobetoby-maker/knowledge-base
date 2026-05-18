# Mobile-First Design

**When:** Building any UI component, page, or layout.
**Rule:** Design for 375px first. Then expand to 768px, 1280px, 1920px. Never design desktop-first and retrofit mobile.

## Why Mobile-First Wins
1. Mobile is harder — less space, less bandwidth, touch instead of hover, viewport changes on scroll
2. If it works at 375px, it'll work everywhere with `max-width` and `grid-template-columns`
3. CSS mobile-first means `min-width` breakpoints — additive, not subtractive
4. Retrofitting mobile is always 2-3x more work than designing mobile-first

## The Four Checkpoints
```
375px   — iPhone SE, most Android budget phones. If it works here, it works.
768px   — iPad portrait, most tablets. Add layout changes here.
1280px  — most laptops. Full layout unlocks here.
1920px  — desktop. Add max-width centering here.
```

## CSS Breakpoint Pattern (Tailwind)
```tsx
// Mobile-first: base styles are mobile, breakpoints add desktop behavior
<div className="
  flex flex-col gap-4          // mobile: stack vertically
  md:flex-row md:gap-8         // tablet+: side by side
  lg:max-w-5xl lg:mx-auto      // desktop+: centered, constrained
">
```

## CSS Breakpoint Pattern (vanilla)
```css
/* Base = mobile */
.layout {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

/* Tablet */
@media (min-width: 768px) {
  .layout {
    flex-direction: row;
    gap: 2rem;
  }
}

/* Desktop */
@media (min-width: 1280px) {
  .layout {
    max-width: 1200px;
    margin: 0 auto;
  }
}
```

## Mobile-Specific Gotchas
```css
/* 100vh breaks on mobile browsers (URL bar changes height) — use dvh */
.hero { height: 100dvh; }    /* ✅ dynamic viewport height */
.hero { height: 100vh; }     /* ❌ jumps when browser chrome shows/hides */

/* Touch targets must be at least 44x44px */
button { min-height: 44px; min-width: 44px; }

/* Hover states don't work on touch — don't hide critical info behind hover */
/* Never: .tooltip { display: none } .item:hover .tooltip { display: block } */
/* Always add :focus-within as fallback */

/* Font size under 16px on input causes iOS to auto-zoom */
input, select, textarea { font-size: 16px; } /* minimum */
```

## Screenshot Verification
Always screenshot at 375px width before shipping. Use:
```bash
node ~/screenshot.js <port> 0,540,810  # captures at 3 scroll depths
```
Then manually check at 768px and 1280px in DevTools.
