# Pattern: Typing Indicator

## Overview
Emitting a typing event on every keydown saturates the websocket with redundant events. The fix is to emit once at the start of a typing burst and debounce the "stopped typing" signal. Group chats compound the problem — showing individual names for 5+ simultaneous typers is noisy, so the display degrades to a count. The indicator must disappear automatically after a server-missed stop event.

## Client-Side Emit

```ts
// Two-signal approach:
// 1. Emit "typing_start" on first keydown after idle
// 2. Emit "typing_stop" via debounce after the last keydown

function useTypingEmitter(conversationId: string) {
  const isTyping = useRef(false);
  const stopTimer = useRef<ReturnType<typeof setTimeout>>();

  function onKeyDown() {
    if (!isTyping.current) {
      // First key after idle — emit start
      isTyping.current = true;
      socket.emit('typing_start', { conversationId });
    }

    // Reset the stop timer on every keydown
    clearTimeout(stopTimer.current);
    stopTimer.current = setTimeout(() => {
      isTyping.current = false;
      socket.emit('typing_stop', { conversationId });
    }, 2000); // 2s of silence → stop
  }

  function onBlur() {
    // Also stop when input loses focus (user switched tabs, etc.)
    if (isTyping.current) {
      clearTimeout(stopTimer.current);
      isTyping.current = false;
      socket.emit('typing_stop', { conversationId });
    }
  }

  function onSend() {
    // Stop typing immediately on send — don't wait for 2s timeout
    clearTimeout(stopTimer.current);
    isTyping.current = false;
    socket.emit('typing_stop', { conversationId });
  }

  // Cleanup on unmount — don't leave a phantom typing indicator server-side
  useEffect(() => () => {
    clearTimeout(stopTimer.current);
    if (isTyping.current) socket.emit('typing_stop', { conversationId });
  }, [conversationId]);

  return { onKeyDown, onBlur, onSend };
}
```

## Server-Side State

```ts
// Server tracks who is typing per conversation in memory (Redis or in-process map)
// TTL auto-expires stale "typing" states in case the client disconnects without stop

// Redis key: typing:{conversationId}:{userId}
// Value: username, TTL: 5 seconds (refreshed on each typing_start)

async function handleTypingStart(socket: Socket, { conversationId }: { conversationId: string }) {
  const userId = socket.data.userId;
  const username = socket.data.username;

  // Set with 5s TTL — covers cases where typing_stop is never sent (crash, disconnect)
  await redis.setex(`typing:${conversationId}:${userId}`, 5, username);

  // Broadcast to everyone else in the conversation
  socket.to(conversationId).emit('typing_update', {
    conversationId,
    typers: await getTypers(conversationId),
  });
}

async function handleTypingStop(socket: Socket, { conversationId }: { conversationId: string }) {
  await redis.del(`typing:${conversationId}:${socket.data.userId}`);
  socket.to(conversationId).emit('typing_update', {
    conversationId,
    typers: await getTypers(conversationId),
  });
}

async function getTypers(conversationId: string): Promise<string[]> {
  const keys = await redis.keys(`typing:${conversationId}:*`);
  if (keys.length === 0) return [];
  return redis.mget(keys) as Promise<string[]>;
}
```

## Display Component

```tsx
function TypingIndicator({ conversationId }: { conversationId: string }) {
  const [typers, setTypers] = useState<string[]>([]);

  useEffect(() => {
    function onUpdate({ conversationId: cid, typers }: { conversationId: string; typers: string[] }) {
      if (cid === conversationId) setTypers(typers);
    }
    socket.on('typing_update', onUpdate);
    return () => socket.off('typing_update', onUpdate);
  }, [conversationId]);

  // Auto-clear after 5s — safety net if server never sends a stop
  const clearTimer = useRef<ReturnType<typeof setTimeout>>();
  useEffect(() => {
    if (typers.length > 0) {
      clearTimeout(clearTimer.current);
      clearTimer.current = setTimeout(() => setTypers([]), 5000);
    }
    return () => clearTimeout(clearTimer.current);
  }, [typers]);

  if (typers.length === 0) return null;

  return (
    <div className="typing-indicator" aria-live="polite" aria-atomic="true">
      <TypingDots />
      <span className="typing-indicator__text">{formatTyperText(typers)}</span>
    </div>
  );
}

function formatTyperText(typers: string[]): string {
  if (typers.length === 1) return `${typers[0]} is typing...`;
  if (typers.length === 2) return `${typers[0]} and ${typers[1]} are typing...`;
  if (typers.length === 3) return `${typers[0]}, ${typers[1]}, and ${typers[2]} are typing...`;
  // 4+: don't list names — it's noisy
  return `${typers.length} people are typing...`;
}
```

## Animated Dots

```css
/* Animated three-dot indicator — pure CSS, no JS animation frame */
.typing-dots { display: inline-flex; gap: 3px; }
.typing-dots span {
  width: 6px; height: 6px;
  border-radius: 50%;
  background: currentColor;
  animation: bounce 1.2s infinite;
  opacity: 0.6;
}
.typing-dots span:nth-child(2) { animation-delay: 0.2s; }
.typing-dots span:nth-child(3) { animation-delay: 0.4s; }

@keyframes bounce {
  0%, 60%, 100% { transform: translateY(0); }
  30% { transform: translateY(-4px); }
}
```

## Key Rules
- Emit `typing_start` once per burst, not on every keydown — check `isTyping` flag first
- Debounce `typing_stop` at 2s — emit immediately on blur or send
- Always emit `typing_stop` on component unmount — prevent phantom indicators
- Server stores typing state in Redis with a 5s TTL — auto-expires on disconnect/crash
- Client auto-clears the indicator after 5s — safety net for missed server stop events
- Display: 1 person → name; 2 → "A and B"; 3 → "A, B, and C"; 4+ → count only
- Use `aria-live="polite"` so screen readers announce the indicator without interrupting
