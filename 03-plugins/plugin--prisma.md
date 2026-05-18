# Plugin: Prisma ORM

## Overview

Prisma is a type-safe ORM for Node.js and TypeScript. It generates a client from your schema file that provides autocompleted, type-safe database queries. Works with PostgreSQL, MySQL, SQLite, MongoDB.

## When to Use Prisma vs Supabase Direct

Use Prisma when:
- You need database-agnostic code (might switch from PostgreSQL to MySQL)
- You're building without Supabase (raw PostgreSQL, PlanetScale, Neon)
- Team prefers a migration-first workflow with versioned schema files
- You want the Prisma Studio GUI for quick data inspection

Use Supabase client directly when:
- Already on Supabase — the Supabase client has RLS, auth, storage, realtime all in one
- You need real-time subscriptions (Prisma doesn't support these)
- Row-Level Security is your authorization layer (Prisma bypasses RLS via connection string)

**Critical:** Prisma uses the database connection string directly — it bypasses PostgreSQL's row-level security entirely. Never use Prisma in user-facing request handlers if RLS is your security boundary.

## Client Singleton

```ts
// lib/prisma.ts
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
  })

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
```

The singleton pattern prevents exhausting database connections in development (hot reload creates new instances without it). In production, one instance per serverless invocation is fine.

## Schema Conventions

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  posts Post[]

  @@map("users")  // maps to snake_case table name
}

model Post {
  id        String   @id @default(cuid())
  title     String
  body      String
  published Boolean  @default(false)
  authorId  String
  author    User     @relation(fields: [authorId], references: [id], onDelete: Cascade)

  @@index([authorId])
  @@map("posts")
}
```

Use `@@map` to keep table names snake_case in the database while models are PascalCase in TypeScript.

## Common Query Patterns

```ts
// Find with related data
const user = await prisma.user.findUnique({
  where: { email: 'test@example.com' },
  include: { posts: { where: { published: true } } },
})

// Pagination
const posts = await prisma.post.findMany({
  where: { published: true },
  orderBy: { createdAt: 'desc' },
  take: 20,
  skip: page * 20,
})

// Upsert (create or update)
const user = await prisma.user.upsert({
  where: { email: data.email },
  update: { name: data.name },
  create: { email: data.email, name: data.name },
})

// Transaction
const [order, payment] = await prisma.$transaction([
  prisma.order.create({ data: orderData }),
  prisma.payment.create({ data: paymentData }),
])

// Raw query for complex SQL
const result = await prisma.$queryRaw<{ count: bigint }[]>`
  SELECT COUNT(*) as count FROM users WHERE created_at > ${cutoff}
`
// Note: $queryRaw returns bigint for COUNT — convert with Number()
const count = Number(result[0].count)
```

## Migrations

```bash
# Development: create a migration
npx prisma migrate dev --name add-posts-table

# Production: apply pending migrations
npx prisma migrate deploy

# Generate client after schema change
npx prisma generate

# Reset dev database (destructive — dev only)
npx prisma migrate reset
```

Commit migration files to git. Never delete migration files — they represent the history of your schema. `migrate dev` creates SQL migration files in `prisma/migrations/`. `migrate deploy` applies them idempotently (tracks applied migrations in `_prisma_migrations` table).

## Soft Delete Pattern

```ts
// Add to all soft-deletable models
model Post {
  deletedAt DateTime?
  @@index([deletedAt])
}

// Extension to add soft delete behavior
const prismaWithSoftDelete = prisma.$extends({
  query: {
    post: {
      async findMany({ args, query }) {
        args.where = { ...args.where, deletedAt: null }
        return query(args)
      },
    },
  },
})
```

## Prisma vs Raw SQL

Prisma generates suboptimal SQL for some complex queries (e.g., deeply nested includes). Use `$queryRaw` for:
- Window functions (`ROW_NUMBER`, `RANK`)
- Complex GROUP BY with HAVING
- CTEs and recursive queries
- Performance-critical hot paths where you want exact SQL control

Always use parameterized queries with `$queryRaw` template literals — they escape values automatically and prevent SQL injection.
