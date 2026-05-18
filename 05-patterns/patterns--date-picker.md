# Date Picker

## Library Choice

Use `react-day-picker` (v8+) — it's what shadcn/ui's Calendar is built on. Don't use a heavyweight date library for just a picker. For date manipulation, use `date-fns`.

```bash
npm install react-day-picker date-fns
```

## Single Date (shadcn Calendar + Popover)

```typescript
import { useState } from 'react'
import { format } from 'date-fns'
import { CalendarIcon } from 'lucide-react'
import { Calendar } from '@/components/ui/calendar'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Button } from '@/components/ui/button'

interface DatePickerProps {
  value: Date | undefined
  onChange: (date: Date | undefined) => void
  placeholder?: string
}

export function DatePicker({ value, onChange, placeholder = 'Pick a date' }: DatePickerProps) {
  const [open, setOpen] = useState(false)
  
  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          className={cn('w-full justify-start text-left font-normal', !value && 'text-muted-foreground')}
        >
          <CalendarIcon className="mr-2 h-4 w-4" />
          {value ? format(value, 'PPP') : placeholder}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-auto p-0" align="start">
        <Calendar
          mode="single"
          selected={value}
          onSelect={(date) => {
            onChange(date)
            setOpen(false)
          }}
          initialFocus
        />
      </PopoverContent>
    </Popover>
  )
}
```

## Date Range Picker

```typescript
import { DateRange } from 'react-day-picker'

interface DateRangePickerProps {
  value: DateRange | undefined
  onChange: (range: DateRange | undefined) => void
}

export function DateRangePicker({ value, onChange }: DateRangePickerProps) {
  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button variant="outline" className="justify-start text-left font-normal">
          <CalendarIcon className="mr-2 h-4 w-4" />
          {value?.from ? (
            value.to
              ? `${format(value.from, 'LLL dd')} – ${format(value.to, 'LLL dd, y')}`
              : format(value.from, 'LLL dd, y')
          ) : 'Select date range'}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-auto p-0" align="start">
        <Calendar
          mode="range"
          selected={value}
          onSelect={onChange}
          numberOfMonths={2}
          initialFocus
        />
      </PopoverContent>
    </Popover>
  )
}
```

## React Hook Form Integration

```typescript
// Schema:
const schema = z.object({
  dueDate: z.date({ required_error: 'Due date is required' }),
  // For date range:
  period: z.object({
    from: z.date(),
    to: z.date(),
  }).optional(),
})

// Form field:
<FormField
  control={form.control}
  name="dueDate"
  render={({ field }) => (
    <FormItem className="flex flex-col">
      <FormLabel>Due Date</FormLabel>
      <DatePicker
        value={field.value}
        onChange={field.onChange}
      />
      <FormMessage />
    </FormItem>
  )}
/>
```

## Disabled Dates

```typescript
<Calendar
  mode="single"
  selected={value}
  onSelect={onChange}
  disabled={(date) =>
    date < new Date()          // no past dates
    || date.getDay() === 0     // no Sundays
    || date.getDay() === 6     // no Saturdays
  }
/>
```

## Storing Dates

Store as `timestamptz` in Postgres (always UTC). When the user picks a date without a time:
- Invoice due date: store as end of day in user's timezone to avoid off-by-one
- Appointment date: store with time component, apply timezone on read

```typescript
// Storing a picked date as end-of-day UTC:
import { endOfDay } from 'date-fns'
import { zonedTimeToUtc } from 'date-fns-tz'

const utcDate = zonedTimeToUtc(endOfDay(pickedDate), userTimezone)
```

## Locale-Aware Display

```typescript
import { format } from 'date-fns'
import { enUS } from 'date-fns/locale'

// Always specify locale for display — avoid ambiguous MM/DD vs DD/MM:
format(date, 'MMMM d, yyyy', { locale: enUS })  // "January 15, 2025"
format(date, 'PPP', { locale: enUS })            // "January 15th, 2025"
```
