# Failure: Date Object Serialization Loss

## Overview
`Date` objects in JavaScript are not serializable by default. When passed through JSON (`JSON.stringify` → `JSON.parse`), across React Server Component → Client Component boundaries, through `postMessage`, or via `localStorage`, `Date` objects silently become strings. The application continues to work — until code that expects `date.getFullYear()` receives a string and throws "date.getFullYear is not a function." This class of bug is particularly insidious because it only appears at runtime when data crosses a serialization boundary.

## Where Dates Get Lost

### JSON Round-Trip
```typescript
const event = { title: "Meeting", startAt: new Date("2024-12-01") };

// JSON.stringify converts Date to ISO string
const json = JSON.stringify(event);
// '{"title":"Meeting","startAt":"2024-12-01T00:00:00.000Z"}'

// JSON.parse returns a plain string — NOT a Date object
const parsed = JSON.parse(json);
typeof parsed.startAt; // "string"
parsed.startAt.getFullYear(); // TypeError: parsed.startAt.getFullYear is not a function
```

### Next.js Server Component → Client Component Props
```typescript
// Server Component
async function EventPage() {
  const event = await prisma.event.findFirst(); // event.startAt is a Date object
  
  // React serializes props to JSON when passing to Client Components
  return <EventCard startAt={event.startAt} />;
  // ← Date is serialized to string; EventCard receives a string, not a Date
}

// Client Component
"use client";
function EventCard({ startAt }: { startAt: Date }) {
  // TypeScript says Date, but at runtime it's a string
  return <time>{startAt.toLocaleDateString()}</time>; // TypeError at runtime
}
```

### localStorage
```typescript
const session = { userId: "123", expiresAt: new Date() };
localStorage.setItem("session", JSON.stringify(session));

const restored = JSON.parse(localStorage.getItem("session")!);
restored.expiresAt > new Date(); // WRONG: string comparison, not date comparison
// "2024-12-01T..." > "2024-06-01T..." → this works accidentally for ISO strings
// but: restored.expiresAt.getTime() → TypeError
```

## The Fix: Explicit Serialization and Deserialization

### Always Serialize to ISO String Before Transmission

```typescript
// Server Component — serialize Date before passing to Client
async function EventPage() {
  const event = await prisma.event.findFirst();
  return (
    <EventCard
      startAt={event.startAt.toISOString()} // explicit string conversion
    />
  );
}

// Client Component — receives string, reconstructs Date when needed
"use client";
function EventCard({ startAt }: { startAt: string }) {
  const startDate = new Date(startAt); // explicit reconstruction
  return <time>{startDate.toLocaleDateString()}</time>;
}
```

### ISO 8601 for All Date Serialization

`Date.toISOString()` produces UTC time in ISO 8601 format: `"2024-12-01T14:30:00.000Z"`. This format is:
- Unambiguous (always UTC, always the same format)
- Sortable lexicographically
- Parseable by `new Date("2024-12-01T14:30:00.000Z")`
- Timezone-safe (no locale confusion)

Never serialize dates as locale strings (`date.toLocaleString()` → `"12/1/2024, 2:30 PM"`) — these are not parseable back to a Date.

### Zod for API Response Parsing

When fetching from APIs, use Zod to coerce ISO strings back to Date objects:

```typescript
import { z } from "zod";

const EventSchema = z.object({
  id: z.string().uuid(),
  title: z.string(),
  startAt: z.string().datetime().pipe(z.coerce.date()), // string → Date
  createdAt: z.coerce.date(), // ISO string → Date
});

const rawData = await fetch("/api/events").then(r => r.json());
const event = EventSchema.parse(rawData);
event.startAt.getFullYear(); // works correctly — actual Date object
```

### Prisma Date Fields

Prisma returns `Date` objects for `DateTime` columns — this is correct. The bug occurs when those objects cross serialization boundaries:

```typescript
// Safe: using Date in server-side code
const events = await prisma.event.findMany();
events.forEach(e => console.log(e.startAt.getFullYear())); // works

// Bug: passing to Client Component or JSON response without serialization
return Response.json({ events }); // dates become strings in JSON
// Fix:
return Response.json({
  events: events.map(e => ({
    ...e,
    startAt: e.startAt.toISOString(),
    createdAt: e.createdAt.toISOString(),
  }))
});
```

## TypeScript Cannot Help Without Branded Types

TypeScript treats `Date` and `string` as different types, but the actual runtime value is a string. This is a type safety gap at serialization boundaries. Mitigations:
- Use `ISODateString` type alias for string-serialized dates
- Use Zod parse at every API boundary to ensure dates are Date objects when the code expects them

## Key Rules
- Always `toISOString()` when putting a Date into JSON, localStorage, props, or message passing
- Always `new Date(isoString)` when reading back from any JSON source
- Zod with `z.coerce.date()` at API response parsing boundaries
- Next.js Server → Client props: dates must be serialized to string (the framework serializes to JSON)
- Never use `toLocaleString()` for storage/transmission — only for display
- In TypeScript, use `string` type for ISO date props crossing client/server boundary; reconstruct with `new Date()` on the receiving end
- Test with date values that cross serialization boundaries — not just pure in-memory values
