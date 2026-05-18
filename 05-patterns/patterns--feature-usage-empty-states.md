# Pattern: Feature Usage Empty States

## Overview
A blank screen with "No items" is a dead end — users don't know what they're supposed to do or why the feature exists. A well-designed empty state is a first-use onboarding moment. The distinction between "never used" and "filtered to nothing" prevents user panic when a filter returns no results.

## Implementation

### Empty State Component
```tsx
interface EmptyStateProps {
  illustration: React.ReactNode;
  headline: string;         // benefit-focused, not "No X found"
  description: string;      // what this feature does and why it matters
  cta?: {
    label: string;
    onClick: () => void;
    variant?: 'primary' | 'secondary';
  };
}

function EmptyState({ illustration, headline, description, cta }: EmptyStateProps) {
  return (
    <div className="empty-state">
      <div className="illustration">{illustration}</div>
      <h3>{headline}</h3>
      <p className="text-muted">{description}</p>
      {cta && (
        <button
          className={`btn-${cta.variant ?? 'primary'}`}
          onClick={cta.onClick}
        >
          {cta.label}
        </button>
      )}
    </div>
  );
}
```

### Context-Aware Empty States
```tsx
function InvoiceList() {
  const { data, isLoading } = useInvoices(filters);

  // 1. Loading: show skeleton, not empty state
  if (isLoading) return <InvoiceListSkeleton />;

  const hasActiveFilters = filters.status || filters.dateFrom || filters.search;

  // 2. Never used (no data exists at all)
  if (data.length === 0 && !hasActiveFilters) {
    return (
      <EmptyState
        illustration={<InvoiceIllustration />}
        headline="Get paid faster with digital invoices"  // benefit, not "No invoices"
        description="Create your first invoice in under a minute. Track status, send reminders, and accept online payment."
        cta={{ label: 'Create your first invoice', onClick: openCreateInvoiceModal }}
      />
    );
  }

  // 3. Filtered to nothing (data exists, but filter returns nothing)
  if (data.length === 0 && hasActiveFilters) {
    return (
      <EmptyState
        illustration={<SearchIllustration />}
        headline="No invoices match your filters"   // explains the cause
        description={`Try adjusting your filters or search terms.`}
        cta={{ label: 'Clear all filters', onClick: clearFilters, variant: 'secondary' }}
      />
    );
  }

  return <InvoiceTable invoices={data} />;
}
```

### Single CTA Rule
```tsx
// WRONG — two CTAs dilute the action
<EmptyState
  cta1={{ label: 'Create invoice', onClick: create }}
  cta2={{ label: 'Import invoices', onClick: importFlow }}
/>

// RIGHT — one primary CTA; import is a secondary option elsewhere
<EmptyState
  cta={{ label: 'Create your first invoice', onClick: create }}
/>
// Import link lives in the page header, not the empty state
```

### Loading vs Empty Guard
```tsx
// WRONG — shows empty state flash before data loads
function TeamList() {
  const { data } = useTeams();
  if (!data || data.length === 0) return <EmptyState ... />;
  return <List items={data} />;
}

// RIGHT — explicit loading state
function TeamList() {
  const { data, isLoading } = useTeams();
  if (isLoading) return <Skeleton />;
  if (!data || data.length === 0) return <EmptyState ... />;
  return <List items={data} />;
}
```

### Illustration Guidelines
```tsx
// Use contextually relevant illustrations, not generic icons
const EMPTY_STATE_ILLUSTRATIONS = {
  invoices: <FileTextIllustration className="w-32 h-32 text-muted" />,
  team: <PeopleIllustration className="w-32 h-32 text-muted" />,
  search: <SearchIllustration className="w-32 h-32 text-muted" />,
  // Keep illustrations simple — decorative, not overwhelming
};
```

## Key Rules
- Never show an empty state while data is loading — show a skeleton instead
- Headline must describe the benefit of the feature, not describe the absence of data
- One CTA only — the single most important action the user should take right now
- "Never used" and "filtered to nothing" are different states with different messages and CTAs
- For "filtered to nothing": CTA clears filters, not "Create new item" — the user knows items exist
- Keep the empty state compact — illustration + headline + description + button, nothing more
- Illustration is decorative and contextual — not a generic empty box icon
- Description answers: what does this feature do, and why would I use it?
- CTA label is specific and action-oriented: "Create your first invoice", not "Get started"
- Empty states are an onboarding opportunity — write copy for a first-time user, not an admin
