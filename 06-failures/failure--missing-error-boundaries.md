# Failure: Missing React Error Boundaries

## Overview
In React, an uncaught rendering error in any component propagates up the component tree and crashes the entire application — producing a blank white screen with no user-visible error message. A single broken component kills the whole page. React's `ErrorBoundary` component intercepts rendering errors within its subtree and renders a fallback UI instead of propagating the crash. Without error boundaries, one edge case in one widget (a null pointer on bad API data, a browser compatibility issue) destroys the user's entire session.

## How React Propagates Errors Without Boundaries

```
App
├── Header ← error here
├── Sidebar
└── MainContent
    ├── UserProfile
    └── OrderList ← error here crashes entire tree
```

Any component throwing during render causes React to unmount the entire tree above it (up to the nearest error boundary or the root). Without boundaries: blank white screen.

## Class-Based Error Boundary (Required — Hooks Cannot Catch Render Errors)

React's error boundary mechanism requires a class component. It cannot be implemented with hooks:

```typescript
import { Component, ReactNode, ErrorInfo } from "react";

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
  onError?: (error: Error, info: ErrorInfo) => void;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // Report to error tracking
    console.error("ErrorBoundary caught:", error, info.componentStack);
    this.props.onError?.(error, info);
    // Sentry: Sentry.captureException(error, { extra: { componentStack: info.componentStack } });
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? (
        <div role="alert" className="error-boundary-fallback">
          <p>Something went wrong.</p>
          <button onClick={this.handleRetry}>Try again</button>
        </div>
      );
    }
    return this.props.children;
  }
}
```

## Placement Strategy

Error boundaries should be placed strategically — wrapping sections of the UI that can fail independently:

```typescript
// Route-level boundary — prevents full-page crashes
export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <ErrorBoundary
      fallback={<PageErrorFallback />}
      onError={(error) => Sentry.captureException(error)}
    >
      {children}
    </ErrorBoundary>
  );
}

// Widget-level boundary — widget can crash without killing the page
function Dashboard() {
  return (
    <div className="grid">
      <ErrorBoundary fallback={<WidgetError name="Revenue Chart" />}>
        <RevenueChart /> {/* complex chart with risky rendering */}
      </ErrorBoundary>
      
      <ErrorBoundary fallback={<WidgetError name="Recent Orders" />}>
        <RecentOrders /> {/* depends on external API */}
      </ErrorBoundary>
    </div>
  );
}
```

## Error Boundaries Do NOT Catch

Error boundaries catch errors during rendering and lifecycle methods. They do NOT catch:
- Errors in event handlers (use try/catch inside the handler)
- Errors in async code (`setTimeout`, `Promise` rejections)
- Errors in server-side rendering
- Errors thrown in the error boundary itself

```typescript
// These errors are NOT caught by error boundaries:
<button onClick={async () => {
  try {
    await riskyOperation(); // must handle with try/catch
  } catch (error) {
    setError(error); // use state to show error UI
  }
}}>
  Click me
</button>
```

## The react-error-boundary Library

`react-error-boundary` provides a hook-friendly wrapper that reduces boilerplate:

```typescript
import { ErrorBoundary, useErrorBoundary } from "react-error-boundary";

function OrderList() {
  const { showBoundary } = useErrorBoundary();
  
  const handleClick = async () => {
    try {
      await loadOrders();
    } catch (error) {
      showBoundary(error); // triggers error boundary from async code
    }
  };
  
  return <button onClick={handleClick}>Load Orders</button>;
}

// Usage
<ErrorBoundary
  FallbackComponent={({ error, resetErrorBoundary }) => (
    <div>
      <p>Error: {error.message}</p>
      <button onClick={resetErrorBoundary}>Retry</button>
    </div>
  )}
  onError={(error, info) => Sentry.captureException(error)}
>
  <OrderList />
</ErrorBoundary>
```

## Key Rules
- Route-level error boundary wraps every page — no page delivers a blank screen
- Complex, data-dependent widgets get their own error boundary
- Error boundaries report to Sentry (or equivalent) in `componentDidCatch`
- Fallback UI shows a meaningful message + retry button, not just "Something went wrong"
- `react-error-boundary`'s `useErrorBoundary` bridges async errors to boundary state
- Never use error boundaries to swallow errors silently — always log them
- Development mode in React throws errors more aggressively — test error boundaries in production mode too
