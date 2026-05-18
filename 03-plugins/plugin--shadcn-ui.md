# Plugin: shadcn/ui

## What It Is

shadcn/ui is not a traditional npm package — it's a CLI that copies component source code directly into your project. You own the components. They're not updated via npm upgrade; they're updated by re-running the CLI.

This means: you can modify the components freely, but you must manually manage updates.

## Installation and Adding Components

```bash
# Add a component (copies source into components/ui/)
npx shadcn@latest add button
npx shadcn@latest add dialog
npx shadcn@latest add form
npx shadcn@latest add table
npx shadcn@latest add select
npx shadcn@latest add tabs
npx shadcn@latest add card
npx shadcn@latest add input
npx shadcn@latest add badge
npx shadcn@latest add toast

# List all available components
npx shadcn@latest list
```

## Configuration: components.json

```json
{
  "style": "default",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "app/globals.css",
    "baseColor": "neutral",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils"
  }
}
```

`cssVariables: true` means shadcn uses CSS custom properties for theming. Changing colors is done in `globals.css`, not in `tailwind.config.ts`.

## Theme Customization

```css
/* app/globals.css */
:root {
  --background: 0 0% 100%;
  --foreground: 222.2 84% 4.9%;
  --primary: 222.2 47.4% 11.2%;
  --primary-foreground: 210 40% 98%;
  --secondary: 210 40% 96.1%;
  --secondary-foreground: 222.2 47.4% 11.2%;
  /* ... all CSS custom properties */
}

.dark {
  --background: 222.2 84% 4.9%;
  /* ... dark mode overrides */
}
```

Colors are HSL values without the `hsl()` wrapper (Tailwind adds it).

## Form Composition with react-hook-form

shadcn Form is built on react-hook-form + Zod:

```typescript
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form'

const schema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
})

export function ContactForm() {
  const form = useForm<z.infer<typeof schema>>({
    resolver: zodResolver(schema),
    defaultValues: { name: '', email: '' },
  })
  
  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Name</FormLabel>
              <FormControl>
                <Input {...field} />
              </FormControl>
              <FormMessage />  {/* shows validation error */}
            </FormItem>
          )}
        />
      </form>
    </Form>
  )
}
```

## Data Table Pattern

```typescript
import { DataTable } from '@/components/ui/data-table'
import { ColumnDef } from '@tanstack/react-table'

const columns: ColumnDef<Invoice>[] = [
  {
    accessorKey: 'id',
    header: 'Invoice #',
  },
  {
    accessorKey: 'amount',
    header: 'Amount',
    cell: ({ row }) => `$${row.original.amount.toFixed(2)}`,
  },
  {
    id: 'actions',
    cell: ({ row }) => (
      <DropdownMenu>...</DropdownMenu>
    ),
  },
]

<DataTable columns={columns} data={invoices} />
```

DataTable requires `@tanstack/react-table` — install separately.

## Toast Notifications

```typescript
import { useToast } from '@/hooks/use-toast'

const { toast } = useToast()

// Success
toast({ title: 'Saved', description: 'Invoice created successfully.' })

// Error
toast({ title: 'Error', description: error.message, variant: 'destructive' })
```

The `Toaster` component must be in the root layout for toasts to appear.

## Dialog Pattern

```typescript
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'

<Dialog>
  <DialogTrigger asChild>
    <Button>Open</Button>
  </DialogTrigger>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Edit Invoice</DialogTitle>
    </DialogHeader>
    <InvoiceForm />
  </DialogContent>
</Dialog>
```

## Important: cn() Utility

shadcn requires the `cn()` utility function in `lib/utils.ts`:

```typescript
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

This merges Tailwind classes correctly (handles conflicts). Always use `cn()` when merging Tailwind classes.
