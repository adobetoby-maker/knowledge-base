# Pattern: Loading + Error Boundary

## Overview
Handling loading and error states ad-hoc in every component leads to inconsistency and forgotten error states. An `AsyncBoundary` component wraps React Suspense and ErrorBoundary together, ensuring every async component gets proper loading UI and error recovery without duplicating the logic. Error boundaries must reset on route change — otherwise navigating away and back still shows the error.

## Implementation

### AsyncBoundary Component
```tsx
import { Suspense, Component, ReactNode, ErrorInfo } from 'react';
import { usePathname } from 'next/navigation';

interface AsyncBoundaryProps {
  children: ReactNode;
  fallback?: ReactNode;           // loading state
  errorFallback?: ReactNode | ((error: Error, reset: () => void) => ReactNode);
}

function AsyncBoundary({ children, fallback, errorFallback }: AsyncBoundaryProps) {
  const pathname = usePathname();

  return (
    <ErrorBoundary
      fallback={errorFallback}
      resetKey={pathname}  // reset error state on route change
    >
      <Suspense fallback={fallback ?? <DefaultSkeleton />}>
        {children}
      </Suspense>
    </ErrorBoundary>
  );
}
```

### ErrorBoundary Class Component
```tsx
interface ErrorBoundaryProps {
  children: ReactNode;
  fallback?: ReactNode | ((error: Error, reset: () => void) => ReactNode);
  resetKey?: string; // resets error when this changes
  onError?: (error: Error, info: ErrorInfo) => void;
}

interface ErrorBoundaryState {
  error: Error | null;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    this.props.onError?.(error, info);
    // Report to error tracking
    reportError(error, { componentStack: info.componentStack });
  }

  componentDidUpdate(prevProps: ErrorBoundaryProps) {
    // Reset when resetKey changes (e.g., route navigation)
    if (this.state.error && prevProps.resetKey !== this.props.resetKey) {
      this.setState({ error: null });
    }
  }

  reset = () => this.setState({ error: null });

  render() {
    if (this.state.error) {
      const fallback = this.props.fallback;
      if (typeof fallback === 'function') {
        return fallback(this.state.error, this.reset);
      }
      return fallback ?? (
        <DefaultErrorFallback error={this.state.error} onRetry={this.reset} />
      );
    }
    return this.props.children;
  }
}
```

### Default Fallbacks
```tsx
function DefaultSkeleton() {
  return (
    <div className="animate-pulse space-y-3">
      <div className="h-4 bg-muted rounded w-3/4" />
      <div className="h-4 bg-muted rounded w-1/2" />
      <div className="h-4 bg-muted rounded w-2/3" />
    </div>
  );
}

function DefaultErrorFallback({ error, onRetry }: { error: Error; onRetry: () => void }) {
  return (
    <div className="error-state" role="alert">
      <AlertCircleIcon className="text-destructive" />
      <h3>Something went wrong</h3>
      <p className="text-muted text-sm">{error.message}</p>
      <button onClick={onRetry}>Try again</button>
    </div>
  );
}
```

### Usage
```tsx
// Page-level boundary — wraps the whole async section
function InvoicePage() {
  return (
    <AsyncBoundary
      fallback={<InvoicePageSkeleton />}
      errorFallback={(error, reset) => (
        <PageError message="Failed to load invoices" onRetry={reset} />
      )}
    >
      <InvoiceList />  {/* async component */}
    </AsyncBoundary>
  );
}

// Component-level boundary — finer-grained
function Dashboard() {
  return (
    <div className="grid grid-cols-2 gap-4">
      <AsyncBoundary fallback={<StatCardSkeleton />}>
        <RevenueCard />
      </AsyncBoundary>
      <AsyncBoundary fallback={<StatCardSkeleton />}>
        <UserCountCard />
      </AsyncBoundary>
    </div>
  );
}

// Async component (throws a promise when loading — React Suspense protocol)
async function InvoiceList() {
  const invoices = await fetchInvoices(); // server component or use() hook
  return <table>...</table>;
}
```

### With React Query (client-side)
```tsx
function InvoiceListClient() {
  const { data, error, isLoading, refetch } = useInvoices();

  if (isLoading) return <InvoiceListSkeleton />;
  if (error) return <DefaultErrorFallback error={error} onRetry={refetch} />;
  return <InvoiceTable data={data} />;
}
// Note: for React Query, handle loading/error in the component;
// use AsyncBoundary for server components and Suspense-enabled queries
```

## Key Rules
- `AsyncBoundary` wraps both Suspense and ErrorBoundary in one composable unit
- Never render error or loading UI without both — a component missing either is incomplete
- `resetKey={pathname}` ensures the error boundary resets when the user navigates to a new route
- Provide a `retry` button in the error fallback — a dead end error screen with no recovery is hostile UX
- Include the error message in the fallback (in dev) — helps diagnose without opening DevTools
- Report errors to your error tracking service inside `componentDidCatch`
- Skeleton fallback should match the rough layout of the loaded content — prevents jarring layout shift
- Multiple small boundaries isolate failures — one broken widget shouldn't blank the whole page
- Never catch errors in `try/catch` inside render — throw them to propagate to the boundary
- Error boundary `role="alert"` for screen reader accessibility
