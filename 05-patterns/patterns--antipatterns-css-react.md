---
name: anti-patterns
description: Use when reviewing code, debugging recurring issues,
  or checking work before commit — patterns that consistently cause
  problems and must be avoided
---

# Anti-Patterns — What Not To Do

## CSS Anti-Patterns

### Never use magic numbers
```css
/* ❌ Magic number — nobody knows why 73px */
.header { height: 73px; }

/* ✅ Named value */
:root { --nav-height: 64px; }
.header { height: var(--nav-height); }
```

### Never fight the browser with !important
```css
/* ❌ Using !important to force styles */
.button { color: white !important; }

/* ✅ Fix the specificity instead */
.nav .primary-button { color: white; }
```

### Never use pixel widths on containers
```css
/* ❌ Breaks on unexpected screen sizes */
.content { width: 960px; }

/* ✅ Use max-width with full width */
.content { width: 100%; max-width: 960px; margin: 0 auto; }
```

### Never use vw for text without clamp
```css
/* ❌ Text too small on mobile, too large on desktop */
h1 { font-size: 5vw; }

/* ✅ Clamp with min and max */
h1 { font-size: clamp(2rem, 5vw, 4rem); }
```

### Never animate non-transform/opacity properties
```css
/* ❌ Causes layout recalculation — janky */
.card:hover { width: 110%; top: -4px; }

/* ✅ Only transform and opacity */
.card:hover { transform: translateY(-4px) scale(1.01); }
```

---

## React Anti-Patterns

### Never mutate state directly
```jsx
// ❌ Mutating array directly
const addItem = () => {
  items.push(newItem) // doesn't trigger re-render
  setItems(items)
}

// ✅ Create new array
const addItem = () => {
  setItems([...items, newItem])
}
```

### Never use array index as key (for dynamic lists)
```jsx
// ❌ Keys change when list reorders
{items.map((item, index) => <Item key={index} />)}

// ✅ Use stable unique ID
{items.map(item => <Item key={item.id} />)}
```

### Never fetch inside render
```jsx
// ❌ Fetches on every render
const Component = () => {
  const data = fetch('/api/data') // runs every render
}

// ✅ Fetch in useEffect or custom hook
const Component = () => {
  const [data, setData] = useState(null)
  useEffect(() => {
    fetch('/api/data').then(r => r.json()).then(setData)
  }, [])
}
```

### Never do expensive work in render
```jsx
// ❌ Sorts 10,000 items on every render
const Component = ({ items, filter }) => {
  const filtered = items.filter(...).sort(...) // expensive

// ✅ Memoize expensive calculations
const Component = ({ items, filter }) => {
  const filtered = useMemo(
    () => items.filter(...).sort(...),
    [items, filter]
  )
}
```

### Never use useEffect for derived state
```jsx
// ❌ Unnecessary effect for derived value
const [items, setItems] = useState([])
const [count, setCount] = useState(0)
useEffect(() => { setCount(items.length) }, [items])

// ✅ Derive directly
const [items, setItems] = useState([])
const count = items.length // just a variable
```

---

## Performance Anti-Patterns

### Never import entire libraries
```javascript
// ❌ Imports entire lodash (70kb)
import _ from 'lodash'
const result = _.groupBy(items, 'category')

// ✅ Import only what's needed
import groupBy from 'lodash-es/groupBy'
const result = groupBy(items, 'category')

// ✅✅ Even better — write 5 lines of vanilla JS
const result = items.reduce((acc, item) => {
  acc[item.category] = [...(acc[item.category] || []), item]
  return acc
}, {})
```

### Never load large images without optimization
```jsx
// ❌ 4MB unoptimized hero image
<img src="hero-original.jpg" />

// ✅ Optimized WebP with proper sizing
<picture>
  <source srcset="hero-800.webp 800w, hero-1600.webp 1600w" type="image/webp" />
  <img src="hero-800.jpg" width="1600" height="900" alt="..." loading="eager" />
</picture>
```

### Never block render with synchronous operations
```javascript
// ❌ Synchronous localStorage reads block render
const App = () => {
  const theme = localStorage.getItem('theme') // blocks
}

// ✅ Read before React loads (in index.html)
// Or use useEffect to read asynchronously
```

---

## Deployment Anti-Patterns

### Never commit secrets
```bash
# ❌ NEVER do this
SUPABASE_KEY=eyJhbGciOi... in .env committed to git

# ✅ Use .env.local (gitignored) + set in Cloudflare Dashboard
# Verify: grep -r "eyJhbGciOi" . --include="*.ts" --include="*.env"
```

### Never deploy without testing
```bash
# ❌ Direct to main
git commit -m "quick fix" && git push origin main

# ✅ Build and test locally first
npm run build && npm run preview
# Then take screenshots
# Then deploy
```

### Never ignore build warnings
```bash
# ❌ Ignoring TypeScript errors
// @ts-nocheck at top of file

# ✅ Fix the actual type error
# Warnings today are errors tomorrow
```

---

## UX Anti-Patterns

### Never use placeholder as label
```html
<!-- ❌ Label disappears when user types -->
<input placeholder="Email address" />

<!-- ✅ Real label always visible -->
<label for="email">Email address</label>
<input id="email" placeholder="john@example.com" />
```

### Never auto-play video with sound
```html
<!-- ❌ Immediately annoying -->
<video src="promo.mp4" autoplay></video>

<!-- ✅ Muted autoplay is acceptable -->
<video src="promo.mp4" autoplay muted loop playsinline></video>
```

### Never use hover-only interactions
```css
/* ❌ Mobile users can't hover */
.tooltip { display: none; }
.item:hover .tooltip { display: block; }

/* ✅ Use click/focus for mobile too */
.tooltip { display: none; }
.item:hover .tooltip,
.item:focus-within .tooltip { display: block; }
```

### Never make users work to find the CTA
```
❌ CTA below the fold, buried in text, low contrast
✅ CTA visible immediately, high contrast, clear action label
```
