# Plugin: tRPC

## Overview
tRPC eliminates the API layer as a source of type drift: your server procedures and client calls share the same TypeScript types with no code generation step. The router is the schema. When you change a procedure's input or output, the call sites break at compile time, not at runtime in production. This works by sharing the `AppRouter` type between server and client — no runtime overhead, just type inference.

## Implementation

### Server Setup
```ts
// server/trpc.ts
import { initTRPC, TRPCError } from '@trpc/server';
import { type FetchCreateContextFnOptions } from '@trpc/server/adapters/fetch';
import { getSession } from './auth';

export const createContext = async (opts: FetchCreateContextFnOptions) => {
  const session = await getSession(opts.req);
  return { session, req: opts.req };
};

type Context = Awaited<ReturnType<typeof createContext>>;

const t = initTRPC.context<Context>().create();

export const router = t.router;
export const publicProcedure = t.procedure;

// Protected procedure — reusable middleware
export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  if (!ctx.session?.user) {
    throw new TRPCError({ code: 'UNAUTHORIZED' });
  }
  return next({ ctx: { ...ctx, user: ctx.session.user } });
});
```

### Router Definition
```ts
// server/routers/user.ts
import { z } from 'zod';
import { router, publicProcedure, protectedProcedure } from '../trpc';

export const userRouter = router({
  getById: publicProcedure
    .input(z.object({ id: z.string() }))
    .query(async ({ input, ctx }) => {
      const user = await db.user.findUnique({ where: { id: input.id } });
      if (!user) throw new TRPCError({ code: 'NOT_FOUND', message: 'User not found' });
      return user;
    }),

  updateProfile: protectedProcedure
    .input(z.object({ name: z.string().min(1), bio: z.string().optional() }))
    .mutation(async ({ input, ctx }) => {
      return db.user.update({
        where: { id: ctx.user.id },
        data: input,
      });
    }),
});

// server/root.ts — merge all routers
export const appRouter = router({
  user: userRouter,
  post: postRouter,
});

export type AppRouter = typeof appRouter; // exported to client
```

### Next.js Route Handler
```ts
// app/api/trpc/[trpc]/route.ts
import { fetchRequestHandler } from '@trpc/server/adapters/fetch';
import { appRouter } from '@/server/root';
import { createContext } from '@/server/trpc';

const handler = (req: Request) =>
  fetchRequestHandler({
    endpoint: '/api/trpc',
    req,
    router: appRouter,
    createContext,
  });

export { handler as GET, handler as POST };
```

### Client Setup
```ts
// lib/trpc/client.ts
import { createTRPCReact } from '@trpc/react-query';
import type { AppRouter } from '@/server/root';

export const trpc = createTRPCReact<AppRouter>();

// providers/trpc.tsx
export function TRPCProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());
  const [trpcClient] = useState(() =>
    trpc.createClient({
      links: [
        httpBatchLink({
          url: '/api/trpc',
          headers: () => ({ 'x-trpc-source': 'client' }),
        }),
      ],
    })
  );

  return (
    <trpc.Provider client={trpcClient} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </trpc.Provider>
  );
}
```

### Client Usage
```tsx
// Queries
const { data, isLoading, error } = trpc.user.getById.useQuery({ id: '123' });

// Mutations with cache invalidation
const utils = trpc.useUtils();
const updateProfile = trpc.user.updateProfile.useMutation({
  onSuccess: () => {
    utils.user.getById.invalidate(); // invalidate specific query
    // or: utils.user.invalidate() — invalidates all user queries
  },
});

// Server-side caller (in Server Components / Route Handlers)
import { createCallerFactory } from '@trpc/server';
const createCaller = createCallerFactory(appRouter);
const caller = createCaller(await createContext(opts));
const user = await caller.user.getById({ id: '123' }); // no HTTP round trip
```

## Key Rules
- Export only `AppRouter` type from server to client — never import server implementations client-side
- Use `TRPCError` with semantic codes: `NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`, `BAD_REQUEST`, `INTERNAL_SERVER_ERROR`
- Input validation with Zod is not optional — it's how tRPC knows the input type; without it, input is `void`
- `query` for reads (GET semantics), `mutation` for writes (POST semantics)
- `useUtils().invalidate()` triggers React Query cache invalidation; scope it narrowly (by input) to avoid over-fetching
- `createCallerFactory` for server-side calls skips HTTP entirely — use in Server Components or route handlers
- Middleware (`.use()`) can narrow context type — TypeScript will enforce the narrowed context in the procedure
- Batch requests happen automatically via `httpBatchLink` — multiple calls in the same tick become one HTTP request
