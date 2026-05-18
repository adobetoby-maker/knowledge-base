# Express.js + PostgreSQL REST API

## Stack Overview

Express is a minimal Node.js HTTP framework. Combined with the `pg` library (node-postgres) and a connection pool, it is the standard pattern for a Node-based REST API backed by PostgreSQL. This bundle covers the patterns that separate production-ready code from tutorial code: connection pooling, async error handling, Zod validation, JWT middleware, and managed migrations.

## pg Pool Configuration

Never create a new `Client` per request — it opens and closes a TCP connection every time. Use a `Pool` that maintains persistent connections.

```ts
// src/db.ts
import { Pool } from 'pg';

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,                // maximum connections in pool
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 2_000,
});

pool.on('error', (err) => {
  console.error('Unexpected pg pool error', err);
  process.exit(-1);  // pool errors are usually unrecoverable
});
```

For transactions, acquire a client from the pool explicitly:

```ts
const client = await pool.connect();
try {
  await client.query('BEGIN');
  await client.query('INSERT INTO orders ...', [...]);
  await client.query('UPDATE inventory ...', [...]);
  await client.query('COMMIT');
} catch (err) {
  await client.query('ROLLBACK');
  throw err;
} finally {
  client.release();  // always release, even on error
}
```

## Async Error Handling Middleware

Express 4 does not catch async errors by default. An unhandled rejected promise in an async route handler crashes the process. Wrap all async handlers:

```ts
// src/middleware/asyncHandler.ts
import { Request, Response, NextFunction, RequestHandler } from 'express';

export const asyncHandler = (fn: RequestHandler): RequestHandler =>
  (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };

// src/middleware/errorHandler.ts
export function errorHandler(err: any, req: Request, res: Response, next: NextFunction) {
  const status = err.status ?? err.statusCode ?? 500;
  res.status(status).json({
    error: err.message ?? 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
}

// Register last in app.ts
app.use(errorHandler);
```

Usage:
```ts
router.get('/invoices/:id', asyncHandler(async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM invoices WHERE id = $1', [req.params.id]);
  if (!rows[0]) { const err: any = new Error('Not found'); err.status = 404; throw err; }
  res.json(rows[0]);
}));
```

## Zod Request Validation

Validate before touching the database. Zod schemas document the expected shape and throw structured errors that the error handler can format.

```ts
import { z } from 'zod';

const CreateInvoiceSchema = z.object({
  clientId: z.string().uuid(),
  amount: z.number().positive(),
  dueDate: z.string().datetime(),
});

router.post('/invoices', asyncHandler(async (req, res) => {
  const body = CreateInvoiceSchema.parse(req.body);  // throws ZodError on failure
  const { rows } = await pool.query(
    'INSERT INTO invoices (client_id, amount, due_date) VALUES ($1, $2, $3) RETURNING *',
    [body.clientId, body.amount, body.dueDate]
  );
  res.status(201).json(rows[0]);
}));
```

In the error handler, check for `ZodError` and return 422 with the validation issues.

## JWT Auth Middleware

```ts
import jwt from 'jsonwebtoken';

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as { userId: string };
    (req as any).userId = payload.userId;
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}
```

Apply per-router: `router.use(requireAuth)` or per-route as a second argument.

## Database Migrations with node-pg-migrate

`node-pg-migrate` uses JavaScript/TypeScript migration files, runs in the same Node environment, and tracks applied migrations in a `pgmigrations` table.

```bash
npm install node-pg-migrate pg
npx node-pg-migrate create add_invoices_table  # creates migrations/timestamp_add_invoices_table.js
npx node-pg-migrate up                          # apply pending migrations
npx node-pg-migrate down                        # roll back last migration
```

Migration files export `up` and `down` functions. Always implement `down` — it is the only safe way to roll back a deploy.

```ts
export const up = (pgm) => {
  pgm.createTable('invoices', {
    id: { type: 'uuid', primaryKey: true, default: pgm.func('gen_random_uuid()') },
    client_id: { type: 'uuid', notNull: true },
    amount: { type: 'numeric(10,2)', notNull: true },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });
  pgm.addIndex('invoices', 'client_id');
};

export const down = (pgm) => {
  pgm.dropTable('invoices');
};
```

## Key Rules

- **Always use parameterized queries** (`$1, $2`) — never concatenate user input into SQL strings.
- **Always call `client.release()`** in a `finally` block when using pool clients directly — leaked connections exhaust the pool.
- **Register `errorHandler` last** in Express middleware chain — placing it before routes means it never catches route errors.
- **Run migrations before starting the server** in production startup (`npm run migrate && node dist/server.js`).
- Do not store raw passwords — hash with `bcrypt` before INSERT, compare with `bcrypt.compare` on login.
- Use `RETURNING *` in INSERT/UPDATE queries to avoid a second SELECT round-trip for the created/updated row.
