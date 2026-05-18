# Plugin: clsx + tailwind-merge

## Overview

`clsx` conditionally builds className strings. `tailwind-merge` resolves Tailwind class conflicts (last class wins). Together they power the `cn()` utility used throughout component libraries.

## The `cn` Utility

```ts
// lib/utils.ts
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs))
}
```

This is the standard pattern in shadcn/ui and most modern Next.js starters. Install both:

```bash
npm install clsx tailwind-merge
```

## Why Both?

`clsx` alone joins class strings and handles conditionals, but doesn't resolve Tailwind conflicts:

```ts
clsx('px-4 py-2', 'px-6')  // → 'px-4 py-2 px-6'  (BROKEN — both px values apply, last wins in CSS)
```

`twMerge` alone merges correctly but is verbose for conditionals:

```ts
twMerge(condition ? 'bg-blue-500' : 'bg-red-500')  // Works but awkward
```

Together:

```ts
cn('px-4 py-2', 'px-6')  // → 'py-2 px-6'  (correctly drops px-4)
cn('bg-blue-500', isActive && 'bg-green-500')  // → 'bg-green-500' when active
```

## Usage Patterns

```tsx
// Basic conditional
<div className={cn('base-class', isActive && 'active-class', isDisabled && 'disabled-class')} />

// Variant-based component
interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'ghost'
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

const variants = {
  primary: 'bg-blue-600 text-white hover:bg-blue-700',
  secondary: 'bg-gray-100 text-gray-900 hover:bg-gray-200',
  ghost: 'hover:bg-gray-100 text-gray-700',
}

const sizes = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-sm',
  lg: 'px-6 py-3 text-base',
}

export function Button({ variant = 'primary', size = 'md', className, ...props }: ButtonProps) {
  return (
    <button
      className={cn(
        'rounded-lg font-medium transition-colors focus-visible:outline-none focus-visible:ring-2',
        variants[variant],
        sizes[size],
        className,  // Always last — consumer overrides take precedence
      )}
      {...props}
    />
  )
}
```

Always put the consumer `className` prop last in `cn()`. This ensures consumer classes override component defaults rather than being overridden by them.

## tailwind-merge Configuration

For custom Tailwind classes (e.g., custom spacing scale, `brand-*` colors), extend the twMerge config so conflicts are resolved correctly:

```ts
import { extendTailwindMerge } from 'tailwind-merge'

export const twMerge = extendTailwindMerge({
  extend: {
    classGroups: {
      'font-size': [{ text: ['brand-sm', 'brand-md', 'brand-lg'] }],
    },
  },
})
```

Without this, `text-brand-sm` and `text-brand-lg` would not be recognized as conflicting and both would be applied.

## class-variance-authority (CVA)

For components with many variants, `cva` from `class-variance-authority` replaces manual variant maps:

```ts
import { cva, type VariantProps } from 'class-variance-authority'

const buttonVariants = cva(
  'rounded-lg font-medium transition-colors focus-visible:outline-none focus-visible:ring-2',
  {
    variants: {
      variant: {
        primary: 'bg-blue-600 text-white hover:bg-blue-700',
        secondary: 'bg-gray-100 text-gray-900 hover:bg-gray-200',
        ghost: 'hover:bg-gray-100 text-gray-700',
      },
      size: {
        sm: 'px-3 py-1.5 text-sm',
        md: 'px-4 py-2 text-sm',
        lg: 'px-6 py-3 text-base',
      },
    },
    defaultVariants: {
      variant: 'primary',
      size: 'md',
    },
    compoundVariants: [
      // Combined variant rules
      { variant: 'primary', size: 'lg', className: 'shadow-md' },
    ],
  },
)

type ButtonProps = VariantProps<typeof buttonVariants> & {
  className?: string
}

export function Button({ variant, size, className, ...props }: ButtonProps) {
  return (
    <button className={cn(buttonVariants({ variant, size }), className)} {...props} />
  )
}
```

CVA is worth adding when a component has 3+ variants or compound variant rules. For simpler components, the manual map is clearer.
