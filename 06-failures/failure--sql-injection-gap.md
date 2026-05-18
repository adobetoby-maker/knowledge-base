# failure--sql-injection-gap.md

Parameterized queries prevent classic SQL injection, but they don't prevent every injection vector. Developers who correctly use parameterization often develop false confidence and miss the cases where parameterization doesn't apply or isn't used under the hood.

## String Interpolation in Queries — Never

The root cause of classic SQL injection is constructing query strings by concatenating user input:

```ts
// Never do this
const query = `SELECT * FROM users WHERE name = '${userInput}'`;
```

Input like `' OR '1'='1` terminates the string and appends a condition. Parameterized queries prevent this by separating data from SQL structure:

```ts
// Parameterized — the database treats userInput as a value, not SQL
db.query('SELECT * FROM users WHERE name = $1', [userInput]);
```

This is table stakes. Every query that incorporates external data must use parameters.

## ORM `raw()` Re-Introduces Injection

ORMs provide escape hatches for complex queries: Prisma's `$queryRaw`, Sequelize's `query()`, Drizzle's `sql` template tag. These bypass the ORM's parameterization and directly interpolate strings unless you use them correctly.

```ts
// Unsafe — userInput is interpolated into the SQL
prisma.$queryRaw`SELECT * FROM users WHERE name = '${userInput}'`

// Safe — Prisma's sql tag handles parameterization
import { sql } from '@prisma/client';
prisma.$queryRaw(sql`SELECT * FROM users WHERE name = ${userInput}`)
```

The syntax looks similar but behaves very differently. Read your ORM's documentation for the correct parameterization pattern in raw queries — it's not always obvious and varies by library.

## LIKE Wildcards and Parameterization

Parameterization prevents injection but does not prevent `LIKE` wildcard abuse. A parameterized `LIKE '%${searchTerm}%'` still lets users search `%` or `_` as wildcards, turning `"a%b%c%d%e"` into a catastrophically slow pattern match.

Escape wildcards in the search term before parameterizing:

```ts
const escaped = searchTerm.replace(/%/g, '\\%').replace(/_/g, '\\_');
db.query('SELECT * FROM products WHERE name LIKE $1 ESCAPE \'\\\'', [`%${escaped}%`]);
```

Without this, a malicious search term can cause full-table scans with regex-like complexity.

## Second-Order Injection

First-order injection happens when user input is put directly into a query. Second-order injection happens when user input is safely stored in the database, then later retrieved and concatenated into another query without escaping.

The stored input looks safe because it was parameterized on the way in. The vulnerability appears in the code that reads it back and uses it unsafely. The fix is to treat any value retrieved from the database as untrusted if it will be used in a subsequent query — parameterize on every use, not just on insert.

## Column and Table Names Cannot Be Parameterized

SQL parameters only work for values, not identifiers (table names, column names, operators). If a table or column name comes from user input, parameterization can't help:

```ts
// This doesn't work — parameters don't apply to identifiers
db.query('SELECT * FROM $1 WHERE $2 = $3', [tableName, columnName, value]);
```

Identifiers must be validated against an allowlist of known-safe names. Never construct dynamic table or column names from user input without an explicit allowlist check:

```ts
const ALLOWED_COLUMNS = ['created_at', 'name', 'status'] as const;
if (!ALLOWED_COLUMNS.includes(sortColumn)) throw new Error('Invalid column');
db.query(`SELECT * FROM items ORDER BY ${sortColumn}`); // safe — validated against allowlist
```

## Key Rules

- Never interpolate user input into SQL strings; use parameterized queries without exception.
- ORM raw query helpers bypass parameterization unless you use the library's specific parameterization API — read the docs.
- Parameterization does not escape LIKE wildcards — escape `%` and `_` before using user input in LIKE patterns.
- Second-order injection: treat database-retrieved values as untrusted when building new queries.
- Table and column names cannot be parameterized — validate against an explicit allowlist.
