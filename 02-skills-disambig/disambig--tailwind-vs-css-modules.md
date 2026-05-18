# Disambig: Tailwind CSS vs CSS Modules

## Overview
Tailwind and CSS Modules solve the same problem — scoped, maintainable styles — with opposite philosophies. Tailwind eliminates the naming problem entirely by using utility classes; CSS Modules solves it with local scope. The choice is rarely about capability and almost always about team preference and the type of UI being built.

## Implementation / Key Points

### Tailwind CSS
```tsx
// Styles live in markup — no separate file, no naming decisions
function Button({ variant = 'primary' }) {
  return (
    <button className={cn(
      'px-4 py-2 rounded-md font-medium transition-colors',
      variant === 'primary' && 'bg-indigo-600 text-white hover:bg-indigo-700',
      variant === 'ghost' && 'text-gray-700 hover:bg-gray-100'
    )}>
      Click me
    </button>
  );
}
```
Unused utility classes are purged at build time — bundle size is determined by the number of distinct utilities used, not the number of components.

### CSS Modules
```tsx
// Component file
import styles from './Button.module.css';

function Button({ variant = 'primary' }) {
  return (
    <button className={`${styles.button} ${styles[variant]}`}>
      Click me
    </button>
  );
}

// Button.module.css
.button { padding: 0.5rem 1rem; border-radius: 0.375rem; }
.primary { background: #4f46e5; color: white; }
.primary:hover { background: #4338ca; }
.ghost { color: #374151; }
.ghost:hover { background: #f3f4f6; }
```
Class names are locally scoped — `.button` in `Button.module.css` does not conflict with `.button` in `Card.module.css`.

### Comparison

| | Tailwind | CSS Modules |
|---|---|---|
| Naming required | No | Yes |
| Co-location | Classes in markup | Separate `.module.css` file |
| Complex animations | Awkward | Natural |
| Pseudo-elements | Limited | Full CSS power |
| Design system consistency | Enforced by config | Manual |
| Unused style purging | Automatic | Manual |
| Learning curve | High (utility names) | Low (CSS knowledge) |
| Class list readability | Degrades at scale | Stays clean |

### When to Use Tailwind
- Component-heavy UI with many reusable, small components
- Strong design system consistency is a priority (Tailwind config enforces tokens)
- New projects where team is comfortable with utility-first
- Rapid prototyping

### When to Use CSS Modules
- Complex animations or heavy pseudoselector usage (`::before`, `:nth-child`)
- Legacy codebases with existing CSS conventions
- Teams who find utility class lists difficult to read/review
- Components with many CSS states that would produce very long class strings
- When you need full CSS features like `@keyframes` scoped to a component

### Mixing (Common Pattern)
```tsx
// Global utilities via Tailwind + complex component styles via module
import styles from './Chart.module.css';

function Chart() {
  return (
    <div className={`${styles.container} relative overflow-hidden`}>
      <canvas className={styles.canvas} />
    </div>
  );
}
```

## Key Rules
- Pick one primary approach per project — mixing both evenly creates inconsistency.
- Tailwind works best when all design values come from the config (`tailwind.config.ts`); never hardcode arbitrary pixel values.
- CSS Modules require discipline: unused selectors don't get removed automatically.
- Tailwind's `@apply` directive exists but should be used sparingly — it defeats the utility-first philosophy.
- Both approaches scope styles; the choice is about the ergonomics, not the output.
