# Progressive Enhancement Principle

## What It Is

Progressive enhancement means building the core functionality first, then layering improvements for better experiences. The inverse — graceful degradation — starts with the full experience and removes features for constrained environments.

For web apps: the core must work. Enhancements make it better.

## Application Layers

**Layer 1 — Functional core**
The feature works. Data loads, forms submit, user gets the result.
No animations, no fancy loading states, no optimistic updates.

**Layer 2 — Performance**
Loading states, skeleton screens, error boundaries. The experience is smooth.
Pages don't flash blank white. Errors are communicated.

**Layer 3 — Delight**
Animations, hover effects, transitions, sound feedback.
Nice to have. First to remove if performance suffers.

**Layer 4 — Edge optimization**
Optimistic updates, infinite scroll, prefetching, offline support.
Only add when Layer 1-3 are solid.

## Why This Matters for AI-Assisted Development

AI agents (and human developers under pressure) tend to implement Layer 4 features before Layer 1 is solid. An animated loading skeleton looks impressive but is worthless if the underlying API fails silently.

Build sequence rule:
1. Data flows correctly
2. Errors are handled
3. Loading states show
4. Animations added last

## Real Examples

### Invoice feature
Layer 1: User can create an invoice and it saves to the database. No loading state, no animation.
Layer 2: Loading spinner during submission, success message, error message on failure.
Layer 3: Smooth form transition, subtle entry animation for the new invoice in the list.
Layer 4: Optimistic update (invoice appears instantly before server confirms).

Ship Layer 1 first. Users can use Layer 1. Users cannot use Layer 4 with a broken Layer 1.

### Image loading
Layer 1: Images load. May cause layout shift (CLS).
Layer 2: Images have dimensions specified, no layout shift. Blur placeholder shows.
Layer 3: Lazy loading, `priority` on LCP image.
Layer 4: Low-quality image placeholder (LQIP) that fades to full quality.

## Server Components and Progressive Enhancement

Next.js App Router naturally supports progressive enhancement:

```typescript
// The basic form works without JavaScript
<form action={serverAction}>
  <input name="email" type="email" required />
  <button type="submit">Subscribe</button>
</form>

// Enhanced with React Hook Form for better UX (Layer 2-3)
// But the basic form still works if JavaScript fails to load
```

Server Actions work with basic HTML form submissions — no JavaScript needed for Layer 1. This is built-in progressive enhancement.

## Avoid Feature Creep Before Core is Solid

Signs you're building Layer 3 before Layer 1 is working:
- Adding transitions to a form that doesn't submit yet
- Building a skeleton screen for data that isn't loading yet
- Implementing optimistic updates before the mutation endpoint exists

When this happens: stop, build the core (Layer 1), verify it works, then add the enhancement.
