# Disambig: Supabase vs Firebase

## Overview
Supabase and Firebase are both backend-as-a-service platforms but are architecturally opposite. Supabase is PostgreSQL with an API layer—every feature is SQL underneath, and you get the full power of a relational database with joins, transactions, and complex queries. Firebase is a NoSQL document database optimized for real-time sync and offline-first mobile apps. Picking the wrong one creates a painful data modeling mismatch that compounds over time.

## Comparison

| Property | Supabase | Firebase |
|---|---|---|
| Database model | Relational (PostgreSQL) | NoSQL (document / key-value) |
| Queries | Full SQL — joins, aggregates, CTEs | Limited — no joins, no aggregates |
| Schema | Enforced (migrations) | Schemaless (flexible but drift-prone) |
| Relations | Native foreign keys + joins | Denormalize manually or multiple reads |
| Transactions | Full ACID transactions | Limited (batch writes, no cross-collection) |
| Access control | Row-Level Security (SQL policies) | Firestore Security Rules (custom syntax) |
| Real-time | Postgres CDC → WebSocket | Native Firestore/RTDB listeners |
| Auth | Built-in (compatible with any PostgreSQL auth) | Firebase Auth (well-polished) |
| File storage | Supabase Storage (S3-compatible) | Firebase Storage (GCS) |
| Functions | Edge Functions (Deno) | Cloud Functions (Node.js) |
| Offline support | No | Yes (Firestore offline cache) |
| Vendor | Open source, self-hostable | Google (proprietary) |
| Pricing model | Predictable (compute + storage) | Reads/writes/storage (can spike) |

## When to Use Supabase

```
Data with relationships
→ orders belong_to customers belong_to addresses
→ SQL joins are natural; Firebase requires denormalization or 3+ reads per view

Complex queries
→ "Show orders by status, group by week, filter by region, include customer name"
→ Single SQL query in Supabase; impossible without denormalization in Firebase

Financial / transactional data
→ ACID transactions prevent partial writes; critical for accounting, inventory

Existing PostgreSQL knowledge on team
→ No new query language to learn; standard SQL, standard tools

Server-rendered web apps (Next.js)
→ Supabase server client works cleanly in RSC and Route Handlers; no offline needed

Need for complex access control
→ RLS policies are SQL — powerful, auditable, composable

Open source / self-hosting requirement
→ Supabase can be self-hosted on your own PostgreSQL; Firebase cannot
```

## When to Use Firebase

```
Offline-first mobile apps
→ Firestore caches data locally; app works without network; syncs when online

Real-time collaboration where the DB is the source of truth
→ Firestore listeners propagate changes to all clients instantly
→ No separate pub/sub layer needed

Simple, flat data with high read frequency
→ Document model works well for user profiles, settings, simple lists
→ Avoids the "just need CRUD" overhead of schema migrations

React Native / Flutter mobile apps in Google ecosystem
→ Firebase Auth + FCM + Crashlytics + Firestore = batteries-included mobile stack

High-concurrency writes to independent documents
→ Firestore scales writes horizontally; PostgreSQL needs careful sharding at extreme scale

Team exclusively building mobile with no SQL background
→ Firebase's JavaScript SDK and security rules have a gentler learning curve
```

## Data Modeling Contrast

```
// Order with line items — Supabase (natural relational model)
SELECT o.id, o.total, c.name as customer_name,
       json_agg(json_build_object('product', p.name, 'qty', li.quantity)) as items
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN line_items li ON li.order_id = o.id
JOIN products p ON li.product_id = p.id
WHERE o.status = 'pending'
GROUP BY o.id, c.name;

// Same query in Firebase:
// → fetch all orders, then for each order fetch customer, then fetch each line item
// → N+1 queries, client-side joins, or denormalized "orders" documents with embedded items
// → denormalized = update product name → must update every order that has it
```

## Key Rules
- **Relational data → Supabase** — if your data has foreign keys, Supabase wins every time.
- **Offline-first mobile → Firebase** — Supabase has no offline sync story.
- **Financial/transactional data → Supabase** — ACID is non-negotiable for money.
- **Firebase pricing can surprise you** — document reads/writes bill individually; heavy real-time use can spike costs unpredictably.
- **Supabase RLS requires understanding SQL** — `USING (auth.uid() = user_id)` policies are powerful but can be misconfigured silently.
- **Don't mix them** — running Supabase for some data and Firebase for other data in the same app creates two auth systems and two billing accounts with no benefit.
