# Empty State Pattern

## Why Empty States Matter

An empty state is not an absence of content — it's an opportunity to:
1. Tell the user why the page is empty
2. Guide them to the next action
3. Prevent confusion ("is this broken?")

Poor empty state: blank page or just "No items found."
Good empty state: explains what goes here + actionable path forward.

## The Three Empty State Types

### 1. No Data Yet (First-Time)

User hasn't created anything yet. Lead them to create.

```typescript
// components/EmptyInvoiceState.tsx
export function EmptyInvoiceState() {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="rounded-full bg-muted p-4 mb-4">
        <FileText className="h-8 w-8 text-muted-foreground" />
      </div>
      <h3 className="font-semibold text-lg mb-2">No invoices yet</h3>
      <p className="text-muted-foreground text-sm max-w-sm mb-6">
        Create your first invoice to start tracking payments from customers.
      </p>
      <Button asChild>
        <Link href="/admin/invoices/new">
          <Plus className="h-4 w-4 mr-2" />
          Create Invoice
        </Link>
      </Button>
    </div>
  )
}
```

### 2. No Results (Filtered/Searched)

User's filter returned nothing. Explain what was filtered and offer to clear.

```typescript
export function NoResultsState({
  query,
  onClear,
}: {
  query: string
  onClear: () => void
}) {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-center">
      <Search className="h-8 w-8 text-muted-foreground mb-4" />
      <h3 className="font-semibold mb-2">No results for "{query}"</h3>
      <p className="text-muted-foreground text-sm mb-4">
        Try different keywords or remove filters.
      </p>
      <Button variant="outline" onClick={onClear}>Clear search</Button>
    </div>
  )
}
```

### 3. Loading Failed

Data couldn't be loaded. Show what failed and offer retry.

```typescript
export function LoadErrorState({ onRetry }: { onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-center">
      <AlertCircle className="h-8 w-8 text-destructive mb-4" />
      <h3 className="font-semibold mb-2">Couldn't load invoices</h3>
      <p className="text-muted-foreground text-sm mb-4">
        Check your connection and try again.
      </p>
      <Button variant="outline" onClick={onRetry}>Try again</Button>
    </div>
  )
}
```

## Context-Aware Empty State

Differentiate between empty-because-filtered and empty-because-new:

```typescript
function InvoiceList({ invoices, hasFilters }: {
  invoices: Invoice[]
  hasFilters: boolean
}) {
  if (invoices.length === 0) {
    return hasFilters ? (
      <NoResultsState
        query="your filters"
        onClear={() => router.push('/admin/invoices')}
      />
    ) : (
      <EmptyInvoiceState />
    )
  }
  
  return <DataTable data={invoices} columns={columns} />
}
```

## Generic Empty State Component

For tables that don't warrant a custom empty state:

```typescript
// components/ui/empty-state.tsx
interface EmptyStateProps {
  icon?: LucideIcon
  title: string
  description?: string
  action?: {
    label: string
    href?: string
    onClick?: () => void
  }
}

export function EmptyState({ icon: Icon = Inbox, title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-center px-4">
      <div className="rounded-full bg-muted p-3 mb-3">
        <Icon className="h-6 w-6 text-muted-foreground" />
      </div>
      <p className="font-medium">{title}</p>
      {description && (
        <p className="text-sm text-muted-foreground mt-1 max-w-xs">{description}</p>
      )}
      {action && (
        <div className="mt-4">
          {action.href ? (
            <Button asChild size="sm">
              <Link href={action.href}>{action.label}</Link>
            </Button>
          ) : (
            <Button size="sm" onClick={action.onClick}>{action.label}</Button>
          )}
        </div>
      )}
    </div>
  )
}

// Usage:
<EmptyState
  icon={Receipt}
  title="No invoices found"
  description="Invoices you create will appear here."
  action={{ label: 'Create Invoice', href: '/admin/invoices/new' }}
/>
```

## In Table Rows

For inline empty state within a Table component:

```typescript
{table.getRowModel().rows.length === 0 && (
  <TableRow>
    <TableCell
      colSpan={columns.length}
      className="h-32 text-center text-muted-foreground"
    >
      {isFiltered ? 'No results match your filters.' : 'No data yet.'}
    </TableCell>
  </TableRow>
)}
```
