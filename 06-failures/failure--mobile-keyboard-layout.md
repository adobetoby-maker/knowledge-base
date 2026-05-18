# failure--mobile-keyboard-layout.md

The soft keyboard on mobile doesn't resize the window — it resizes the visual viewport. `100vh` is calculated against the layout viewport (full height before keyboard appears), so elements sized with `100vh` get obscured by the keyboard rather than shrinking to fit. This causes bottom bars, CTAs, and sticky footers to slide underneath the keyboard.

## The Core Problem

`window.innerHeight` updates when the keyboard opens on Android, but **not on iOS Safari**. iOS Safari locks `100vh` to the initial viewport height. The keyboard overlaps content without firing a resize event that the layout reacts to.

`100dvh` (dynamic viewport height) solves this on modern browsers — it reflects the actual available height after browser chrome and keyboard are subtracted. But `100dvh` support isn't universal on older iOS (pre-15.4 Safari) so always pair it with a `100vh` fallback:

```css
height: 100vh;        /* fallback */
height: 100dvh;       /* wins where supported */
```

## Fixed-Position Elements and Keyboard

On iOS, `position: fixed` elements that were anchored to the bottom of the screen get pushed up with the keyboard — they stay "fixed" relative to the visual viewport, not the layout viewport. This is sometimes desired (a send button staying above the keyboard in a chat) but breaks forms where a sticky CTA should stay put at the page bottom.

Fix: listen to `window.visualViewport` resize events and reposition explicitly:

```ts
const vv = window.visualViewport;
function reposition() {
  const offsetFromBottom = window.innerHeight - (vv.height + vv.offsetTop);
  element.style.bottom = `${offsetFromBottom}px`;
}
vv?.addEventListener('resize', reposition);
vv?.addEventListener('scroll', reposition);
```

Clean up these listeners on component unmount or you'll accumulate them across navigations.

## Android vs iOS Differences

**Android Chrome**: fires a genuine `window.resize` when the keyboard opens. `window.innerHeight` reflects the reduced space. Layouts using `100vh` will re-render correctly if flexbox/grid fills the viewport.

**iOS Safari**: no resize event on keyboard open. `window.innerHeight` stays constant. `visualViewport.height` shrinks. Only `visualViewport` events tell you the keyboard appeared.

**iOS WKWebView (in-app browsers)**: behavior is often buggier than Safari proper. Avoid relying on any keyboard detection in webviews.

## Input Focus Scrolling Issues

When an input receives focus and the keyboard opens, iOS scrolls the page to keep the input visible. This scroll happens in the visual viewport, not the document — `scrollTop` on body/html doesn't change. Don't try to counteract this scroll manually; you'll fight the browser and lose. Instead, ensure the input's surrounding container has enough bottom padding to be fully visible above the keyboard after the scroll.

## What Not To Do

- Do not calculate available height with `window.innerHeight - keyboardHeight` where `keyboardHeight` is hardcoded or estimated — keyboard height varies by device, language, and autocomplete bar state.
- Do not use `position: fixed; bottom: 0` for bottom CTAs in forms without the `visualViewport` correction on iOS.
- Do not assume a `resize` event fired means the keyboard opened — browser chrome resize also fires it.

## Key Rules

- Use `100dvh` with `100vh` fallback for full-height containers.
- Use `visualViewport` resize/scroll events for iOS keyboard detection — `window.resize` won't fire.
- Fixed-bottom elements need explicit repositioning on iOS via `visualViewport.height`.
- Android and iOS behave differently; test both, don't assume one fixes the other.
- Never hardcode keyboard height; it varies by device and input method.
