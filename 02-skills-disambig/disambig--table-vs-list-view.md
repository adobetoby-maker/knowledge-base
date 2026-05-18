# Disambig: Table vs List View for Data

## The Question

Data should be displayed — as a table (rows and columns) or as a card list?

## Decision Guide

**Use a table when:**
- Data has 4+ attributes that users need to scan and compare side-by-side
- Users need to sort by multiple columns
- The data is primarily textual (names, statuses, numbers, dates)
- Users perform batch operations (select multiple, bulk delete/export)
- Screen space is desktop-first (mobile gets a simplified view)

**Use a card list when:**
- Each item has a primary visual element (image, icon, avatar)
- Items have very different or complex layouts (varying content)
- Users navigate TO each item rather than scan across them
- Mobile is the primary viewport
- Content is content-like (blog posts, products, profiles)

## Side-by-Side Comparison

| Pattern | Table | Card List |
|---------|-------|-----------|
| Invoice list | ✓ Numbers, dates, amounts, status | |
| Blog articles | | ✓ Thumbnails, excerpts, varied layout |
| Client directory | Either — depends on if searching or browsing | |
| Product catalog | | ✓ Images, prices, CTAs |
| Admin user list | ✓ Sortable by name, role, date | |
| Service offerings | | ✓ Icon, description, CTA per service |

## Table Pattern

```tsx
// Use @tanstack/react-table for sortable, filterable tables
import { DataTable } from '@/components/ui/data-table'
import { columns } from './columns'

<DataTable
  data={invoices}
  columns={columns}
  onRowClick={(invoice) => router.push(`/invoices/${invoice.id}`)}
/>
```

Table columns (`columns.tsx`):
```tsx
export const columns: ColumnDef<Invoice>[] = [
  { id: 'select', ... },  // Checkbox column for bulk selection
  { accessorKey: 'number', header: 'Invoice' },
  { accessorKey: 'client_name', header: 'Client', enableSorting: true },
  { accessorKey: 'total_cents', header: 'Amount', cell: ({ row }) => formatCurrency(row.original.total_cents) },
  { accessorKey: 'status', header: 'Status', cell: ({ row }) => <StatusBadge status={row.original.status} /> },
  { id: 'actions', cell: ({ row }) => <RowActions invoice={row.original} /> },
]
```

## Card List Pattern

```tsx
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
  {services.map(service => (
    <Card key={service.id}>
      <CardHeader>
        <service.icon className="h-8 w-8 text-primary" />
        <CardTitle>{service.name}</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-sm text-muted-foreground">{service.description}</p>
      </CardContent>
      <CardFooter>
        <Button asChild className="w-full">
          <Link href={`/services/${service.slug}`}>Learn more</Link>
        </Button>
      </CardFooter>
    </Card>
  ))}
</div>
```

## Responsive Strategy

Often the right answer is: table on desktop, simplified card list on mobile.

```tsx
// Show table on md+, simplified list on mobile
<div className="hidden md:block">
  <DataTable data={invoices} columns={columns} />
</div>
<div className="block md:hidden space-y-3">
  {invoices.map(invoice => (
    <InvoiceListItem key={invoice.id} invoice={invoice} />
  ))}
</div>
```

The `InvoiceListItem` card shows the most important 3–4 fields only, with a tap-to-expand or tap-to-navigate pattern.

## Mixed Approach: List with Inline Data

For items with 2–3 key data points:

```tsx
// List item with inline columns — not a full table but scannable
{invoices.map(invoice => (
  <div key={invoice.id} className="flex items-center px-4 py-3 border-b hover:bg-muted/50">
    <div className="flex-1 min-w-0">
      <p className="font-medium truncate">{invoice.client_name}</p>
      <p className="text-sm text-muted-foreground">#{invoice.number}</p>
    </div>
    <div className="ml-4 text-right">
      <p className="font-medium">{formatCurrency(invoice.total_cents)}</p>
      <StatusBadge status={invoice.status} />
    </div>
  </div>
))}
```

This hybrid works well for mobile and for simpler desktop views where a full table is overkill.
