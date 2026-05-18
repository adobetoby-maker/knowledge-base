# Next.js RSC Bundle Boundary — 'use client' Is Not a Toggle

**When:** Adding interactivity to a Server Component. Unsure where to put 'use client'.
**Rule:** 'use client' marks a bundle split point — everything below it becomes client JS. It does NOT mean "only runs on client." Components without it run ONLY on the server.

## The Mental Model
```
No directive    → Server Component: runs on server only
'use client'    → Client Component: bundled as JS, sent to browser

'use client' = "start of the client bundle here"
                 Everything imported by this component is also client JS
```

## What Each Can Do

### Server Components — The Default
```typescript
// No directive = Server Component
import { db } from '@/lib/db'  // OK — not in browser bundle

async function UserProfile({ id }: { id: string }) {
  const user = await db.users.findUnique({ where: { id } })  // direct DB access
  
  // CANNOT use: useState, useEffect, onClick, browser APIs
  return <div>{user.name}</div>
}
```

### Client Components
```typescript
'use client'

import { useState } from 'react'  // OK — React hooks work here

function LikeButton({ postId }: { postId: string }) {
  const [liked, setLiked] = useState(false)
  
  // CANNOT: import server-only modules (db, fs, env secrets)
  // CANNOT: be async (top-level async components)
  return <button onClick={() => setLiked(!liked)}>{liked ? '❤️' : '♡'}</button>
}
```

## The Composition Pattern — Pass Server Data to Client Components
```typescript
// Server Component (no directive)
async function ArticlePage({ slug }: { slug: string }) {
  const article = await db.articles.findBySlug(slug)  // server-only
  
  // Pass data DOWN as props to client interactive parts
  return (
    <article>
      <h1>{article.title}</h1>
      <p>{article.body}</p>
      <LikeButton postId={article.id} initialLikes={article.likes} />
      {/* LikeButton is 'use client' and gets plain serializable props */}
    </article>
  )
}
```

## The Children Pattern — Server Content Inside Client Wrappers
```typescript
// Client wrapper (animates, tracks state)
'use client'
function AnimatedSection({ children }: { children: React.ReactNode }) {
  const [visible, setVisible] = useState(false)
  return <div className={visible ? 'visible' : 'hidden'}>{children}</div>
}

// Server Component uses it — passes server-rendered content as children
async function Page() {
  const data = await fetchExpensiveData()  // server-only
  return (
    <AnimatedSection>
      <ExpensiveServerContent data={data} />
      {/* This renders on server, passed as children to client component */}
    </AnimatedSection>
  )
}
```

## Common Mistakes
```typescript
// WRONG — importing server-only in client component
'use client'
import { db } from '@/lib/db'  // ERROR: db uses Node.js, not available in browser

// WRONG — adding 'use client' to everything "just to be safe"
// This pushes ALL data fetching to client-side, eliminating RSC benefits

// WRONG — async Client Component
'use client'
async function MyComponent() {  // ERROR: client components can't be async
  const data = await fetch(...)
}
// Fix: fetch in a Server Component, pass as props. Or use TanStack Query.
```

## Rule: Push 'use client' as Deep as Possible
```
Page (server — fetches all data)
  └── Layout (server — renders structure)
       ├── Content (server — renders text)
       └── InteractiveButton (client — needs onClick)  ← 'use client' here, not higher
```
