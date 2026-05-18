# Plugin: Socket.IO

## Overview

Socket.IO enables real-time bidirectional communication between server and clients. Used for: chat, live collaboration, multiplayer, live dashboards. Not applicable for Vercel/Cloudflare serverless — requires a persistent server (Railway, Fly.io, Render).

## When to Use Socket.IO vs. Supabase Realtime

| Scenario | Use |
|----------|-----|
| Real-time DB changes (inserts, updates) | Supabase Realtime |
| Presence across app users | Supabase Realtime Presence |
| Chat / messaging | Either — Socket.IO has rooms, Supabase has channels |
| Multiplayer game state | Socket.IO — lower latency, full control |
| Collaborative editing | Socket.IO + CRDT (Yjs) |
| Push from server to clients | Supabase is simpler |
| Custom server-side events, rooms, auth | Socket.IO |

Use Supabase Realtime first — it's zero infrastructure. Use Socket.IO when you need custom room logic, game state, or latency-critical bidirectional communication.

## Server Setup (Node.js + Express)

```ts
// server.ts (separate Node.js server on Railway/Fly.io)
import { createServer } from 'http'
import { Server } from 'socket.io'
import express from 'express'

const app = express()
const httpServer = createServer(app)
const io = new Server(httpServer, {
  cors: {
    origin: process.env.CLIENT_URL ?? 'http://localhost:3000',
    methods: ['GET', 'POST'],
    credentials: true,
  },
})

// Authentication middleware
io.use(async (socket, next) => {
  const token = socket.handshake.auth.token
  if (!token) return next(new Error('Authentication required'))

  try {
    const { data: { user } } = await supabase.auth.getUser(token)
    if (!user) return next(new Error('Invalid token'))
    socket.data.userId = user.id
    next()
  } catch {
    next(new Error('Auth failed'))
  }
})

io.on('connection', (socket) => {
  const { userId } = socket.data
  console.log(`User ${userId} connected: ${socket.id}`)

  // Join a room
  socket.on('join-room', (roomId: string) => {
    socket.join(roomId)
    socket.to(roomId).emit('user-joined', { userId, socketId: socket.id })
  })

  // Chat message
  socket.on('message', (data: { roomId: string; text: string }) => {
    const message = {
      id: crypto.randomUUID(),
      userId,
      text: data.text,
      timestamp: Date.now(),
    }
    // Emit to room — including sender
    io.to(data.roomId).emit('message', message)
    // Save to database
    saveMessage(message).catch(console.error)
  })

  socket.on('disconnect', () => {
    console.log(`User ${userId} disconnected`)
  })
})

httpServer.listen(4000, () => console.log('Socket.IO server on :4000'))
```

## Client Setup (Next.js)

```ts
// lib/socket.ts
import { io, Socket } from 'socket.io-client'

let socket: Socket | null = null

export function getSocket(token: string): Socket {
  if (!socket) {
    socket = io(process.env.NEXT_PUBLIC_SOCKET_URL!, {
      auth: { token },
      autoConnect: true,
      reconnection: true,
      reconnectionAttempts: 5,
      reconnectionDelay: 1000,
    })
  }
  return socket
}

export function disconnectSocket() {
  socket?.disconnect()
  socket = null
}
```

## Chat Room Hook

```ts
'use client'
import { useEffect, useRef, useState } from 'react'
import { getSocket } from '@/lib/socket'

interface Message {
  id: string
  userId: string
  text: string
  timestamp: number
}

export function useChat(roomId: string, token: string) {
  const [messages, setMessages] = useState<Message[]>([])
  const [connected, setConnected] = useState(false)
  const socketRef = useRef<ReturnType<typeof getSocket> | null>(null)

  useEffect(() => {
    const socket = getSocket(token)
    socketRef.current = socket

    socket.on('connect', () => {
      setConnected(true)
      socket.emit('join-room', roomId)
    })

    socket.on('disconnect', () => setConnected(false))

    socket.on('message', (message: Message) => {
      setMessages((prev) => [...prev, message])
    })

    return () => {
      socket.off('message')
      socket.off('connect')
      socket.off('disconnect')
      // Don't disconnect — socket is shared across components
    }
  }, [roomId, token])

  function sendMessage(text: string) {
    socketRef.current?.emit('message', { roomId, text })
  }

  return { messages, connected, sendMessage }
}
```

## Rooms and Namespaces

```ts
// Namespaces: separate event channels on same connection
const chatNS = io.of('/chat')
const gameNS = io.of('/game')

// Client
const chatSocket = io('/chat', { auth: { token } })
const gameSocket = io('/game', { auth: { token } })

// Rooms: group sockets for targeted broadcasts
socket.join(`room:${roomId}`)      // Join a room
io.to(`room:${roomId}`).emit(...)  // Broadcast to all in room
socket.to(`room:${roomId}`).emit(...)  // To room, excluding sender
socket.leave(`room:${roomId}`)     // Leave
```

## Scaling to Multiple Instances

Socket.IO state (rooms, socket IDs) is in-memory per instance. To scale horizontally, use Redis adapter:

```ts
import { createAdapter } from '@socket.io/redis-adapter'
import { createClient } from 'redis'

const pubClient = createClient({ url: process.env.REDIS_URL })
const subClient = pubClient.duplicate()
await Promise.all([pubClient.connect(), subClient.connect()])

io.adapter(createAdapter(pubClient, subClient))
```

Without the Redis adapter, `io.to(roomId).emit()` only reaches clients connected to the same server instance.
