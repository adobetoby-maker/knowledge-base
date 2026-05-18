# Pattern: Address Form

## What This Solves

Address forms appear on checkout, client management, service order, and profile pages. The pattern: consistent field structure, US-state dropdown, ZIP validation, and Google Places autocomplete as an optional enhancement.

## Basic Address Form

```tsx
// components/AddressForm.tsx
import { useFormContext } from 'react-hook-form'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { US_STATES } from '@/lib/us-states'

interface AddressFormProps {
  prefix?: string   // For nested forms: 'billing.' 'shipping.' etc.
  required?: boolean
}

export function AddressForm({ prefix = '', required = false }: AddressFormProps) {
  const { register, formState: { errors }, control } = useFormContext()

  const field = (name: string) => `${prefix}${name}`
  const error = (name: string) => {
    const parts = `${prefix}${name}`.split('.')
    return parts.reduce((obj: unknown, key) => (obj as Record<string, unknown>)?.[key], errors) as { message?: string } | undefined
  }

  return (
    <div className="space-y-4">
      <div>
        <Label htmlFor={field('street1')}>Street address {required && '*'}</Label>
        <Input
          id={field('street1')}
          {...register(field('street1'), { required: required && 'Street address is required' })}
          placeholder="123 Main St"
          autoComplete="street-address"
        />
        {error('street1') && <p className="text-sm text-destructive mt-1">{error('street1')?.message}</p>}
      </div>

      <div>
        <Label htmlFor={field('street2')}>Apartment, suite, etc.</Label>
        <Input
          id={field('street2')}
          {...register(field('street2'))}
          placeholder="Apt 4B"
          autoComplete="address-line2"
        />
      </div>

      <div className="grid grid-cols-6 gap-3">
        <div className="col-span-3">
          <Label htmlFor={field('city')}>City {required && '*'}</Label>
          <Input
            id={field('city')}
            {...register(field('city'), { required: required && 'City is required' })}
            placeholder="Twin Falls"
            autoComplete="address-level2"
          />
          {error('city') && <p className="text-sm text-destructive mt-1">{error('city')?.message}</p>}
        </div>

        <div className="col-span-1">
          <Label htmlFor={field('state')}>State</Label>
          <Controller
            name={field('state')}
            control={control}
            rules={{ required: required && 'Required' }}
            render={({ field: f }) => (
              <Select value={f.value} onValueChange={f.onChange}>
                <SelectTrigger>
                  <SelectValue placeholder="ID" />
                </SelectTrigger>
                <SelectContent>
                  {US_STATES.map(s => (
                    <SelectItem key={s.value} value={s.value}>{s.value}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </div>

        <div className="col-span-2">
          <Label htmlFor={field('zip')}>ZIP {required && '*'}</Label>
          <Input
            id={field('zip')}
            {...register(field('zip'), {
              required: required && 'ZIP is required',
              pattern: { value: /^\d{5}(-\d{4})?$/, message: 'Invalid ZIP code' }
            })}
            placeholder="83301"
            maxLength={10}
            autoComplete="postal-code"
          />
          {error('zip') && <p className="text-sm text-destructive mt-1">{error('zip')?.message}</p>}
        </div>
      </div>
    </div>
  )
}
```

## US States Data

```ts
// lib/us-states.ts
export const US_STATES = [
  { value: 'AL', label: 'Alabama' },
  { value: 'AK', label: 'Alaska' },
  // ... all 50 states + DC
  { value: 'ID', label: 'Idaho' },
  // ... etc.
] as const
```

## Zod Schema

```ts
const AddressSchema = z.object({
  street1: z.string().min(1, 'Street address is required'),
  street2: z.string().optional(),
  city: z.string().min(1, 'City is required'),
  state: z.string().length(2, 'Select a state'),
  zip: z.string().regex(/^\d{5}(-\d{4})?$/, 'Invalid ZIP code'),
})

// For optional addresses:
const OptionalAddressSchema = z.object({
  street1: z.string(),
  street2: z.string().optional(),
  city: z.string(),
  state: z.string().optional(),
  zip: z.string().optional(),
}).optional()
```

## Database Storage

```sql
-- Option A: Inline columns (simple, hard to refactor)
ALTER TABLE clients ADD COLUMN address_street1 text;
ALTER TABLE clients ADD COLUMN address_city text;
ALTER TABLE clients ADD COLUMN address_state char(2);
ALTER TABLE clients ADD COLUMN address_zip text;

-- Option B: JSONB column (flexible, easy to query by parts)
ALTER TABLE clients ADD COLUMN address jsonb;
-- Query: WHERE address->>'state' = 'ID'

-- Option C: Separate address table (best for multiple addresses)
CREATE TABLE addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL,  -- 'client', 'order', etc.
  entity_id uuid NOT NULL,
  label text,                 -- 'billing', 'shipping', 'primary'
  street1 text,
  street2 text,
  city text,
  state char(2),
  zip text,
  country char(2) DEFAULT 'US',
  is_primary boolean DEFAULT false
);
```

## autocomplete Attributes

Always set `autocomplete` attributes — they enable browser autofill and are an accessibility requirement:

| Field | autocomplete value |
|-------|-------------------|
| Street line 1 | `street-address` |
| Street line 2 | `address-line2` |
| City | `address-level2` |
| State | `address-level1` |
| ZIP | `postal-code` |
| Country | `country` |
