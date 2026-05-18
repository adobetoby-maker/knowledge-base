---
name: high-end-css-patterns
description: Use when writing CSS for visual impact, creating high-end
  effects, glass morphism, gradients, typography, layouts, or any
  advanced CSS technique for engaging educational sites
---

# High-End CSS Patterns

## Design Philosophy
Toby's sites are NOT generic. They use CSS as a design tool —
not just for layout but for creating feeling, depth, and engagement.

---

## Typography System
```css
/* Fluid type scale — scales smoothly between breakpoints */
:root {
  --text-xs:   clamp(0.75rem,  1.5vw,  0.875rem);
  --text-sm:   clamp(0.875rem, 2vw,    1rem);
  --text-base: clamp(1rem,     2.5vw,  1.125rem);
  --text-lg:   clamp(1.125rem, 3vw,    1.25rem);
  --text-xl:   clamp(1.25rem,  3.5vw,  1.5rem);
  --text-2xl:  clamp(1.5rem,   4vw,    2rem);
  --text-3xl:  clamp(1.875rem, 5vw,    2.5rem);
  --text-4xl:  clamp(2.25rem,  6vw,    3.5rem);
  --text-5xl:  clamp(3rem,     8vw,    5rem);
  --text-hero: clamp(3.5rem,   10vw,   7rem);

  /* Line heights */
  --leading-tight:  1.1;
  --leading-snug:   1.3;
  --leading-normal: 1.5;
  --leading-relaxed: 1.7;
  --leading-loose:  2;

  /* Letter spacing */
  --tracking-tight:  -0.025em;
  --tracking-normal: 0;
  --tracking-wide:   0.05em;
  --tracking-wider:  0.1em;
  --tracking-caps:   0.15em;
}

/* Hero headline style */
.hero-heading {
  font-size: var(--text-hero);
  line-height: var(--leading-tight);
  letter-spacing: var(--tracking-tight);
  font-weight: 800;
}

/* Readable body text */
.body-text {
  font-size: var(--text-base);
  line-height: var(--leading-relaxed);
  max-width: 65ch; /* optimal reading width */
}

/* Overline/eyebrow text */
.eyebrow {
  font-size: var(--text-sm);
  font-weight: 600;
  letter-spacing: var(--tracking-caps);
  text-transform: uppercase;
}
```

---

## Color System
```css
:root {
  /* Primary palette */
  --color-primary-50:  hsl(220, 100%, 97%);
  --color-primary-100: hsl(220, 95%,  93%);
  --color-primary-500: hsl(220, 90%,  56%);
  --color-primary-600: hsl(220, 85%,  47%);
  --color-primary-700: hsl(220, 80%,  38%);
  --color-primary-900: hsl(220, 75%,  20%);

  /* Neutral palette */
  --color-gray-50:  hsl(220, 20%, 98%);
  --color-gray-100: hsl(220, 15%, 95%);
  --color-gray-200: hsl(220, 12%, 90%);
  --color-gray-400: hsl(220, 10%, 65%);
  --color-gray-600: hsl(220, 10%, 40%);
  --color-gray-800: hsl(220, 12%, 20%);
  --color-gray-900: hsl(220, 15%, 12%);

  /* Semantic */
  --color-success: hsl(142, 70%, 45%);
  --color-warning: hsl(38,  90%, 50%);
  --color-error:   hsl(0,   75%, 50%);
}
```

---

## Glass Morphism
```css
/* Frosted glass card */
.glass-card {
  background: rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(12px) saturate(180%);
  -webkit-backdrop-filter: blur(12px) saturate(180%);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 16px;
  box-shadow: 
    0 4px 16px rgba(0, 0, 0, 0.12),
    inset 0 1px 0 rgba(255, 255, 255, 0.15);
}

/* Dark glass */
.glass-dark {
  background: rgba(0, 0, 0, 0.25);
  backdrop-filter: blur(16px);
  border: 1px solid rgba(255, 255, 255, 0.06);
}

/* Glass nav */
.glass-nav {
  background: rgba(255, 255, 255, 0.85);
  backdrop-filter: blur(20px) saturate(200%);
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
}

/* Glass fallback for no backdrop-filter support */
@supports not (backdrop-filter: blur(1px)) {
  .glass-card {
    background: rgba(255, 255, 255, 0.95);
  }
}
```

---

## Gradient Patterns
```css
/* Mesh gradient background */
.mesh-gradient {
  background-color: #0f172a;
  background-image:
    radial-gradient(at 40% 20%, hsla(220, 90%, 60%, 0.3) 0px, transparent 50%),
    radial-gradient(at 80% 0%, hsla(280, 90%, 60%, 0.2) 0px, transparent 50%),
    radial-gradient(at 0% 50%, hsla(180, 90%, 50%, 0.2) 0px, transparent 50%),
    radial-gradient(at 80% 50%, hsla(340, 90%, 60%, 0.2) 0px, transparent 50%),
    radial-gradient(at 0% 100%, hsla(240, 90%, 60%, 0.3) 0px, transparent 50%);
}

/* Animated gradient */
.animated-gradient {
  background: linear-gradient(
    135deg,
    hsl(220, 90%, 56%),
    hsl(280, 90%, 60%),
    hsl(340, 90%, 60%),
    hsl(220, 90%, 56%)
  );
  background-size: 300% 300%;
  animation: gradient-shift 8s ease infinite;
}

@keyframes gradient-shift {
  0%, 100% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
}

/* Text gradient */
.gradient-text {
  background: linear-gradient(135deg, #3b82f6, #8b5cf6, #ec4899);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
```

---

## Shadow System
```css
:root {
  --shadow-xs:  0 1px 2px rgba(0,0,0,0.05);
  --shadow-sm:  0 2px 4px rgba(0,0,0,0.07), 0 1px 2px rgba(0,0,0,0.05);
  --shadow-md:  0 4px 8px rgba(0,0,0,0.08), 0 2px 4px rgba(0,0,0,0.06);
  --shadow-lg:  0 8px 24px rgba(0,0,0,0.10), 0 4px 8px rgba(0,0,0,0.06);
  --shadow-xl:  0 16px 40px rgba(0,0,0,0.12), 0 8px 16px rgba(0,0,0,0.06);
  --shadow-2xl: 0 24px 64px rgba(0,0,0,0.15), 0 12px 24px rgba(0,0,0,0.08);
  
  /* Colored shadows for brand elements */
  --shadow-primary: 0 8px 24px rgba(59, 130, 246, 0.35);
  --shadow-purple:  0 8px 24px rgba(139, 92, 246, 0.35);
}
```

---

## Advanced Layout Patterns

### Full-Bleed Layout
```css
.content-grid {
  display: grid;
  grid-template-columns:
    [full-start] minmax(0, 1fr)
    [content-start] min(65ch, calc(100% - 3rem))
    [content-end] minmax(0, 1fr)
    [full-end];
}

.content-grid > * { grid-column: content; }
.content-grid > .full-bleed { grid-column: full; }
```

### Sticky Sidebar Layout
```css
.sidebar-layout {
  display: grid;
  grid-template-columns: 280px 1fr;
  gap: 4rem;
  align-items: start;
}

.sidebar {
  position: sticky;
  top: calc(var(--nav-height) + 2rem);
  max-height: calc(100vh - var(--nav-height) - 4rem);
  overflow-y: auto;
}

@media (max-width: 1024px) {
  .sidebar-layout {
    grid-template-columns: 1fr;
  }
  .sidebar { position: static; }
}
```

### Card Grid
```css
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(320px, 100%), 1fr));
  gap: 1.5rem;
}
```

---

## Interactive Micro-Patterns

### Hover Card Lift
```css
.card {
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-xl);
}
```

### Underline Animation
```css
.animated-link {
  position: relative;
  text-decoration: none;
}
.animated-link::after {
  content: '';
  position: absolute;
  bottom: -2px;
  left: 0;
  width: 0;
  height: 2px;
  background: currentColor;
  transition: width 0.3s ease;
}
.animated-link:hover::after { width: 100%; }
```

### Focus Ring (Accessible)
```css
:focus-visible {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 3px;
  border-radius: 4px;
}
```

---

## CSS Fallbacks

### backdrop-filter not supported
```css
@supports not (backdrop-filter: blur(1px)) {
  .glass { background: rgba(255,255,255,0.97); }
}
```

### CSS Grid not available
```css
.grid {
  display: flex;
  flex-wrap: wrap;
  gap: 1.5rem;
}
.grid > * { flex: 1 1 280px; }
```

### CSS custom properties not supported
```css
/* Always provide fallback value */
color: #3b82f6;
color: var(--color-primary-500, #3b82f6);
```

### clamp() not supported
```css
font-size: 2.5rem;
font-size: clamp(1.5rem, 4vw, 2.5rem);
```

### Gradient text not working
```css
/* Fallback for unsupported browsers */
.gradient-text {
  color: #3b82f6; /* solid fallback */
}
@supports (-webkit-background-clip: text) {
  .gradient-text {
    background: linear-gradient(135deg, #3b82f6, #8b5cf6);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }
}
```
