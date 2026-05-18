# Pattern: Data Freshness Indicator

## Overview
Dashboards and data views can show stale data if the user leaves a tab open for hours. Without a freshness indicator, users make decisions on outdated information without realizing it. The indicator creates awareness of data age and provides a manual escape hatch. Color coding turns "stale" from a binary into a gradient that lets users judge urgency.

## Implementation

### Freshness Hook
```typescript
const STALE_THRESHOLD_YELLOW = 5 * 60 * 1000;  // 5 minutes
const STALE_THRESHOLD_RED = 15 * 60 * 1000;    // 15 minutes

type FreshnessStatus = 'fresh' | 'stale-warning' | 'stale-error';

function useFreshness(lastUpdatedAt: Date | null, autoRefreshMs?: number) {
  const [now, setNow] = useState(Date.now());
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Update "now" every 30s to keep relative time display accurate
  useEffect(() => {
    const interval = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(interval);
  }, []);

  // Auto-refresh countdown
  const [nextRefreshIn, setNextRefreshIn] = useState(autoRefreshMs ?? null);
  useEffect(() => {
    if (!autoRefreshMs) return;
    const countdown = setInterval(() => {
      setNextRefreshIn(prev => {
        if (prev !== null && prev <= 1000) return autoRefreshMs; // reset
        return prev !== null ? prev - 1000 : null;
      });
    }, 1000);
    return () => clearInterval(countdown);
  }, [autoRefreshMs]);

  const ageMs = lastUpdatedAt ? now - lastUpdatedAt.getTime() : null;

  const status: FreshnessStatus =
    ageMs === null ? 'fresh' :
    ageMs > STALE_THRESHOLD_RED ? 'stale-error' :
    ageMs > STALE_THRESHOLD_YELLOW ? 'stale-warning' :
    'fresh';

  return { ageMs, status, now, isRefreshing, setIsRefreshing, nextRefreshIn };
}
```

### Freshness Indicator Component
```tsx
interface FreshnessIndicatorProps {
  lastUpdatedAt: Date | null;
  onRefresh: () => Promise<void>;
  autoRefreshMs?: number; // e.g. 60_000 for 1-minute auto-refresh
}

function FreshnessIndicator({ lastUpdatedAt, onRefresh, autoRefreshMs }: FreshnessIndicatorProps) {
  const { ageMs, status, isRefreshing, setIsRefreshing, nextRefreshIn } = useFreshness(
    lastUpdatedAt,
    autoRefreshMs
  );

  const handleRefresh = async () => {
    if (isRefreshing) return;
    setIsRefreshing(true);
    try {
      await onRefresh();
    } finally {
      setIsRefreshing(false);
    }
  };

  // Auto-refresh trigger
  useEffect(() => {
    if (nextRefreshIn !== null && nextRefreshIn <= 0 && !isRefreshing) {
      handleRefresh();
    }
  }, [nextRefreshIn]);

  const statusColors = {
    fresh: 'text-muted',
    'stale-warning': 'text-yellow-600',
    'stale-error': 'text-red-600',
  };

  return (
    <div className={`freshness-indicator ${statusColors[status]}`}>
      <Tooltip
        content={
          lastUpdatedAt
            ? `Last updated: ${lastUpdatedAt.toLocaleString()}`
            : 'Not yet loaded'
        }
      >
        <span>
          {isRefreshing
            ? 'Updating...'
            : lastUpdatedAt
            ? `Updated ${formatRelative(lastUpdatedAt)}`
            : 'No data'}
        </span>
      </Tooltip>

      {autoRefreshMs && nextRefreshIn !== null && !isRefreshing && (
        <span className="text-muted text-xs">
          · auto-refresh in {Math.ceil(nextRefreshIn / 1000)}s
        </span>
      )}

      <button
        onClick={handleRefresh}
        disabled={isRefreshing}
        aria-label="Refresh data"
        className="refresh-btn"
      >
        <RefreshIcon className={isRefreshing ? 'animate-spin' : ''} />
      </button>
    </div>
  );
}
```

### Usage
```tsx
function RevenueDashboard() {
  const { data, refetch, dataUpdatedAt } = useQuery({
    queryKey: ['revenue'],
    queryFn: fetchRevenue,
    staleTime: 5 * 60 * 1000,
  });

  return (
    <div>
      <div className="dashboard-header">
        <h1>Revenue</h1>
        <FreshnessIndicator
          lastUpdatedAt={dataUpdatedAt ? new Date(dataUpdatedAt) : null}
          onRefresh={refetch}
          autoRefreshMs={60_000} // auto-refresh every minute
        />
      </div>
      <RevenueChart data={data} />
    </div>
  );
}
```

### CSS Status Colors
```css
.freshness-indicator {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 0.75rem;
}

/* Yellow: data is aging */
.freshness-indicator.text-yellow-600 { color: #ca8a04; }

/* Red: data is likely stale — user should refresh */
.freshness-indicator.text-red-600 { color: #dc2626; }

.refresh-btn { background: none; border: none; cursor: pointer; padding: 2px; }
.refresh-btn:disabled { opacity: 0.5; cursor: not-allowed; }
```

## Key Rules
- Show absolute timestamp on hover (tooltip) — relative time ("5 min ago") is ambiguous across time zones
- Yellow at 5 minutes, red at 15 minutes — thresholds depend on data volatility, but these are safe defaults
- Disable the refresh button while a refresh is in progress — prevent duplicate requests
- Animate the refresh icon (spin) during loading — provides visual feedback without blocking the UI
- Auto-refresh countdown is informational — show it, but don't make it the primary element
- Update relative time ("2 minutes ago") on a 30-second interval — don't let it freeze
- Place the indicator near the data it describes — top-right of a card, or sub-header of a section
- Stale threshold logic lives in the indicator — components consuming data don't need to know the thresholds
- If auto-refresh is enabled, don't reset it on manual refresh — restart the countdown from zero instead
- Never block the UI during refresh — data remains visible and interactive while refreshing
