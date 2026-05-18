# Pattern: Presence Indicators

## Overview

Show who is currently viewing or editing a page — like "3 people are viewing this document." Uses Supabase Realtime broadcast channels for zero-database overhead.

## Why Broadcast, Not Database

Don't store presence in a database table. Presence is ephemeral — it should vanish when the user leaves. Database rows require cleanup jobs, have latency from writes, and create unnecessary load.

Supabase Realtime broadcast channels handle this without touching the database: the presence state lives in memory on the Realtime server and is automatically cleaned up when a client disconnects.

## Core Hook

```ts
'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'

interface PresenceUser {
  userId: string
  name: string
  avatar?: string
  color: string
  cursor?: { x: number; y: number }
}

const COLORS = ['#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899']

export function usePresence(roomId: string, currentUser: { id: string; name: string; avatar?: string }) {
  const [others, setOthers] = useState<PresenceUser[]>([])
  const supabase = createClient()

  useEffect(() => {
    const color = COLORS[Math.floor(Math.random() * COLORS.length)]

    const channel = supabase.channel(`presence:${roomId}`, {
      config: { presence: { key: currentUser.id } },
    })

    channel
      .on('presence', { event: 'sync' }, () => {
        const state = channel.presenceState<PresenceUser>()
        const presenceList = Object.values(state)
          .flat()
          .filter((u) => u.userId !== currentUser.id)
        setOthers(presenceList)
      })
      .on('presence', { event: 'join' }, ({ newPresences }) => {
        setOthers((prev) => [
          ...prev.filter((u) => !newPresences.some((n) => n.userId === u.userId)),
          ...newPresences.filter((n) => n.userId !== currentUser.id),
        ])
      })
      .on('presence', { event: 'leave' }, ({ leftPresences }) => {
        setOthers((prev) => prev.filter((u) => !leftPresences.some((l) => l.userId === u.userId)))
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await channel.track({
            userId: currentUser.id,
            name: currentUser.name,
            avatar: currentUser.avatar,
            color,
          } satisfies PresenceUser)
        }
      })

    return () => {
      channel.untrack()
      supabase.removeChannel(channel)
    }
  }, [roomId, currentUser.id, currentUser.name])

  return others
}
```

## Presence Avatars Component

```tsx
export function PresenceAvatars({ roomId, currentUser }: PresenceProps) {
  const others = usePresence(roomId, currentUser)

  if (others.length === 0) return null

  const visible = others.slice(0, 4)
  const overflow = others.length - 4

  return (
    <div className="flex items-center -space-x-2">
      {visible.map((user) => (
        <div
          key={user.userId}
          title={`${user.name} is viewing`}
          className="relative"
          style={{ zIndex: visible.indexOf(user) + 1 }}
        >
          {user.avatar ? (
            <img
              src={user.avatar}
              alt={user.name}
              className="w-8 h-8 rounded-full border-2 border-white"
            />
          ) : (
            <div
              className="w-8 h-8 rounded-full border-2 border-white flex items-center justify-center text-white text-xs font-medium"
              style={{ backgroundColor: user.color }}
            >
              {user.name[0].toUpperCase()}
            </div>
          )}
          <span
            className="absolute bottom-0 right-0 w-2.5 h-2.5 rounded-full border border-white"
            style={{ backgroundColor: '#10B981' }}
          />
        </div>
      ))}
      {overflow > 0 && (
        <div className="w-8 h-8 rounded-full border-2 border-white bg-gray-200 flex items-center justify-center text-xs font-medium text-gray-600">
          +{overflow}
        </div>
      )}
    </div>
  )
}
```

## Collaborative Cursors (Advanced)

Broadcast cursor positions via a separate broadcast channel (not presence — broadcast has lower overhead for high-frequency updates):

```ts
// Send cursor updates via broadcast
function useCursorBroadcast(channelRef: React.MutableRefObject<RealtimeChannel | null>) {
  useEffect(() => {
    function handleMouseMove(e: MouseEvent) {
      channelRef.current?.send({
        type: 'broadcast',
        event: 'cursor',
        payload: { x: e.clientX / window.innerWidth, y: e.clientY / window.innerHeight },
      })
    }
    window.addEventListener('mousemove', handleMouseMove, { passive: true })
    return () => window.removeEventListener('mousemove', handleMouseMove)
  }, [])
}
```

Rate-limit cursor broadcasts to 30fps (33ms throttle) with `requestAnimationFrame` or a simple timestamp check. Sending every pixel-move floods the channel.

## Typing Indicator

```ts
// Show "Alice is typing..." when a user is editing a text field
async function setTyping(channel: RealtimeChannel, isTyping: boolean) {
  await channel.track({ ...currentPresence, isTyping })
}

// In the text input
function handleKeyDown() {
  setTyping(channel, true)
  clearTimeout(typingTimeout.current)
  typingTimeout.current = setTimeout(() => setTyping(channel, false), 2000)
}
```

Always clear the typing indicator after a timeout (2s of no input). If a user closes the tab mid-typing, Supabase cleans up their presence but the "typing" state would otherwise persist until the timeout.
