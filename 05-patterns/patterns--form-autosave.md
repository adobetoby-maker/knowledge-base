# Pattern: Form Autosave

## What This Solves

Long-form content (notes, proposals, profiles, blog posts) should save as the user types — losing a paragraph because the browser crashed or the session expired is a trust-destroying experience. The challenges are: not hammering the server on every keystroke, communicating save status clearly, blocking navigation on unsaved changes, and handling concurrent edits from multiple tabs.

## Debounced Save

Debounce at 1000ms minimum. Less than that creates network noise; more than 2000ms feels unreliable. The debounce resets on every change, so the save fires 1 second after the user pauses:

```tsx
import { useDebouncedCallback } from 'use-debounce'
import { useForm } from 'react-hook-form'

function NoteEditor({ noteId, initialContent }: Props) {
  const [saveStatus, setSaveStatus] = useState<'saved' | 'saving' | 'unsaved' | 'error'>('saved')
  const { register, watch, formState: { isDirty } } = useForm({
    defaultValues: { content: initialContent },
  })

  const debouncedSave = useDebouncedCallback(async (content: string) => {
    setSaveStatus('saving')
    try {
      await fetch(`/api/notes/${noteId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content }),
      })
      setSaveStatus('saved')
    } catch {
      setSaveStatus('error')
    }
  }, 1000)

  // Watch all form values and trigger autosave on change
  useEffect(() => {
    const sub = watch((values) => {
      setSaveStatus('unsaved')
      debouncedSave(values.content ?? '')
    })
    return () => sub.unsubscribe()
  }, [watch, debouncedSave])

  return (
    <div>
      <SaveIndicator status={saveStatus} />
      <textarea {...register('content')} />
    </div>
  )
}
```

## Save Indicator State Machine

The indicator has four states. Transitions must be strict — never jump from `saving` to `unsaved` unless the user types while a save is in flight:

```
idle → unsaved (user types)
unsaved → saving (debounce fires)
saving → saved (request succeeds)
saving → error (request fails)
error → unsaved (user types again)
saved → unsaved (user types again)
```

```tsx
function SaveIndicator({ status }: { status: 'saved' | 'saving' | 'unsaved' | 'error' }) {
  return (
    <div className="flex items-center gap-1.5 text-xs text-muted-foreground h-4">
      {status === 'saving' && (
        <><Spinner className="h-3 w-3" /> Saving…</>
      )}
      {status === 'saved' && (
        <><CheckIcon className="h-3 w-3 text-green-500" /> Saved</>
      )}
      {status === 'unsaved' && (
        <span className="text-amber-500">Unsaved changes</span>
      )}
      {status === 'error' && (
        <span className="text-destructive">Save failed — retrying…</span>
      )}
    </div>
  )
}
```

## Blocking Navigation on Unsaved Changes

In Next.js App Router, there's no built-in route change blocker. Use `beforeunload` for tab close and a custom solution for client-side navigation:

```tsx
// Block browser unload (tab close, hard refresh)
useEffect(() => {
  if (saveStatus !== 'unsaved' && saveStatus !== 'saving') return

  function handleBeforeUnload(e: BeforeUnloadEvent) {
    e.preventDefault()
  }

  window.addEventListener('beforeunload', handleBeforeUnload)
  return () => window.removeEventListener('beforeunload', handleBeforeUnload)
}, [saveStatus])
```

For in-app navigation, a confirmation dialog approach is more reliable than trying to intercept router events:

```tsx
// Wrap navigation links with a guard when unsaved
function NavLink({ href, children }: { href: string; children: ReactNode }) {
  const { saveStatus } = useFormStatus()
  const router = useRouter()

  function handleClick(e: React.MouseEvent) {
    if (saveStatus === 'unsaved' || saveStatus === 'saving') {
      e.preventDefault()
      const confirmed = confirm('You have unsaved changes. Leave anyway?')
      if (confirmed) router.push(href)
    }
  }

  return <a href={href} onClick={handleClick}>{children}</a>
}
```

For a better UX, flush the save synchronously before navigating rather than blocking:

```tsx
async function handleNavigation() {
  debouncedSave.flush() // fires immediately, cancels pending debounce
  await pendingSave     // await the in-flight request
  router.push(href)
}
```

## Server-Side Conflict Detection

Multiple browser tabs editing the same document will conflict. Use optimistic locking via `updated_at`:

```ts
// PATCH /api/notes/:id
const { content, clientUpdatedAt } = await req.json()

const note = await db.note.findUnique({ where: { id } })
if (note.updatedAt.getTime() !== new Date(clientUpdatedAt).getTime()) {
  return Response.json({ error: 'conflict', serverContent: note.content }, { status: 409 })
}

await db.note.update({ where: { id }, data: { content } })
```

On 409, present a diff or "Your version / Server version" merge UI rather than silently overwriting.

## Key Rules

- Debounce at 1000ms; never lower than 500ms in production
- Track save status as a 4-state machine — `saved/saving/unsaved/error` — and transition strictly
- Block `beforeunload` when `saveStatus` is `unsaved` or `saving`
- Call `debouncedSave.flush()` before programmatic navigation to save immediately rather than block
- Send `updated_at` with every PATCH; return 409 on conflict; never silently overwrite server state
- Show a non-intrusive indicator in a fixed position (top of editor or status bar area), not a toast that requires dismissal
