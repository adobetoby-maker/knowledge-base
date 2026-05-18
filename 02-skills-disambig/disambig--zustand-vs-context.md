# Zustand vs React Context

## The Re-render Problem With Context

React Context is not a state management solution — it is a dependency injection mechanism. When a context value changes, every component that calls `useContext` with that context re-renders, regardless of whether the specific slice of data they consume changed.

This is fine when the value changes infrequently. It becomes a performance problem when the context value changes on every keystroke, every scroll event, or every item selection. A cart context with 50 items that renders a header badge, a sidebar list, and a checkout total will re-render all three on every quantity change, even if only one of them needs the new value.

Context does not support selective subscription. There is no built-in equivalent to "re-render only when `cart.itemCount` changes."

## How Zustand Solves This

Zustand stores are external to the React tree. Components subscribe to a slice of the store using a selector function. When the store updates, only components whose selected slice actually changed (by reference equality) re-render.

```ts
// Only re-renders when itemCount changes, not when item names or prices change
const itemCount = useCartStore(state => state.itemCount)
```

This is the fundamental reason to choose Zustand over Context for frequently-updating shared state: granular subscriptions prevent unnecessary renders without requiring `React.memo`, `useMemo`, or manual optimization.

## When Context Is Correct

Context is appropriate when the value changes infrequently and the consumer tree is small or tolerates re-renders. The canonical examples:

- **Theme** — changes once per user session at most
- **Auth/user identity** — changes on login/logout, not on interaction
- **Locale/i18n** — static for the lifetime of a page load
- **Feature flags** — read-only after initial load
- **Modal/toast state** — typically one component consuming it

For these cases, Context is simpler, requires no dependencies, and the re-render cost is negligible.

## When Zustand Is Correct

Zustand is appropriate when state changes frequently and multiple components across the tree need to react to it selectively:

- **Shopping cart** — quantity changes, item additions/removals happening during normal interaction
- **Selection state** — which rows are selected in a table, which nodes are selected on a canvas
- **Filter/sort state** — UI controls that update on every user interaction
- **Multi-step form data** — values changing on every field edit, consumed by a progress indicator, a preview, and the submit handler
- **Real-time data** — WebSocket updates that need to reach specific components without re-rendering the whole tree

## The "Just Use Context" Trap

The trap is starting with Context because it requires no library, then adding `useMemo` everywhere to suppress re-renders, then splitting the context into smaller contexts to limit scope, then realizing the code is more complex than Zustand would have been. Context plus performance optimization is harder than Zustand.

The other trap is reaching for Zustand for everything, including theme and auth. Zustand adds a dependency and a store module. For state that never changes during user interaction, Context is the right tool.

## Composition Pattern

Use both together. Context for static or near-static configuration (theme, auth, locale). Zustand for interactive, mutable, frequently-changing shared state. They don't compete — they serve different roles.

## Key Rules

- If a context value changes during normal user interaction, use Zustand instead
- Never add `React.memo` or split contexts to fix Context re-render problems — that is a signal to switch to Zustand
- Theme, auth, and locale belong in Context; cart, selections, and filters belong in Zustand
- Always write selector functions in `useStore(selector)` form — subscribing to the entire store defeats granular re-render prevention
- Zustand stores should be defined outside components in module scope, never inside a component or hook
- Avoid Zustand for data that is already in a server state library (TanStack Query, SWR) — do not duplicate server state into a Zustand store
