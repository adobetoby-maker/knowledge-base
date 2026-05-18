# Review: Mobile QA Checklist

## Viewport and Meta

- [ ] `<meta name="viewport" content="width=device-width, initial-scale=1">` in `<head>`
- [ ] No `maximum-scale=1` or `user-scalable=no` (blocks accessibility zoom)
- [ ] No horizontal scroll at 375px viewport width (iPhone SE)
- [ ] Content doesn't overflow past viewport edge

## Touch Targets

- [ ] All interactive elements minimum 44×44px (Apple) or 48×48dp (Google) tap target
- [ ] Buttons and links not too close together (8px minimum spacing)
- [ ] `touch-action: manipulation` on interactive elements to remove 300ms click delay

```css
button, a, [role="button"] {
  touch-action: manipulation;
}
```

## Text and Readability

- [ ] No text smaller than 16px on input fields (prevents iOS zoom on focus)
- [ ] Text readable without zooming at 375px width
- [ ] Line length under 75 characters on mobile

## Forms

- [ ] `type="email"` on email inputs (shows `@` key on iOS keyboard)
- [ ] `type="tel"` on phone inputs (shows numeric keypad)
- [ ] `type="number"` or `inputMode="decimal"` on numeric inputs
- [ ] `autocomplete` attributes present (address, email, password)
- [ ] Forms don't trigger layout shift on keyboard appear

## Navigation

- [ ] Mobile nav accessible (hamburger or bottom nav)
- [ ] Back button behaves correctly (browser history)
- [ ] Sticky nav height accounted for in scroll offset
- [ ] `env(safe-area-inset-bottom)` for notched devices (iPhone X+)

```css
.fixed-bottom-bar {
  padding-bottom: max(1rem, env(safe-area-inset-bottom));
}
```

## Images

- [ ] All images have `srcset` or Next.js `sizes` prop
- [ ] Images don't overflow viewport on small screens
- [ ] No cumulative layout shift from image loading (explicit width/height)

## Performance

- [ ] Lighthouse Mobile score > 80
- [ ] LCP < 2.5s on simulated 4G
- [ ] No large unoptimized scripts blocking render
- [ ] Fonts loaded with `font-display: swap`

## iOS-Specific

- [ ] `playsInline` on video elements (prevents fullscreen autoplay on iOS)
- [ ] Scroll momentum works (`-webkit-overflow-scrolling: touch` in older iOS)
- [ ] Input fields not zooming on focus (font-size ≥ 16px on input)
- [ ] Date inputs usable (iOS uses native date picker for `type="date"`)

## Android-Specific

- [ ] `theme-color` meta tag for browser chrome
- [ ] No fixed position elements causing scroll jank on Android Chrome

## Testing Approach

1. Use Chrome DevTools Device Emulation (F12 → device icon) for quick checks
2. Test on real device for: scroll feel, keyboard behavior, tap target accuracy
3. Key viewports: 375px (iPhone SE), 390px (iPhone 14), 360px (Android mid-range)
4. Use `node ~/record.js <port> --mobile` for scroll review video

```bash
# Playwright mobile test
mcp__plugin_playwright_playwright__browser_resize({ width: 390, height: 844 })
mcp__plugin_playwright_playwright__browser_navigate({ url: 'http://localhost:3000' })
mcp__plugin_playwright_playwright__browser_take_screenshot({ filename: 'mobile-full.png' })
```

## Keyboard/Accessibility on Mobile

- [ ] VoiceOver (iOS) / TalkBack (Android) can navigate all key features
- [ ] Focus order is logical on small viewport
- [ ] Modals/drawers trap focus correctly
- [ ] Screen reader announces page changes (title update)
