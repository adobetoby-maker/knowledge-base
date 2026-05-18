# Pattern: Page Header with Actions

## Overview
The page header is the most-viewed element on any interior page — it establishes context (where am I?), communicates state (draft, published, archived), and provides the primary actions for the page. A poorly structured header forces users to hunt for actions, misidentifies the primary action, and collapses badly on mobile. Standardizing the header across all pages reduces cognitive load: users develop muscle memory for where actions live.

## Implementation

### Base Structure
```tsx
interface PageHeaderProps {
  title: string;
  subtitle?: string;
  status?: React.ReactNode;        // badge, tag
  primaryAction?: {
    label: string;
    onClick: () => void;
    loading?: boolean;
    disabled?: boolean;
  };
  secondaryActions?: {
    label: string;
    onClick: () => void;
    variant?: 'default' | 'destructive';
  }[];
  overflowActions?: {              // appear in "..." menu on mobile
    label: string;
    onClick: () => void;
    variant?: 'default' | 'destructive';
  }[];
  sticky?: boolean;
}

function PageHeader({
  title,
  subtitle,
  status,
  primaryAction,
  secondaryActions = [],
  overflowActions = [],
  sticky = false,
}: PageHeaderProps) {
  const [overflowOpen, setOverflowOpen] = useState(false);
  const isMobile = useMediaQuery('(max-width: 640px)');

  return (
    <header
      style={{
        display: 'flex',
        alignItems: 'flex-start',
        justifyContent: 'space-between',
        gap: 16,
        padding: '24px 0 16px',
        position: sticky ? 'sticky' : undefined,
        top: sticky ? 0 : undefined,
        background: sticky ? '#fff' : undefined,
        zIndex: sticky ? 10 : undefined,
        borderBottom: sticky ? '1px solid #e5e7eb' : undefined,
        // Stack on mobile
        flexDirection: isMobile ? 'column' : 'row',
      }}
    >
      {/* Left: title + subtitle + status */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <h1 style={{ fontSize: 20, fontWeight: 700, margin: 0 }}>{title}</h1>
          {status}
        </div>
        {subtitle && (
          <p style={{ fontSize: 14, color: '#6b7280', margin: 0 }}>{subtitle}</p>
        )}
      </div>

      {/* Right: actions */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        flexShrink: 0,
        width: isMobile ? '100%' : undefined,
      }}>
        {/* Secondary actions — hidden on mobile, moved to overflow */}
        {!isMobile && secondaryActions.map((action, i) => (
          <button
            key={i}
            onClick={action.onClick}
            style={{ color: action.variant === 'destructive' ? '#ef4444' : undefined }}
          >
            {action.label}
          </button>
        ))}

        {/* Overflow menu (mobile: all secondary; desktop: overflow only) */}
        {(isMobile
          ? [...secondaryActions, ...overflowActions]
          : overflowActions
        ).length > 0 && (
          <div style={{ position: 'relative' }}>
            <button
              onClick={() => setOverflowOpen(o => !o)}
              aria-label="More actions"
              aria-haspopup="menu"
              aria-expanded={overflowOpen}
            >
              •••
            </button>
            {overflowOpen && (
              <DropdownMenu
                items={isMobile ? [...secondaryActions, ...overflowActions] : overflowActions}
                onClose={() => setOverflowOpen(false)}
              />
            )}
          </div>
        )}

        {/* Primary action — always visible, prominent */}
        {primaryAction && (
          <button
            onClick={primaryAction.onClick}
            disabled={primaryAction.disabled || primaryAction.loading}
            style={{
              flex: isMobile ? 1 : undefined, // full width on mobile
              fontWeight: 600,
            }}
          >
            {primaryAction.loading ? 'Saving...' : primaryAction.label}
          </button>
        )}
      </div>
    </header>
  );
}
```

### Sticky Behavior
Sticky headers work best on long content pages (settings, edit forms with many fields). For short pages or dashboards, non-sticky is cleaner. When sticky:
- Add a bottom border — creates visual separation from scrolled-past content.
- Use `backdrop-filter: blur(8px)` + semi-transparent background for depth without hard edge.
- The sticky header counts against viewport height — keep it compact (no subtitle when sticky).

### Status Badges
```tsx
const STATUS_STYLES = {
  draft:     { background: '#f3f4f6', color: '#374151' },
  active:    { background: '#d1fae5', color: '#065f46' },
  archived:  { background: '#f3f4f6', color: '#9ca3af' },
  error:     { background: '#fee2e2', color: '#991b1b' },
};

function StatusBadge({ status }: { status: string }) {
  const style = STATUS_STYLES[status] ?? STATUS_STYLES.draft;
  return (
    <span style={{ ...style, padding: '2px 8px', borderRadius: 9999, fontSize: 12, fontWeight: 500 }}>
      {status}
    </span>
  );
}
```

## Key Rules
- One primary action per page header — if there are two equally important actions, reconsider the page's purpose.
- Primary action always appears rightmost and uses a filled/prominent button style.
- Secondary actions (2–3 maximum) appear to the left of the primary action on desktop.
- On mobile, secondary actions move to the overflow menu — primary action spans full width.
- The `<h1>` must match the page `<title>` — search engines and screen readers use both.
- Sticky headers must account for iOS Safari's dynamic toolbar — `position: sticky; top: env(safe-area-inset-top)`.
- Destructive actions (delete, archive) belong in the overflow menu, never in the primary position.
