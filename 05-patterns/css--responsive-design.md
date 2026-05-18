# CSS Responsive Design Patterns

## Tailwind Breakpoint System

Tailwind uses mobile-first breakpoints — base classes apply to all sizes, prefixed classes apply at that size and up.

| Prefix | Min-width | Target devices |
|--------|-----------|----------------|
| (none) | 0px | Mobile and up |
| `sm:` | 640px | Small tablet and up |
| `md:` | 768px | Tablet and up |
| `lg:` | 1024px | Laptop and up |
| `xl:` | 1280px | Desktop and up |
| `2xl:` | 1536px | Large desktop |

## Mobile-First Class Ordering

```html
<!-- Wrong — desktop-first thinking *)
<div class="grid-cols-4 sm:grid-cols-2 xs:grid-cols-1">

<!-- Right — mobile-first *)
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4">
```

Read left to right: 1 column on mobile, 2 on tablet, 4 on desktop.

## Common Responsive Layouts

### Responsive grid
```html
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
  {items.map(item => <Card key={item.id} {...item} />)}
</div>
```

### Stack → side by side
```html
<div class="flex flex-col md:flex-row gap-6">
  <aside class="w-full md:w-64 shrink-0">Sidebar</aside>
  <main class="flex-1">Main content</main>
</div>
```

### Responsive hero
```html
<section class="px-4 py-12 md:py-20 lg:py-32">
  <h1 class="text-3xl md:text-5xl lg:text-7xl font-bold">Title</h1>
  <p class="text-base md:text-xl mt-4 max-w-2xl">Description</p>
</section>
```

## Fluid Typography

```css
/* Fluid type without media queries — clamp(min, preferred, max) */
.hero-title {
  font-size: clamp(2rem, 5vw + 1rem, 5rem);
}

.body-text {
  font-size: clamp(1rem, 2vw + 0.5rem, 1.25rem);
}
```

Or with Tailwind custom utilities:
```typescript
// tailwind.config.ts
fontSize: {
  'fluid-xl': 'clamp(1.5rem, 3vw + 1rem, 3rem)',
  'fluid-2xl': 'clamp(2rem, 5vw + 1rem, 5rem)',
}
```

## Container Queries (Tailwind v3.2+)

For components that respond to their container size (not viewport):

```html
<div class="@container">
  <div class="grid grid-cols-1 @md:grid-cols-2 @lg:grid-cols-3">
    {items}
  </div>
</div>
```

Container queries are ideal for reusable components that need to adapt to where they're placed.

## Hiding and Showing by Breakpoint

```html
<!-- Hide on mobile, show on desktop -->
<div class="hidden lg:block">Desktop only content</div>

<!-- Show on mobile, hide on desktop -->
<div class="block lg:hidden">Mobile only content</div>
```

Prefer CSS hide/show over JavaScript conditional rendering — the DOM element exists for SEO and accessibility; it's just visually hidden.

## Safe Area Insets (Mobile notch/home bar)

```html
<footer class="pb-safe px-safe">
  <!-- pb-safe adds iOS safe area bottom padding -->
</footer>
```

Requires Tailwind plugin or manual CSS:
```css
.pb-safe { padding-bottom: env(safe-area-inset-bottom); }
.px-safe { 
  padding-left: env(safe-area-inset-left);
  padding-right: env(safe-area-inset-right);
}
```

Critical for apps with sticky bottom navigation on mobile.

## Touch Target Sizing

Minimum touch target: 44×44px. If a visual element is smaller, add padding to increase the tappable area:

```html
<!-- Visual icon is 20px, but touch target is 44px -->
<button class="p-3 -m-3">
  <Icon class="w-5 h-5" />
</button>
```

Negative margin prevents the padding from affecting layout.

## Viewport Units — dvh vs vh

On mobile, `100vh` includes the browser chrome (address bar). When the chrome hides on scroll, `100vh` elements resize, causing content jump.

```css
/* Wrong on mobile — resizes with browser chrome */
height: 100vh;

/* Right — dynamic viewport height, excludes browser chrome */
height: 100dvh;

/* Or with Tailwind */
class="h-screen"  /* use h-dvh when available in Tailwind v3.4+ */
```

`100dvh` is supported in Safari 15.4+, Chrome 108+, Firefox 101+.
