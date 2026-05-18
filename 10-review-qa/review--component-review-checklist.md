# Component Review Checklist

## Server vs Client Component Decision

- [ ] Component is Server Component by default (no 'use client' unless needed)
- [ ] 'use client' added ONLY when component uses: hooks, event handlers, browser APIs, interactivity
- [ ] Data fetching happens in Server Components, not Client Components
- [ ] Client Components receive data as props, not fetch it themselves (unless using TanStack Query)

## Props Design

- [ ] Props are typed with TypeScript interface
- [ ] No `any` type in props
- [ ] Optional props have sensible defaults
- [ ] No prop drilling more than 2 levels (use context or composition instead)
- [ ] Callback props named with `on` prefix: `onSubmit`, `onChange`, `onDelete`

## Performance

- [ ] Columns/config objects defined OUTSIDE component body (not recreated each render)
- [ ] Large lists virtualized if > 100 items (use `@tanstack/react-virtual`)
- [ ] Images use `next/image` with explicit dimensions
- [ ] No unnecessary `useEffect` that could be replaced with derived state
- [ ] `useCallback` only where the callback is passed to memo'd children (not everywhere)

## Accessibility

- [ ] Interactive elements use semantic HTML (`<button>`, `<a>`, not `<div onClick>`)
- [ ] Images have appropriate `alt` text
- [ ] Form inputs have associated `<label>` elements
- [ ] Focus visible (not removed with `outline-none` without replacement)
- [ ] Dynamic content updates announced with `role="alert"` or `aria-live`

## Error States

- [ ] Component handles empty state (no data)
- [ ] Component handles loading state
- [ ] Component handles error state
- [ ] Errors don't leave the UI in a broken/partial state

## Composition

- [ ] Component does one thing well (not a monolith)
- [ ] Logic extracted to custom hooks when it gets complex
- [ ] Conditional rendering uses early return pattern, not deeply nested ternaries

```typescript
// MESSY:
return (
  <div>
    {loading ? <Skeleton /> : error ? <ErrorMessage /> : data ? <Content /> : null}
  </div>
)

// CLEAN:
if (loading) return <Skeleton />
if (error) return <ErrorMessage error={error} />
if (!data) return null
return <Content data={data} />
```

## Naming

- [ ] Component name is PascalCase and describes what it renders
- [ ] File name matches component name
- [ ] Event handlers named `handle[Action]`: `handleSubmit`, `handleDelete`, `handleStatusChange`
- [ ] Boolean props use `is/has/can` prefix: `isLoading`, `hasError`, `canEdit`

## Side Effects

- [ ] Every `useEffect` with subscriptions/listeners has a cleanup return
- [ ] `useEffect` deps array is complete (no missing dependencies)
- [ ] Side effects that don't need cleanup don't use `useEffect` at all

## Memoization (Only Where Needed)

```typescript
// USE memo/useCallback only when:
// 1. Component re-renders frequently and rendering is expensive
// 2. Callback is passed to a memo'd child that would otherwise re-render

// DON'T memoize:
// - Simple presentational components
// - Functions that aren't passed as props
// - Values that aren't used in deps arrays
```

## Shadcn Component Usage

- [ ] Shadcn components used from `@/components/ui/` (not custom reimplementation)
- [ ] `cn()` utility used for conditional class names (not template literals)
- [ ] `variant` prop used for style variations (not inline `className` overrides)
- [ ] `asChild` used when wrapping shadcn trigger/button around custom elements
