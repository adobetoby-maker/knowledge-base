# Stack Bundle: Express + TypeScript

## Overview
Express was designed for JavaScript without types, so using it with TypeScript requires deliberate
type augmentation. The default `Request` and `Response` types are loose — tightening them at the
right level (middleware, route handler, custom interface) prevents runtime errors that TypeScript
would otherwise catch.

## Implementation

### Typed Request/Response with Custom Interface
```ts
// types/express.d.ts — augment the global Express namespace
declare global {
  namespace Express {
    interface Request {
      user?: { id: string; email: string; role: 'admin' | 'user' };
    }
  }
}

// In a typed route handler
import { Request, Response, NextFunction } from 'express';

interface CreatePostBody {
  title: string;
  content: string;
}

app.post('/posts', (req: Request<{}, {}, CreatePostBody>, res: Response) => {
  const { title, content } = req.body;  // fully typed
  res.status(201).json({ id: '1', title, content });
});
// Generic params: Request<Params, ResBody, ReqBody, Query>
```

### Middleware Chain Typing
```ts
// Auth middleware — sets req.user
export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    res.status(401).json({ error: 'Unauthorized' });
    return;  // must return void, not return res.json(...)
  }
  try {
    req.user = verifyToken(token);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}
```

### Error Handler Middleware (4 Params — Required)
```ts
// Express detects error handlers by arity — MUST have exactly 4 parameters
// Placing this LAST in the middleware chain is critical
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error(err.stack);

  if (err instanceof ValidationError) {
    return res.status(400).json({ error: err.message, issues: err.issues });
  }

  if (err instanceof NotFoundError) {
    return res.status(404).json({ error: err.message });
  }

  // Unhandled errors become 500
  res.status(500).json({ error: 'Internal server error' });
});
```

### express-async-errors for Async Error Propagation
```ts
// Without express-async-errors, async errors bypass the error handler:
app.get('/users/:id', async (req, res) => {
  const user = await db.findUser(req.params.id);  // if this throws, Express hangs
  res.json(user);
});

// Fix: import 'express-async-errors' BEFORE defining routes
import 'express-async-errors';  // patches Express to forward async errors automatically

// Now async throws reach the error handler:
app.get('/users/:id', async (req, res) => {
  const user = await db.findUser(req.params.id);  // throws → goes to error handler
  res.json(user);
});
```

### Zod for Request Validation
```ts
import { z } from 'zod';

const CreateUserSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

// Reusable validation middleware
function validate(schema: z.AnyZodObject) {
  return (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse({
      body: req.body,
      params: req.params,
      query: req.query,
    });
    if (!result.success) {
      return res.status(400).json({ error: result.error.flatten() });
    }
    Object.assign(req, result.data);  // replace with parsed/coerced values
    next();
  };
}

app.post('/users', validate(CreateUserSchema), async (req, res) => {
  // req.body is now validated
});
```

### Jest + Supertest for Testing
```ts
// app.ts — export app without calling listen()
export const app = express();
// routes...

// app.test.ts
import request from 'supertest';
import { app } from '../app';
import { db } from '../db';

afterEach(async () => {
  await db.cleanup();  // reset test data
});

test('POST /users creates user', async () => {
  const res = await request(app)
    .post('/users')
    .send({ email: 'test@test.com', password: 'password123' });

  expect(res.status).toBe(201);
  expect(res.body).toMatchObject({ email: 'test@test.com' });
  expect(res.body).not.toHaveProperty('password');  // never expose password
});
```

## Key Rules
- Error handler middleware must have exactly 4 parameters — Express checks by `fn.length`, not by convention
- Import `express-async-errors` before any route definitions or async errors will be silently swallowed
- Never call `next(err)` inside the error handler itself — it creates infinite loops
- Augment `Express.Request` globally for properties set by middleware (user, session) — don't use `as any`
- Export `app` without calling `.listen()` so tests can import it without binding a port
- Use `express.json()` middleware explicitly — it is not included by default
- Route param validation belongs in Zod schema, not in route handler logic
