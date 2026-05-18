# Pattern: Tag Input

## What This Solves

Tag inputs (comma-separated keywords, multi-select chips) need: adding by pressing Enter or comma, removing by clicking X or pressing Backspace on empty input, visual chips, and form integration. React Hook Form integration is the tricky part — tags are a string[] but the native input is a text field.

## Component

```tsx
// components/TagInput.tsx
'use client'
import { useState, useRef, KeyboardEvent } from 'react'
import { X } from 'lucide-react'
import { cn } from '@/lib/utils'

interface TagInputProps {
  value: string[]
  onChange: (tags: string[]) => void
  placeholder?: string
  maxTags?: number
  className?: string
}

export function TagInput({
  value,
  onChange,
  placeholder = 'Add a tag...',
  maxTags = 20,
  className,
}: TagInputProps) {
  const [inputValue, setInputValue] = useState('')
  const inputRef = useRef<HTMLInputElement>(null)

  const addTag = (raw: string) => {
    const tag = raw.trim().toLowerCase()
    if (!tag) return
    if (value.includes(tag)) return
    if (value.length >= maxTags) return
    onChange([...value, tag])
  }

  const removeTag = (index: number) => {
    onChange(value.filter((_, i) => i !== index))
  }

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' || e.key === ',') {
      e.preventDefault()
      addTag(inputValue)
      setInputValue('')
      return
    }
    if (e.key === 'Backspace' && inputValue === '' && value.length > 0) {
      removeTag(value.length - 1)
    }
  }

  const handleBlur = () => {
    if (inputValue.trim()) {
      addTag(inputValue)
      setInputValue('')
    }
  }

  return (
    <div
      className={cn(
        'flex flex-wrap gap-1.5 min-h-10 w-full rounded-md border border-input bg-background px-3 py-2 cursor-text',
        className
      )}
      onClick={() => inputRef.current?.focus()}
    >
      {value.map((tag, i) => (
        <span
          key={tag}
          className="inline-flex items-center gap-1 bg-secondary text-secondary-foreground rounded-sm px-2 py-0.5 text-sm"
        >
          {tag}
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); removeTag(i) }}
            className="hover:text-destructive transition-colors"
          >
            <X className="h-3 w-3" />
          </button>
        </span>
      ))}
      <input
        ref={inputRef}
        value={inputValue}
        onChange={e => setInputValue(e.target.value)}
        onKeyDown={handleKeyDown}
        onBlur={handleBlur}
        placeholder={value.length === 0 ? placeholder : ''}
        className="flex-1 min-w-24 bg-transparent outline-none text-sm placeholder:text-muted-foreground"
        disabled={value.length >= maxTags}
      />
    </div>
  )
}
```

## React Hook Form Integration

```tsx
import { useForm, Controller } from 'react-hook-form'
import { z } from 'zod'
import { zodResolver } from '@hookform/resolvers/zod'

const schema = z.object({
  title: z.string().min(1),
  tags: z.array(z.string()).min(1, 'Add at least one tag').max(20),
})

type FormValues = z.infer<typeof schema>

function ArticleForm() {
  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { title: '', tags: [] },
  })

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <Controller
        control={form.control}
        name="tags"
        render={({ field, fieldState }) => (
          <div>
            <TagInput
              value={field.value}
              onChange={field.onChange}
              placeholder="Add keywords..."
            />
            {fieldState.error && (
              <p className="text-sm text-destructive mt-1">{fieldState.error.message}</p>
            )}
          </div>
        )}
      />
    </form>
  )
}
```

## Database Storage

Two options:

**Option A — Postgres array column:**
```sql
ALTER TABLE articles ADD COLUMN tags text[] NOT NULL DEFAULT '{}';
CREATE INDEX articles_tags_gin ON articles USING GIN(tags);
```
Query: `.contains('tags', ['nextjs', 'react'])` in Supabase.

**Option B — Junction table** (when tags have their own metadata):
```sql
CREATE TABLE tags (id uuid PRIMARY KEY, name text UNIQUE NOT NULL);
CREATE TABLE article_tags (article_id uuid REFERENCES articles, tag_id uuid REFERENCES tags, PRIMARY KEY (article_id, tag_id));
```

Use Option A for simple keyword arrays. Use Option B when tags need descriptions, colors, or counts.

## Normalization

Always normalize before storing: trim whitespace, lowercase, remove special characters:
```ts
const normalizeTag = (raw: string) =>
  raw.trim().toLowerCase().replace(/[^a-z0-9-]/g, '-').replace(/-+/g, '-').slice(0, 50)
```

## Autocomplete Variant

Add a dropdown of existing tags below the input:
```tsx
const [suggestions, setSuggestions] = useState<string[]>([])

useEffect(() => {
  if (inputValue.length < 2) { setSuggestions([]); return }
  supabase.rpc('search_tags', { q: inputValue }).then(({ data }) => {
    setSuggestions(data?.map(t => t.name) ?? [])
  })
}, [inputValue])
```

Render suggestions as a popover anchored to the input. Clicking a suggestion calls `addTag()` and clears the input.
