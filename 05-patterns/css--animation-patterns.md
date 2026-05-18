# CSS Animation Patterns — Production Quality

**When:** Adding motion to UI. Hover effects, page transitions, loading states, scroll-triggered reveals.
**Rule:** Motion should reinforce meaning, not decorate. Every animation needs a purpose. Respect `prefers-reduced-motion`.

## The Reduced Motion Rule — ALWAYS First
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```
Or in Tailwind:
```html
<div class="transition-transform motion-reduce:transition-none">
```

## Fade In (most common)
```css
@keyframes fade-in {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}

.fade-in {
  animation: fade-in 0.3s ease-out forwards;
}
```

## Staggered List Animation
```css
/* Parent triggers, children stagger */
.list-item {
  opacity: 0;
  animation: fade-in 0.3s ease-out forwards;
}
.list-item:nth-child(1) { animation-delay: 0ms; }
.list-item:nth-child(2) { animation-delay: 60ms; }
.list-item:nth-child(3) { animation-delay: 120ms; }
.list-item:nth-child(4) { animation-delay: 180ms; }
```
In React, compute delay dynamically:
```tsx
{items.map((item, i) => (
  <li style={{ animationDelay: `${i * 60}ms` }} className="fade-in">
```

## Hover Effects — Tailwind Patterns
```html
<!-- Scale on hover -->
<div class="transition-transform duration-200 hover:scale-105">

<!-- Lift with shadow -->
<div class="transition-all duration-200 hover:-translate-y-1 hover:shadow-lg">

<!-- Color shift -->
<button class="bg-blue-600 transition-colors duration-150 hover:bg-blue-700">

<!-- Underline grow -->
<a class="relative after:absolute after:bottom-0 after:left-0 after:h-0.5 after:w-0 
          after:bg-current after:transition-all hover:after:w-full">
```

## Loading States

### Skeleton Shimmer
```css
@keyframes shimmer {
  0%   { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}

.skeleton {
  background: linear-gradient(90deg, #e5e7eb 25%, #f3f4f6 50%, #e5e7eb 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
  border-radius: 4px;
}
```

### Spinner
```html
<div class="h-5 w-5 animate-spin rounded-full border-2 border-gray-300 border-t-blue-600">
</div>
```

## Scroll-Triggered Reveal (Intersection Observer)
```typescript
// hooks/useReveal.ts
function useReveal() {
  const ref = useRef<HTMLElement>(null)
  const [visible, setVisible] = useState(false)
  
  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setVisible(true) },
      { threshold: 0.1 }
    )
    if (ref.current) observer.observe(ref.current)
    return () => observer.disconnect()
  }, [])
  
  return { ref, visible }
}

// Usage
const { ref, visible } = useReveal()
<section ref={ref} className={`transition-all duration-700 ${visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'}`}>
```

## Animation Timing Guide
```
Micro-interactions (hover, click): 100-200ms
UI transitions (modal, drawer): 200-300ms
Page-level animations: 300-500ms
Decorative / background: 500ms+

ease-out: elements entering the screen (decelerates)
ease-in: elements leaving (accelerates)
ease-in-out: balanced for both
```

## Performance Rules
- Only animate: `transform`, `opacity` (GPU-composited — no layout)
- Never animate: `width`, `height`, `top`, `left`, `margin` (causes layout recalculation)
- Use `will-change: transform` sparingly — only right before animation starts, remove after
