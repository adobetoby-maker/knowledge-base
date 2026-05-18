# TypeScript + Zod — Validation at Boundaries

**When:** Handling data from external sources: user input, API responses, env vars, URL params.
**Rule:** Use Zod to parse and validate at every system boundary. Never trust external data. Once parsed, trust the TypeScript types completely.

## Why Zod
TypeScript types are compile-time only — they vanish at runtime. A typed API response could be anything.
Zod validates the shape at runtime AND narrows the TypeScript type automatically after `.parse()`.

## Basic Patterns

### Form/Request Body Validation
```typescript
import { z } from 'zod'

const ContactSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  email: z.string().email('Invalid email'),
  message: z.string().min(10).max(1000),
  phone: z.string().optional()
})

type Contact = z.infer<typeof ContactSchema>  // derive type from schema

// In Route Handler
export async function POST(req: NextRequest) {
  const body = await req.json()
  const result = ContactSchema.safeParse(body)  // use safeParse — doesn't throw

  if (!result.success) {
    return NextResponse.json({
      error: 'Invalid input',
      details: result.error.flatten().fieldErrors
    }, { status: 400 })
  }

  const contact = result.data  // fully typed: Contact
  // now trust it completely
  await db.contacts.insert(contact)
}
```

### API Response Validation
```typescript
const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  createdAt: z.string().datetime().transform(s => new Date(s))
})

const response = await fetch('/api/user/123')
const data = await response.json()  // unknown at runtime
const user = UserSchema.parse(data)  // throws if shape is wrong
// user is now: { id: string, email: string, createdAt: Date }
```

### URL Search Params
```typescript
const SearchSchema = z.object({
  q: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),  // coerce: "5" → 5
  category: z.enum(['oil-change', 'brakes', 'tires']).optional()
})

// In a Server Component
export default function Page({ searchParams }: { searchParams: Record<string, string> }) {
  const params = SearchSchema.parse(searchParams)
  // params.page is number (not string), defaults to 1
}
```

### Environment Variables (at startup)
```typescript
// lib/env.ts — validate once at startup, export typed values
import { z } from 'zod'

const EnvSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  ADMIN_SECRET: z.string().min(32, 'ADMIN_SECRET must be at least 32 chars'),
  ANTHROPIC_API_KEY: z.string().startsWith('sk-ant-'),
})

export const env = EnvSchema.parse(process.env)
// If any var is missing or wrong shape, throws at startup with a clear error
```

## safeParse vs parse
```typescript
// .parse() — throws ZodError if invalid
const user = UserSchema.parse(data)  // use when you want to crash on bad data

// .safeParse() — returns { success: boolean, data?, error? }
const result = UserSchema.safeParse(data)  // use for user-facing validation
if (!result.success) {
  console.log(result.error.flatten())  // user-friendly error structure
}
```

## Common Schema Patterns
```typescript
z.string().url()                  // valid URL
z.string().email()                // valid email
z.string().uuid()                 // UUID format
z.coerce.number()                 // "5" → 5, string coercion
z.number().int().min(1).max(100)  // integer range
z.enum(['a', 'b', 'c'])           // specific values only
z.array(ItemSchema).min(1)        // non-empty array
z.record(z.string(), z.number())  // { [key: string]: number }
z.union([SchemaA, SchemaB])       // either shape
z.discriminatedUnion('type', [...]) // based on discriminant field
```
