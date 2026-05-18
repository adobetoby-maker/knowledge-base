# Pattern: Typing Indicator

## Overview

Show "Alice is typing…" in chat interfaces. Three dots animating is the convention (iOS-style bubble). The critical issue is debouncing the send — emit "started typing" on keydown, emit "stopped typing" after 2-3 seconds of silence, and clean up on component unmount.

## Core Component

```tsx
interface TypingIndicatorProps {
  names: string[]  // users currently typing
}

export function TypingIndicator({ names }: TypingIndicatorProps) {
  if (names.length === 0) return null

  const label =
    names.length === 1
      ? `${names[0]} is typing`
      : names.length === 2
      ? `${names[0]} and ${names[1]} are typing`
      : `${names[0]} and ${names.length - 1} others are typing`

  return (
    <div className="flex items-center gap-2 text-sm text-gray-500 px-4 py-1">
      <span className="flex gap-0.5">
        <span className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce [animation-delay:0ms]" />
        <span className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce [animation-delay:150ms]" />
        <span className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce [animation-delay:300ms]" />
      </span>
      <span>{label}</span>
    </div>
  )
}
```

Tailwind animation for staggered dots in `tailwind.config.ts`:

```ts
// Already in Tailwind — just need delay utilities
// Add to globals.css if using CSS:
@keyframes bounce {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-4px); }
}
```

## Sending Typing Events (Supabase Realtime)

```tsx
function ChatInput({ roomId, userId }: { roomId: string; userId: string }) {
  const [value, setValue] = useState('')
  const channelRef = useRef<RealtimeChannel | null>(null)
  const stopTimeoutRef = useRef<ReturnType<typeof setTimeout>>()

  useEffect(() => {
    channelRef.current = supabase.channel(`room:${roomId}`)
    channelRef.current.subscribe()
    return () => {
      channelRef.current?.unsubscribe()
    }
  }, [roomId])

  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setValue(e.target.value)
    sendTypingEvent('started')
    clearTimeout(stopTimeoutRef.current)
    stopTimeoutRef.current = setTimeout(() => sendTypingEvent('stopped'), 2500)
  }

  const sendTypingEvent = (status: 'started' | 'stopped') => {
    channelRef.current?.send({
      type: 'broadcast',
      event: 'typing',
      payload: { userId, status },
    })
  }

  const handleSubmit = () => {
    clearTimeout(stopTimeoutRef.current)
    sendTypingEvent('stopped')
    // send message...
    setValue('')
  }

  useEffect(() => () => clearTimeout(stopTimeoutRef.current), [])

  return <textarea value={value} onChange={handleChange} onKeyDown={e => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSubmit() }
  }} />
}
```

## Receiving Typing Events

```tsx
function useTypingUsers(roomId: string, currentUserId: string) {
  const [typingUsers, setTypingUsers] = useState<Map<string, string>>(new Map())
  const timeoutsRef = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map())

  useEffect(() => {
    const channel = supabase.channel(`room:${roomId}`)
      .on('broadcast', { event: 'typing' }, ({ payload }) => {
        const { userId, status, displayName } = payload

        if (userId === currentUserId) return  // Don't show own indicator

        if (status === 'stopped') {
          setTypingUsers(prev => {
            const next = new Map(prev)
            next.delete(userId)
            return next
          })
          clearTimeout(timeoutsRef.current.get(userId))
          timeoutsRef.current.delete(userId)
          return
        }

        setTypingUsers(prev => new Map(prev).set(userId, displayName ?? userId))

        // Auto-remove if we miss the 'stopped' event (e.g., tab closed)
        clearTimeout(timeoutsRef.current.get(userId))
        timeoutsRef.current.set(userId, setTimeout(() => {
          setTypingUsers(prev => {
            const next = new Map(prev)
            next.delete(userId)
            return next
          })
        }, 4000))
      })
      .subscribe()

    return () => {
      channel.unsubscribe()
      timeoutsRef.current.forEach(clearTimeout)
    }
  }, [roomId, currentUserId])

  return Array.from(typingUsers.values())
}
```

## Key Rules

- Auto-remove typing state after 4s — browsers closing don't send "stopped" events.
- Filter out the current user's own typing events — never show "you are typing" to yourself.
- Throttle the "started typing" broadcast — once per 2s is plenty, not on every keystroke.
- Place the indicator below the message list, above the input box — standard chat convention.
- Keep indicator height reserved even when empty (`min-h-[24px]`) to prevent layout shift when it appears.
