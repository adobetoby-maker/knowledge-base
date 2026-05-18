# Pattern: Live Collaboration Cursors

## Overview
Real-time cursors signal presence — they show collaborators where others are working, preventing accidental overwrites and enabling coordination without out-of-band communication. Sending cursor position on a continuous timer wastes bandwidth and causes jitter; sending on move events only is far more efficient. Fading after inactivity prevents ghost cursors from cluttering the UI.

## Implementation

### Presence with Liveblocks
```typescript
// types/liveblocks.ts
import { createClient } from '@liveblocks/client';
import { createRoomContext } from '@liveblocks/react';

type Presence = {
  cursor: { x: number; y: number } | null;
  name: string;
  color: string; // deterministic from user ID
};

type Storage = {}; // your document storage here

export const client = createClient({ publicApiKey: process.env.NEXT_PUBLIC_LIVEBLOCKS_KEY! });
export const { RoomProvider, useMyPresence, useOthers } = createRoomContext<Presence, Storage>(client);
```

### Deterministic Color from User ID
```typescript
const CURSOR_COLORS = [
  '#E03131', '#C2255C', '#9C36B5', '#3B5BDB',
  '#1C7ED6', '#0C8599', '#2F9E44', '#E67700',
];

function userColor(userId: string): string {
  // Hash the user ID to an index — same user always gets the same color
  let hash = 0;
  for (let i = 0; i < userId.length; i++) {
    hash = (hash << 5) - hash + userId.charCodeAt(i);
    hash |= 0;
  }
  return CURSOR_COLORS[Math.abs(hash) % CURSOR_COLORS.length];
}
```

### Cursor Tracking (only on move)
```tsx
function CollaborativeCanvas({ children }) {
  const [, updatePresence] = useMyPresence();

  const handlePointerMove = useCallback(
    throttle((e: React.PointerEvent) => {
      const rect = e.currentTarget.getBoundingClientRect();
      updatePresence({
        cursor: {
          x: Math.round(e.clientX - rect.left),
          y: Math.round(e.clientY - rect.top),
        },
      });
    }, 16), // ~60fps max
    [updatePresence]
  );

  const handlePointerLeave = useCallback(() => {
    updatePresence({ cursor: null }); // hide cursor when user leaves canvas
  }, [updatePresence]);

  return (
    <div
      onPointerMove={handlePointerMove}
      onPointerLeave={handlePointerLeave}
      style={{ position: 'relative' }}
    >
      {children}
      <RemoteCursors />
    </div>
  );
}
```

### Remote Cursors Overlay
```tsx
const INACTIVITY_MS = 3000;

function RemoteCursors() {
  const others = useOthers();

  return (
    <>
      {others.map(({ connectionId, presence, info }) => {
        if (!presence.cursor) return null;
        return (
          <RemoteCursor
            key={connectionId}
            x={presence.cursor.x}
            y={presence.cursor.y}
            name={info?.name ?? 'Anonymous'}
            color={userColor(connectionId.toString())}
            lastMoved={Date.now()} // track for fade
          />
        );
      })}
    </>
  );
}

function RemoteCursor({ x, y, name, color, lastMoved }) {
  const [opacity, setOpacity] = useState(1);

  useEffect(() => {
    setOpacity(1); // reset on move
    const timer = setTimeout(() => setOpacity(0), INACTIVITY_MS);
    return () => clearTimeout(timer);
  }, [x, y]);

  return (
    <div
      style={{
        position: 'absolute',
        left: x,
        top: y,
        pointerEvents: 'none', // don't block clicks
        transition: 'opacity 0.5s ease',
        opacity,
        zIndex: 100,
      }}
    >
      <CursorIcon color={color} />
      <span
        style={{ backgroundColor: color }}
        className="cursor-label"
      >
        {name}
      </span>
    </div>
  );
}
```

### With Y.js (self-hosted alternative)
```typescript
import * as Y from 'yjs';
import { WebsocketProvider } from 'y-websocket';

const doc = new Y.Doc();
const provider = new WebsocketProvider('wss://your-server/yjs', 'room-id', doc);
const awareness = provider.awareness;

// Set local cursor
awareness.setLocalStateField('cursor', { x, y });
awareness.setLocalStateField('user', { name: currentUser.name, color: userColor(currentUser.id) });

// Subscribe to remote cursors
awareness.on('change', () => {
  const states = Array.from(awareness.getStates().entries());
  // render each state's cursor
});
```

## Key Rules
- Send cursor position only on `pointermove` events — never on a timer
- Throttle move events to 60fps (16ms) maximum — prevents flooding the server
- Null cursor on `pointerleave` — don't leave ghost cursors when user leaves the area
- Fade cursor after 3 seconds of no movement — `setTimeout` reset on each position update
- `pointerEvents: none` on cursor elements — they must not block user interactions
- Deterministic color from user ID — same user always appears in the same color
- Show name label near the cursor — colors alone are not accessible
- Colors must contrast with the canvas background — test on both light and dark themes
- For Y.js: use awareness protocol, not the shared document — cursors are ephemeral, not persistent
- Cursor state is not stored in the DB — it's ephemeral, lives only in the real-time layer
