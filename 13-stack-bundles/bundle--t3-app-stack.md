# Stack Bundle: T3 App Stack (Next.js + tRPC + Prisma + Tailwind + NextAuth)

## Overview
The T3 stack achieves end-to-end type safety from database to UI without writing separate API contracts.
tRPC's key insight is that if your backend and frontend are in the same repository, you don't need HTTP
API types — you import the router type directly. This eliminates an entire class of type drift bugs.

## Implementation

### tRPC Router Setup
```ts
// server/api/trpc.ts — core setup
import { initTRPC, TRPCError } from '@trpc/server';
import { ZodError } from 'zod';

const t = initTRPC.context<typeof createTRPCContext>().create({
  errorFormatter({ shape, error }) {
    return {
      ...shape,
      data: {
        ...shape.data,
        zodError: error.cause instanceof ZodError ? error.cause.flatten() : null,
      },
    };
  },
});

export const createTRPCRouter = t.router;
export const publicProcedure = t.procedure;

// Authenticated procedure — reusable middleware
const enforceUserIsAuthed = t.middleware(({ ctx, next }) => {
  if (!ctx.session?.user) {
    throw new TRPCError({ code: 'UNAUTHORIZED' });
  }
  return next({ ctx: { ...ctx, session: ctx.session } });  // session is non-null here
});

export const protectedProcedure = t.procedure.use(enforceUserIsAuthed);
```

### createTRPCContext for Request Context
```ts
// server/api/trpc.ts
import { getServerSession } from 'next-auth';
import { authOptions } from '~/server/auth';
import { db } from '~/server/db';

export const createTRPCContext = async (opts: CreateNextContextOptions) => {
  const session = await getServerSession(opts.req, opts.res, authOptions);
  return {
    db,
    session,
    req: opts.req,
  };
};
```

### Router with Input Validation
```ts
// server/api/routers/post.ts
import { z } from 'zod';
import { createTRPCRouter, protectedProcedure, publicProcedure } from '~/server/api/trpc';

export const postRouter = createTRPCRouter({
  getAll: publicProcedure.query(({ ctx }) => {
    return ctx.db.post.findMany({ orderBy: { createdAt: 'desc' } });
  }),

  create: protectedProcedure
    .input(z.object({ title: z.string().min(1).max(200), body: z.string() }))
    .mutation(({ ctx, input }) => {
      return ctx.db.post.create({
        data: { ...input, authorId: ctx.session.user.id },  // session is non-null (enforced by protectedProcedure)
      });
    }),

  delete: protectedProcedure
    .input(z.object({ id: z.string().cuid() }))
    .mutation(async ({ ctx, input }) => {
      const post = await ctx.db.post.findUnique({ where: { id: input.id } });
      if (post?.authorId !== ctx.session.user.id) {
        throw new TRPCError({ code: 'FORBIDDEN' });
      }
      return ctx.db.post.delete({ where: { id: input.id } });
    }),
});
```

### Type Inference AppRouter
```ts
// server/api/root.ts
export const appRouter = createTRPCRouter({
  post: postRouter,
  user: userRouter,
});

export type AppRouter = typeof appRouter;  // the single exported type

// client/utils/api.ts
import { createTRPCReact } from '@trpc/react-query';
import type { AppRouter } from '~/server/api/root';

export const api = createTRPCReact<AppRouter>();
// AppRouter travels from server to client as a TYPE ONLY — zero runtime overhead
```

### useUtils for Cache Invalidation
```tsx
// component
const utils = api.useUtils();

const createPost = api.post.create.useMutation({
  onSuccess: async () => {
    // Invalidate the getAll query so it refetches
    await utils.post.getAll.invalidate();
    // Or update the cache optimistically instead of refetching:
    utils.post.getAll.setData(undefined, (old) => [newPost, ...(old ?? [])]);
  },
});
```

### Prisma Schema Patterns
```prisma
// prisma/schema.prisma
model Post {
    id        String   @id @default(cuid())
    title     String
    body      String   @db.Text
    createdAt DateTime @default(now())
    updatedAt DateTime @updatedAt
    author    User     @relation(fields: [authorId], references: [id], onDelete: Cascade)
    authorId  String

    @@index([authorId])   // always index foreign keys
}
```
```bash
npx prisma db push          # push schema to dev DB (no migration file)
npx prisma migrate dev      # create migration file + apply (use for tracked changes)
npx prisma generate         # regenerate Prisma Client (run after schema change)
```

## Key Rules
- `AppRouter` type is imported with `import type` on the client — it is never bundled into client JS
- `protectedProcedure` makes session non-nullable in the handler — always use it for authenticated routes
- Input validation with Zod goes on the procedure `.input()`, never inside the handler body
- `useUtils().invalidate()` triggers a background refetch; `setData()` is optimistic (no network call)
- Never call `createTRPCContext` directly from components — it runs on the server only
- `db.push` for rapid prototyping; `migrate dev` for any schema change you want tracked in git
- tRPC error codes map to HTTP status: UNAUTHORIZED → 401, FORBIDDEN → 403, NOT_FOUND → 404, BAD_REQUEST → 400
