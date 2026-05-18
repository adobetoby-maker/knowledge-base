# Skill: shadcn

**Trigger:** Adding UI components to a Next.js or React project. Need buttons, dialogs, forms, data tables, selects, toasts, navigation menus.
**Invoke:** `/shadcn`
**Returns:** How to add, configure, and customize shadcn/ui components correctly.

## When to Invoke
- Adding any reusable UI component
- Styling a form with validation states
- Building a data table with sorting/filtering
- Need a modal, sheet, drawer, or popover
- Customizing component variants/themes

## How shadcn/ui Works
shadcn/ui is NOT a package you import — it's a CLI that copies component source into `components/ui/`. You own the code; modify it freely.

```bash
# Add a component
npx shadcn@latest add button
npx shadcn@latest add dialog
npx shadcn@latest add form

# Add multiple
npx shadcn@latest add button card dialog form input label
```

Component goes to: `components/ui/button.tsx` — editable, not locked in node_modules.

## Components Most Used

### Button
```typescript
import { Button } from '@/components/ui/button'
<Button variant="default">Save</Button>
<Button variant="destructive">Delete</Button>
<Button variant="outline">Cancel</Button>
<Button variant="ghost">Learn More</Button>
<Button size="sm" | "lg" | "icon">...</Button>
```

### Dialog (Modal)
```typescript
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
<Dialog>
  <DialogTrigger asChild><Button>Open</Button></DialogTrigger>
  <DialogContent>
    <DialogHeader><DialogTitle>Title</DialogTitle></DialogHeader>
    Content here
  </DialogContent>
</Dialog>
```

### Form (React Hook Form + Zod)
shadcn form wraps react-hook-form. Always pair with zod schema.
```typescript
const form = useForm<z.infer<typeof schema>>({
  resolver: zodResolver(schema),
  defaultValues: { name: '' }
})
// Form.Field provides error messages automatically
```

### Toast
```typescript
import { useToast } from '@/components/ui/use-toast'
const { toast } = useToast()
toast({ title: 'Saved', description: 'Changes saved successfully' })
toast({ variant: 'destructive', title: 'Error', description: err.message })
```

## Theming
Colors controlled in `app/globals.css` via CSS custom properties:
```css
:root {
  --background: 0 0% 100%;
  --foreground: 222.2 84% 4.9%;
  --primary: 221.2 83.2% 53.3%;
}
```
Edit these values to change the whole theme. Don't edit component files for color changes.

## Customizing Variants
The `cn()` utility (wraps clsx + tailwind-merge) is used for conditional classes.
Add variants directly to the component file you own:
```typescript
const buttonVariants = cva(
  "inline-flex items-center...",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground",
        brand: "bg-blue-600 text-white hover:bg-blue-700"  // ADD HERE
      }
    }
  }
)
```

## What Skill Returns
Full component catalog, composition patterns, form validation examples, data table setup, theme customization guide.
