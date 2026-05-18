# Inline Edit

## When to Use

Inline edit = click a value to edit it in place, press Enter or click away to save. Use for:
- Quick single-field edits (renaming a record, updating a status note)
- Dense data views where opening a dialog would be disruptive
- Fields users edit frequently

Use a dialog form instead when:
- Multiple fields need to be edited together
- Validation is complex
- The edit is infrequent

## Simple Inline Edit

```typescript
function InlineEdit({
  value,
  onSave,
  placeholder = 'Click to edit',
}: {
  value: string
  onSave: (newValue: string) => Promise<void>
  placeholder?: string
}) {
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState(value)
  const [saving, setSaving] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)
  
  useEffect(() => {
    if (editing) inputRef.current?.focus()
  }, [editing])
  
  async function handleSave() {
    if (draft === value) { setEditing(false); return }
    setSaving(true)
    try {
      await onSave(draft)
      setEditing(false)
    } catch {
      toast.error('Failed to save')
      setDraft(value)  // rollback
    } finally {
      setSaving(false)
    }
  }
  
  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'Enter') handleSave()
    if (e.key === 'Escape') { setDraft(value); setEditing(false) }
  }
  
  if (editing) {
    return (
      <div className="flex items-center gap-1">
        <Input
          ref={inputRef}
          value={draft}
          onChange={e => setDraft(e.target.value)}
          onKeyDown={handleKeyDown}
          onBlur={handleSave}
          disabled={saving}
          className="h-7 py-0"
        />
        {saving && <Loader2 className="h-3 w-3 animate-spin" />}
      </div>
    )
  }
  
  return (
    <button
      onClick={() => setEditing(true)}
      className="text-left hover:bg-muted px-1 rounded group"
    >
      <span>{value || placeholder}</span>
      <Pencil className="inline-block h-3 w-3 ml-1 opacity-0 group-hover:opacity-50" />
    </button>
  )
}
```

## Usage

```typescript
function CustomerRow({ customer }: { customer: Customer }) {
  return (
    <TableRow>
      <TableCell>
        <InlineEdit
          value={customer.name}
          onSave={async (name) => {
            await supabase.from('customers').update({ name }).eq('id', customer.id)
          }}
        />
      </TableCell>
    </TableRow>
  )
}
```

## Inline Textarea

For multi-line content:

```typescript
function InlineTextarea({ value, onSave }: { value: string; onSave: (v: string) => Promise<void> }) {
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState(value)
  
  if (editing) {
    return (
      <Textarea
        value={draft}
        onChange={e => setDraft(e.target.value)}
        onBlur={async () => {
          if (draft !== value) await onSave(draft)
          setEditing(false)
        }}
        onKeyDown={e => {
          if (e.key === 'Escape') { setDraft(value); setEditing(false) }
          // Enter adds newline — no save-on-enter for textarea
          // Ctrl+Enter or Cmd+Enter to save:
          if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
            e.preventDefault()
            if (draft !== value) onSave(draft)
            setEditing(false)
          }
        }}
        autoFocus
        className="min-h-[80px]"
      />
    )
  }
  
  return (
    <p
      onClick={() => setEditing(true)}
      className="cursor-text hover:bg-muted p-1 rounded min-h-[40px] whitespace-pre-wrap text-sm"
    >
      {value || <span className="text-muted-foreground">Click to add notes...</span>}
    </p>
  )
}
```

## Optimistic Update Pattern

For list views, update the local state immediately and sync in background:

```typescript
const [customers, setCustomers] = useState(initialCustomers)

async function handleRename(customerId: string, newName: string) {
  // Optimistic:
  setCustomers(prev => prev.map(c => c.id === customerId ? { ...c, name: newName } : c))
  
  // Sync:
  const { error } = await supabase.from('customers').update({ name: newName }).eq('id', customerId)
  
  if (error) {
    // Rollback:
    setCustomers(initialCustomers)
    toast.error('Failed to rename')
  }
}
```
