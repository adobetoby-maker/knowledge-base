# Error Boundary Design

Error boundaries in React catch rendering errors in a component subtree and render fallback UI instead of crashing the whole app. But placement, recovery behavior, and fallback UI design determine whether they help users recover or just hide failures.

## Granularity: Per Independent Widget, Not Global

One global error boundary at the root catches everything but recovers nothing — a sidebar crash nukes the entire page. Place boundaries at the granularity of independently useful UI sections.

Concretely: a dashboard with a metrics chart, a recent-activity feed, and a quick-actions panel should have three separate boundaries. If the metrics chart throws, the user can still use the activity feed and quick actions. The crash is contained to the failing widget.

Good candidates for boundaries: route-level pages, async data widgets, third-party component wrappers, heavy visualization components. Bad placement: wrapping individual buttons or form fields — the boundary adds overhead and the fallback is meaningless at that granularity.

## Recovery Actions: Give Users an Exit

A fallback UI that says "Something went wrong" with no action is a dead end. Every boundary fallback should offer at least one recovery path:

- **Retry** — re-mount the component, attempt the fetch again. Works for transient errors (network hiccup, rate limit)
- **Refresh the page** — for state corruption errors where the component tree is stale
- **Navigate away** — "Return to dashboard" link lets the user escape without a full reload
- **Contact support** — last resort, with the error ID pre-filled so support can look it up

Match the action to the likely failure mode. A data widget that failed to load should offer retry. A critical auth component that broke should suggest page refresh.

## Error Reporting from the Boundary

The `componentDidCatch` lifecycle (or the `onError` prop in newer patterns) is where you send errors to your monitoring system. Do this from the boundary itself, not from individual components — boundaries are the choke point where you know an error escaped normal handling.

Attach context: which boundary fired (give each one a `name` prop), the current route, the user ID, and any relevant feature flags. This context transforms "TypeError: Cannot read property of undefined" into "chart widget on /dashboard for logged-in user, after feature flag X enabled."

```jsx
componentDidCatch(error, info) {
  Sentry.withScope(scope => {
    scope.setTag('boundary', this.props.name)
    scope.setContext('componentStack', info.componentStack)
    Sentry.captureException(error)
  })
}
```

## Fallback UI Anti-Patterns

**Blank screen**: Worse than a crash — the user doesn't know if content is loading or broken. Always render something.

**Spinner that never resolves**: A loading spinner in the fallback misleads users into waiting. Reserve spinners for actual loading states with a known resolution. Use "failed to load" messaging with an action instead.

**Full-page error for a partial failure**: If a sidebar widget fails, don't render a full-page error screen. Match the fallback's footprint to the boundary's footprint.

**Swallowing errors silently**: Rendering a fallback without reporting the error means you find out about production failures from users, not monitoring. Always report.

## Key Rules

- Place boundaries at independently useful UI sections, not globally or per-component
- Every fallback must offer at least one recovery action: retry, refresh, or navigate
- Report errors from `componentDidCatch` to your error monitoring service with boundary name and user context
- Never render a spinner as a fallback — it implies loading, not failure
- Match fallback footprint to boundary footprint — a widget crash should not blank the page
- Give each boundary a `name` prop so monitoring can identify which part of the UI failed
- Test error boundaries in development by intentionally throwing from child components
