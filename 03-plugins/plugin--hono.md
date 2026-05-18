# Plugin: Hono Web Framework

## Purpose
Minimal, fast web framework designed for edge runtimes (Cloudflare Workers, Deno Deploy, Bun, Node.js). Unlike Express, Hono targets the WinterCG-compatible `fetch` API standard — `app.fetch` is the entry point, not `app.listen`. This means the same `app.ts` runs on Workers, Lambda, or Node without modification.

## Routing
```ts
import { Hono } from 'hono';

const app = new Hono();

app.get('/health', c => c.json({ ok: true }));
app.get('/users/:id', async c => {
  const id = c.req.param('id');
  const user = await getUser(id);
  if (!user) return c.json({ error: 'Not found' }, 404);
  return c.json(user);
});
app.post('/users', async c => {
  const body = await c.req.json();
  // ...
});
```

Route groups with `Hono` sub-apps:
```ts
const api = new Hono();
api.get('/users', listUsers);
api.post('/users', createUser);

app.route('/api/v1', api);
```

## `c.req.json()` / `c.json()` Helpers
Hono's context `c` wraps request and response:
- `c.req.json()` — parse JSON body (async)
- `c.req.param('name')` — path parameter
- `c.req.query('key')` — query string value
- `c.json(data, status?)` — return JSON response
- `c.text(str, status?)` — return plain text
- `c.html(str)` — return HTML

Always use these helpers rather than constructing `Response` objects manually — they set correct Content-Type headers automatically.

## Middleware Chain
Middleware runs in registration order. Use `app.use()` for global middleware, or pass inline to specific routes:

```ts
import { logger } from 'hono/logger';
import { cors } from 'hono/cors';
import { bearerAuth } from 'hono/bearer-auth';

app.use('*', logger());
app.use('/api/*', cors({ origin: process.env.ALLOWED_ORIGIN }));
app.use('/api/admin/*', bearerAuth({ token: process.env.ADMIN_TOKEN! }));
```

Hono ships many middleware out of the box: `logger`, `cors`, `bearerAuth`, `basicAuth`, `compress`, `etag`, `cache`, `secureHeaders`. Use these instead of hand-rolling.

To pass data between middleware and handlers, use `c.set()` / `c.get()` with typed variables:
```ts
type Variables = { userId: string };
const app = new Hono<{ Variables: Variables }>();

app.use('/api/*', async (c, next) => {
  const userId = verifyJwt(c.req.header('Authorization'));
  c.set('userId', userId);
  await next();
});

app.get('/api/me', c => {
  const userId = c.get('userId'); // typed as string
  return c.json({ userId });
});
```

## Zod Validator Middleware
```ts
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
});

app.post('/users', zValidator('json', createUserSchema), async c => {
  const data = c.req.valid('json'); // typed as CreateUser
  // ...
});
```

`zValidator` returns 400 with validation errors automatically — no manual try/catch. The `'json'` target can be `'form'`, `'query'`, `'param'`, `'header'` for other input locations.

## Cloudflare Workers Deployment
```ts
// index.ts — the entry point
export default app; // Hono app is the default export

// wrangler.toml
// main = "src/index.ts"
```

Hono's `app` object has an `.fetch(request, env, ctx)` method — this is what Cloudflare Workers calls. Exporting the `app` directly satisfies the Workers module interface. To access `env` bindings (KV, R2, D1) inside handlers, use `c.env`:

```ts
app.get('/data', async c => {
  const value = await c.env.MY_KV.get('key');
  return c.json({ value });
});
```

Type the bindings: `new Hono<{ Bindings: Env }>()` where `Env` matches your `wrangler.toml` bindings.

## Error Handling
```ts
app.onError((err, c) => {
  console.error(err);
  return c.json({ error: 'Internal server error' }, 500);
});

app.notFound(c => c.json({ error: 'Not found' }, 404));
```

## Key Rules
- **Export `app` as default** — don't use `app.listen()` for edge runtimes; `app.fetch` is the entry point
- **Type `Variables` and `Bindings`** on the `Hono<{...}>` generic — otherwise `c.get()` and `c.env` are untyped
- **Use `zValidator` for all input validation** — it handles 400 responses and typing automatically
- **Group routes with sub-apps** — `app.route('/prefix', subApp)` keeps files manageable
- **Use built-in middleware** before writing your own — Hono ships CORS, auth, logger, and more
- **`c.req.json()` is async** — always `await` it; skipping await gives you a Promise, not the data
