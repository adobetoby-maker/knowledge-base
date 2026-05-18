# Mobile First

## The Approach

Write CSS for mobile, then add overrides for larger screens. This is the foundation of Tailwind's responsive design system.

```typescript
// MOBILE FIRST (correct):
// Mobile: full-width, stacked
// Tablet (md): 2 columns
// Desktop (lg): 3 columns
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">

// DESKTOP FIRST (wrong in Tailwind):
// Don't do this — Tailwind breakpoints are min-width, not max-width
<div className="grid grid-cols-3 sm:grid-cols-2 xs:grid-cols-1">
// There is no xs: in Tailwind — this doesn't work as expected
```

Tailwind breakpoints are minimums: `md:` means "md and above". There's no "below md" — that's handled by the unprefixed class.

## Typography Scale

```typescript
// Mobile: 16px base, 28px headings
// Desktop: 16px base, 48px headings
<h1 className="text-2xl md:text-4xl lg:text-5xl font-bold">
  Auto Repair Twin Falls
</h1>

<p className="text-sm md:text-base leading-relaxed">
  Body text
</p>
```

Never go below 16px for body text — iOS zooms in on inputs with font-size < 16px.

## Spacing

Mobile needs less whitespace — there's less room to breathe:
```typescript
// Mobile: compact padding
// Desktop: generous padding
<section className="py-8 md:py-16 lg:py-24 px-4 md:px-8">

<div className="space-y-4 md:space-y-8">
```

## Navigation on Mobile

The hamburger menu pattern:
```typescript
// Desktop: horizontal nav bar visible
// Mobile: hamburger button + Sheet drawer

<nav>
  {/* Desktop nav */}
  <div className="hidden md:flex items-center gap-6">
    {links.map(link => <Link key={link.href} href={link.href}>{link.label}</Link>)}
  </div>
  
  {/* Mobile hamburger */}
  <Sheet>
    <SheetTrigger asChild className="md:hidden">
      <Button variant="ghost" size="icon">
        <Menu className="h-5 w-5" />
      </Button>
    </SheetTrigger>
    <SheetContent side="right">
      <nav className="flex flex-col gap-4 mt-8">
        {links.map(link => <Link key={link.href} href={link.href}>{link.label}</Link>)}
      </nav>
    </SheetContent>
  </Sheet>
</nav>
```

## Touch Targets

Minimum 44×44px touch target for any interactive element:

```typescript
// WRONG — 24×24px icon button is too small:
<Button variant="ghost" size="icon" className="h-6 w-6">
  <Edit className="h-4 w-4" />
</Button>

// CORRECT — 44×44px minimum:
<Button variant="ghost" size="icon" className="h-11 w-11">
  <Edit className="h-4 w-4" />
</Button>
```

shadcn's default `size="icon"` is 36px — increase to `h-11 w-11` (44px) for important actions.

## Forms on Mobile

- Large inputs: `h-12` instead of default `h-9`
- `type="tel"` for phone — opens numeric keyboard on iOS
- `type="email"` — opens email keyboard
- `inputMode="numeric"` for numeric fields
- `autocomplete` attributes reduce typing

```typescript
<Input
  type="tel"
  inputMode="numeric"
  autoComplete="tel"
  className="h-12 text-base"  // text-base prevents iOS zoom
  placeholder="(208) 555-0100"
/>
```

## Tables on Mobile

Data tables overflow horizontally on mobile. Wrap in a scroll container:

```typescript
<div className="overflow-x-auto rounded-md border">
  <Table>
    <TableHeader>...</TableHeader>
    <TableBody>...</TableBody>
  </Table>
</div>
```

For complex tables, consider a card list layout on mobile instead:
```typescript
{/* Card layout on mobile, table on desktop */}
<div className="md:hidden space-y-3">
  {invoices.map(inv => <InvoiceCard key={inv.id} invoice={inv} />)}
</div>
<div className="hidden md:block">
  <InvoiceTable invoices={invoices} />
</div>
```

## Images on Mobile

Fill the container width on mobile, fixed size on desktop:

```typescript
// Service card image
<div className="relative w-full h-48 sm:h-56 md:h-64">
  <Image
    src={image}
    alt={title}
    fill
    className="object-cover rounded-t-lg"
    sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
  />
</div>
```

## Viewport Meta Tag

Already in `app/layout.tsx` via Next.js defaults — don't override it:
```html
<!-- Next.js sets this automatically: -->
<meta name="viewport" content="width=device-width, initial-scale=1" />
```

Never add `user-scalable=no` — this breaks accessibility by preventing pinch-zoom.

## Testing

Test at 390px width (iPhone 14) and 375px (iPhone SE). The easiest way:
```bash
node ~/record.js 3000 --mobile  # 390×844 viewport
```

Check: navigation, forms, tables, image sizing, touch target sizes.
