# Pattern: Empty State with Contextual Call-to-Action

An empty state is not just "no data"—it has three distinct causes that require different messages and actions. Getting this right turns a dead end into a conversion opportunity or a helpful prompt.

## Why It Matters

Generic empty states ("No items found") are a failure. They don't explain why the list is empty or what to do next. A user who just signed up needs a "Create your first project" CTA. A user whose search returned nothing needs a "Clear search" link. A user without permission needs an explanation—not a button that leads nowhere.

## Three Empty State Types

### 1. No Data (First-Time / Blank State)

User has no items yet. This is an onboarding opportunity.

```tsx
function NoDataEmptyState({
  entityName,
  onCreateClick,
  onImportClick,
}: {
  entityName: string;
  onCreateClick: () => void;
  onImportClick?: () => void;
}) {
  return (
    <div className="empty-state" role="status">
      <div className="empty-state__icon" aria-hidden>
        <BoxIcon />
      </div>
      <h3 className="empty-state__title">No {entityName}s yet</h3>
      <p className="empty-state__body">
        Get started by creating your first {entityName.toLowerCase()}.
      </p>
      <div className="empty-state__actions">
        <button type="button" onClick={onCreateClick} className="btn-primary">
          Create {entityName}
        </button>
        {onImportClick && (
          <button type="button" onClick={onImportClick} className="btn-secondary">
            Import from CSV
          </button>
        )}
      </div>
    </div>
  );
}
```

The primary CTA is specific—"Create Invoice" not "Get Started". The secondary CTA (import) reduces the barrier for users migrating from another tool.

### 2. No Results (Search / Filter Applied)

The list is non-empty but the current filters return nothing. The problem is the filter state, not the data.

```tsx
function NoResultsEmptyState({
  query,
  activeFilterCount,
  onClearSearch,
  onClearFilters,
}: {
  query: string;
  activeFilterCount: number;
  onClearSearch: () => void;
  onClearFilters: () => void;
}) {
  return (
    <div className="empty-state" role="status" aria-live="polite">
      <div className="empty-state__icon" aria-hidden>
        <SearchXIcon />
      </div>
      <h3 className="empty-state__title">
        {query ? `No results for "${query}"` : 'No matching results'}
      </h3>
      <p className="empty-state__body">
        {activeFilterCount > 0
          ? `${activeFilterCount} filter${activeFilterCount > 1 ? 's' : ''} applied. Try adjusting them.`
          : 'Try a different search term.'}
      </p>
      <div className="empty-state__actions">
        {query && (
          <button type="button" onClick={onClearSearch} className="btn-secondary">
            Clear search
          </button>
        )}
        {activeFilterCount > 0 && (
          <button type="button" onClick={onClearFilters} className="btn-secondary">
            Clear all filters
          </button>
        )}
      </div>
    </div>
  );
}
```

`aria-live="polite"` announces the empty state to screen reader users when it appears after typing in a search field.

### 3. No Permission

The user has authenticated but lacks access to this resource. Don't show a create button—they can't use it.

```tsx
function NoPermissionEmptyState({
  resourceName,
  contactEmail,
}: {
  resourceName: string;
  contactEmail?: string;
}) {
  return (
    <div className="empty-state">
      <div className="empty-state__icon" aria-hidden>
        <LockIcon />
      </div>
      <h3 className="empty-state__title">No access to {resourceName}</h3>
      <p className="empty-state__body">
        You don't have permission to view this content.
        {contactEmail && ' Contact your administrator to request access.'}
      </p>
      {contactEmail && (
        <a href={`mailto:${contactEmail}`} className="btn-secondary">
          Request access
        </a>
      )}
    </div>
  );
}
```

Never show a "Create" button on a permission-empty state—it will fail and confuse the user.

## Routing to the Right Type

```tsx
function SmartEmptyState({ items, isSearching, hasPermission, ...handlers }) {
  if (!hasPermission) return <NoPermissionEmptyState {...handlers} />;
  if (isSearching || activeFilterCount > 0) return <NoResultsEmptyState {...handlers} />;
  return <NoDataEmptyState {...handlers} />;
}
```

Determine type server-side when possible—avoid a flash of the wrong empty state as permission data loads.

## Illustration vs Icon

- **First-time empty states**: use a friendly illustration or larger icon to set a welcoming tone.
- **No results**: use a search/filter icon—functional, not decorative.
- **No permission**: use a lock icon—clear, not alarming.

Keep illustrations simple (single-color SVG or Lottie). Complex illustrations slow load time and add visual noise.

## Import/Create Shortcuts

For first-time empty states in data-heavy contexts, provide both paths:

```tsx
<div className="empty-state__shortcuts">
  <button onClick={openCreateModal}>+ New manually</button>
  <label className="import-label">
    <input type="file" accept=".csv" onChange={handleImport} className="sr-only" />
    Import CSV
  </label>
  <button onClick={openTemplates}>Start from template</button>
</div>
```

## Key Rules

- **Three types, three messages**: blank state / no results / no permission—never conflate them.
- **Primary CTA is entity-specific**: "Create Invoice" not "Add Item".
- **No-results shows a clear action**: one-click "Clear search" or "Clear filters".
- **No-permission never shows a create button**—it will fail; frustration > no button.
- **`aria-live="polite"`** on no-results—announce to screen readers when results disappear.
- **Import shortcut** in blank states reduces migration friction.
- **Determine type server-side** when possible—avoid flicker between empty state variants.
