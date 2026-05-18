# Skill: Deterministic Database Seeding

## Overview
Seed data that generates random IDs on every run causes cascading test failures when IDs change, blocks team members who rely on specific test accounts, and makes debugging "works on my machine" impossible. Deterministic seeds — same data every time — make your dev environment reproducible and trustworthy. The reset+seed command is your single source of truth for starting from scratch.

## Implementation

### 1. Seed file with fixed IDs
```ts
// scripts/seed.ts
import { db } from '../lib/db';

// Fixed UUIDs — never generate randomly in seed files
const SEED_IDS = {
  adminUser:    '00000000-0000-0000-0000-000000000001',
  regularUser:  '00000000-0000-0000-0000-000000000002',
  premiumUser:  '00000000-0000-0000-0000-000000000003',
  org1:         '10000000-0000-0000-0000-000000000001',
  org2:         '10000000-0000-0000-0000-000000000002',
  // Pattern: leading zeros + semantic number — easy to remember in tests
};

async function seed() {
  console.log('Seeding database...');

  // Order matters — respect foreign key constraints
  await seedUsers();
  await seedOrgs();
  await seedMemberships();
  await seedProducts();
  await seedOrders();

  console.log('Seed complete');
}

async function seedUsers() {
  await db.user.upsert({
    where: { id: SEED_IDS.adminUser },
    update: {},  // don't overwrite if exists — preserves auth changes
    create: {
      id: SEED_IDS.adminUser,
      email: 'admin@example.com',
      name: 'Admin User',
      role: 'admin',
    },
  });

  await db.user.upsert({
    where: { id: SEED_IDS.regularUser },
    update: {},
    create: {
      id: SEED_IDS.regularUser,
      email: 'user@example.com',
      name: 'Regular User',
      role: 'user',
    },
  });
}
```

### 2. Reset + seed as one command
```ts
// scripts/reset-and-seed.ts
async function resetAndSeed() {
  // Fail loudly if not in dev
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Never run seed in production');
  }
  if (!process.env.DATABASE_URL?.includes('localhost') &&
      !process.env.DATABASE_URL?.includes('local')) {
    throw new Error('DATABASE_URL does not look like a local DB. Aborting.');
  }

  // Run migration reset with prisma CLI
  const { execFileSync } = await import('child_process');
  execFileSync('npx', ['prisma', 'migrate', 'reset', '--force', '--skip-seed'], {
    stdio: 'inherit',
    env: process.env,
  });

  await import('./seed');
}

resetAndSeed().catch(console.error);
```

```json
// package.json
{
  "scripts": {
    "db:seed": "tsx scripts/seed.ts",
    "db:reset": "tsx scripts/reset-and-seed.ts"
  }
}
```

### 3. Cover all enum values and edge cases
```ts
async function seedOrders() {
  const statuses = ['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded'];

  // One order per status — every enum value covered in dev data
  for (let i = 0; i < statuses.length; i++) {
    const paddedIndex = String(i + 1).padStart(12, '0');
    await db.order.upsert({
      where: { id: `20000000-0000-0000-0000-${paddedIndex}` },
      update: {},
      create: {
        id: `20000000-0000-0000-0000-${paddedIndex}`,
        userId: SEED_IDS.regularUser,
        status: statuses[i],
        totalCents: (i + 1) * 1000,
      },
    });
  }

  // Edge cases: large order with discount
  await db.order.upsert({
    where: { id: '20000000-0000-0000-0000-000000000099' },
    update: {},
    create: {
      id: '20000000-0000-0000-0000-000000000099',
      userId: SEED_IDS.premiumUser,
      status: 'delivered',
      totalCents: 99999,   // large amount — tests formatting
      discountCents: 10000,
    },
  });
}
```

### 4. Separate dev seed vs test fixtures
```ts
// tests/fixtures/users.ts — for unit/integration tests, not dev env
export const testUsers = {
  admin: {
    id: 'test-admin-000',
    email: 'admin@test.local',
    role: 'admin' as const,
  },
};

// Use in tests — create/cleanup per test, not persistent
beforeEach(async () => {
  await db.user.create({ data: testUsers.admin });
});
afterEach(async () => {
  await db.user.deleteMany({ where: { email: { endsWith: '@test.local' } } });
});
```

### 5. Export constants for test use
```ts
// scripts/seed.ts — export so tests can reference without magic strings
export { SEED_IDS };

// In tests
import { SEED_IDS } from '../scripts/seed';
const res = await getUser(SEED_IDS.adminUser);
expect(res.role).toBe('admin');
```

## Key Rules
- **Never use `Math.random()` or `new Date()` in seed files** — generates different data every run, making tests non-deterministic.
- **Use `upsert` not `create`** — idempotent seeds can be re-run without errors when data already exists.
- **Guard against production** — check `NODE_ENV` and `DATABASE_URL` at the top of reset scripts; throw before any DB operation.
- Seed covers every enum value — if your app has `status: 'refunded'`, there must be a refunded order in seed data.
- Include known edge cases (empty state, maximum values, long strings) — edge cases only get caught if they exist in dev data.
- Export `SEED_IDS` from seed file — tests can use these constants to write assertions without hardcoding magic strings.
- Run seed in CI against a fresh DB to catch FK constraint violations early — they're easy to miss locally.
- Dev seed and test fixtures serve different purposes — dev seed is persistent state for manual testing; test fixtures are ephemeral per-test.
