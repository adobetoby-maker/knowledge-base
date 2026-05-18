# Stack Bundle: Next.js + Prisma + PostgreSQL

## Overview

Next.js App Router with Prisma ORM and PostgreSQL. Use this when you want a familiar ORM with migrations, type-safe queries, and explicit schema definition. The key difference from the Drizzle stack: Prisma requires code generation (`prisma generate`) after every schema change, and needs PgBouncer or Prisma Accelerate in serverless environments.

## Project Structure

```
prisma/
  schema.prisma        # Data model
  migrations/          # Auto-generated migration files
  seed.ts              # Development seed data
src/
  lib/
    prisma.ts          # PrismaClient singleton
  app/
    api/               # Route handlers using Prisma
```

## PrismaClient Singleton

```ts
// src/lib/prisma.ts
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient }

export const prisma = globalForPrisma.prisma ?? new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'error'] : ['error'],
})

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma
}
```

The `globalThis` pattern prevents creating a new connection pool on every hot-reload in development.

## Schema Definition

```prisma
// prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")   // For Supabase/PgBouncer: bypass pooler for migrations
}

generator client {
  provider = "prisma-client-js"
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  posts     Post[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  author    User     @relation(fields: [authorId], references: [id])
  authorId  String
  createdAt DateTime @default(now())
}
```

## Migrations Workflow

```bash
# Develop schema changes
npx prisma migrate dev --name add-post-table   # creates migration + runs it

# Production deploy
npx prisma migrate deploy                        # applies pending migrations

# After pulling schema changes from git
npx prisma generate                              # regenerate client

# Inspect current DB state
npx prisma studio                                # visual DB browser
```

## Queries

```ts
// Eager loading with include
const user = await prisma.user.findUnique({
  where: { id: userId },
  include: { posts: { where: { published: true } } },
})

// Select specific fields
const users = await prisma.user.findMany({
  select: { id: true, email: true, name: true },
  orderBy: { createdAt: 'desc' },
  take: 20,
  skip: (page - 1) * 20,
})

// Transaction
const [user, post] = await prisma.$transaction([
  prisma.user.create({ data: { email, name } }),
  prisma.post.create({ data: { title, authorId: userId } }),
])
```

## Serverless Setup (Supabase + PgBouncer)

```env
# Two connection strings required for Supabase:
DATABASE_URL="postgresql://...@aws-0-us-east-1.pooler.supabase.com:5432/postgres?pgbouncer=true"
DIRECT_URL="postgresql://...@aws-0-us-east-1.pooler.supabase.com:5432/postgres"
```

`DATABASE_URL` uses the pooler for queries. `DIRECT_URL` bypasses the pooler for migrations (which require direct connections).

## Key Rules

- Run `prisma generate` after every schema change — the client is generated code and must match the schema.
- Use `DIRECT_URL` for migrations alongside pooled `DATABASE_URL` in serverless environments.
- `cuid()` or `uuid()` defaults are safer than auto-increment integers for public-facing IDs.
- `include` for relations + `select` for field projection can be combined, but don't `include` everything by default — it causes N+1 at the DB level.
- In development, `log: ['query']` shows all SQL queries to spot N+1 problems early.
