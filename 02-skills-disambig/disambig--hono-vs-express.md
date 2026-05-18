# Disambig: Hono vs Express

## Overview
Hono is built on the Web Standards API (`Request`/`Response`) and runs anywhere a V8 runtime exists — Cloudflare Workers, Deno, Bun, and Node.js. Express is Node.js-only and built on the Node.js `http` module. If your API must run on Cloudflare Workers or another edge runtime, Express is not an option; Hono is the natural choice. For Node.js servers with a rich plugin ecosystem requirement, Express remains entirely viable.

## Implementation / Key Points

### Hono
```ts
import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';

const app = new Hono();

app.get('/users/:id', async (c) => {
  const id = c.req.param('id');
  const user = await db.users.findById(id);
  if (!user) return c.json({ error: 'Not found' }, 404);
  return c.json(user);
});

app.post(
  '/users',
  zValidator('json', z.object({ name: z.string(), email: z.string().email() })),
  async (c) => {
    const body = c.req.valid('json');  // typed and validated
    const user = await db.users.create(body);
    return c.json(user, 201);
  }
);

// Export for any runtime:
export default app;              // Cloudflare Workers
// Bun.serve({ fetch: app.fetch });
// serve(app);                  // Node.js via @hono/node-server
```

### Express
```ts
import express from 'express';

const app = express();
app.use(express.json());

app.get('/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id);
  if (!user) return res.status(404).json({ error: 'Not found' });
  res.json(user);
});

app.listen(3000);
```

### Comparison

| | Hono | Express |
|---|---|---|
| Runtime | Any (Cloudflare, Deno, Bun, Node.js) | Node.js only |
| Bundle size | ~14KB | ~200KB (+ dependencies) |
| API model | Web Standards (Request/Response) | Node.js IncomingMessage |
| Type safety | First-class | Via `@types/express` |
| Middleware | Compatible with Node.js via adapter | Huge ecosystem (`passport`, `multer`, `morgan`) |
| Performance | Very fast (benchmark: ~300k req/s on Bun) | Good on Node.js |
| Validation | `@hono/zod-validator` (built-in type narrowing) | Manual or via express-validator |
| Maturity | 2022 (3+ years) | 2010 (15+ years) |

### Hono on Cloudflare Workers
```ts
// wrangler.toml
// compatibility_flags = ["nodejs_compat"]

// src/index.ts
export default app;  // Cloudflare Workers expects a default export with fetch handler
```

### Express on Cloudflare Workers
Not supported — Cloudflare Workers does not have Node.js `http` module. You cannot run Express on Workers without a full Node.js compatibility layer (which defeats the purpose of Workers).

### When to Use Hono
- Deploying to Cloudflare Workers, Deno Deploy, or Bun
- Multi-runtime target (same codebase runs on Node.js and edge)
- New Node.js APIs where type safety and small bundle size are priorities
- Microservices or lightweight APIs

### When to Use Express
- Large existing Express codebases
- Need specific Express middleware (e.g., `passport.js` strategies, `express-fileupload`)
- Team has deep Express expertise and no edge runtime requirement
- Complex middleware chains relying on mutating `req`/`res` objects

## Key Rules
- Cloudflare Workers = Hono (or another Web Standards framework). Express is not an option.
- Hono's `c.req.valid('json')` gives typed validation output — use `@hono/zod-validator`.
- Express middleware can be adapted to Hono via `@hono/node-server` adapter in some cases.
- Hono's context object (`c`) replaces Express `req`/`res` — it's a different mental model.
- Both support route groups, middleware chaining, and error handling patterns.
