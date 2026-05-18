# Relational vs Document Database

## The Fundamental Difference

Relational databases (PostgreSQL, MySQL) store data in tables with a fixed schema. Relationships between entities are modeled as foreign keys and resolved with JOINs. The schema is a contract — the database enforces it on every write.

Document databases (MongoDB, Firestore, DynamoDB in document mode) store self-contained JSON-like documents. Each document can have a different shape. There are no JOINs — related data is either embedded in the document or looked up by application code in a separate query.

Both can store the same data. The difference is where the structure is enforced (database vs application) and how related data is accessed (JOINs vs embedding/application-side joins).

## SQL's ACID Guarantee

ACID (Atomicity, Consistency, Isolation, Durability) means:
- A transaction either fully succeeds or fully rolls back — no partial writes
- Foreign key constraints prevent orphaned records
- Concurrent transactions are isolated from each other's uncommitted changes
- Committed data survives crashes

This matters enormously for financial records, inventory systems, booking systems — any domain where a half-written state is worse than a failed operation. If you charge a card and fail to create the order record, that is catastrophic. SQL transactions prevent that class of bug at the database level.

Document databases can provide ACID within a single document. Cross-document transactions exist in MongoDB (4.0+) and Firestore, but they are a retrofit — more complex, with stricter limits than native SQL transactions.

## The JOIN Capability

SQL JOINs let you model your data normalized (no duplication) and reconstruct any view of it with queries. An order system with customers, orders, line items, products, and inventory can be queried as "orders this week by customer, with product names and current inventory" in a single SQL statement.

Document databases require either: (a) embedding all related data in one document (denormalization, which creates update anomalies — changing a product name means updating every order document), or (b) making multiple queries in application code and merging results (slow, complex, not atomic).

Denormalization works for data that is immutable at write time (order history, audit logs). It fails for data that changes and needs to be consistent across references.

## NoSQL's Real Advantages

**Flexible schema**: When the shape of a record varies significantly per instance (CMS content types, user-configurable fields, configuration blobs), a document model is genuinely simpler than a SQL schema with many nullable columns or a JSONB column.

**Horizontal sharding**: Document databases were designed from the ground up for horizontal scaling across many nodes. PostgreSQL can scale vertically and with read replicas, but sharding relational data across nodes requires significant application-level work. For truly massive write throughput (millions of writes per second distributed globally), DynamoDB or Cassandra have architectural advantages.

**Schemaless iteration**: In early-stage products where the data model is changing every week, not needing migrations can accelerate development. This advantage diminishes once the model stabilizes and the lack of schema enforcement becomes a liability (inconsistent shapes, missing fields, type mismatches).

## The Practical Starting Point

PostgreSQL can model anything. It supports JSONB columns for flexible/schemaless data within a relational schema. It can serve document-like access patterns while preserving the option to use SQL for analytics, JOINs, and transactions.

Starting with PostgreSQL means you never hit a wall where you need transactions or complex queries and your database can't provide them. Starting with a document database means you may hit a wall where data consistency or complex relational queries are needed and your architecture resists it.

## When to Migrate to a Specialized Database

Stay on PostgreSQL until you have a concrete, measured reason to leave:
- A time-series database (TimescaleDB as extension, InfluxDB) when query patterns are purely temporal aggregations at scale
- A graph database (Neo4j) when the relationships themselves are the query target (social graph traversal, recommendation engines)
- A document database for content with genuinely unpredictable, highly variable schema
- DynamoDB/Cassandra when you have benchmarked PostgreSQL at your target throughput and it cannot keep up

"We might need to scale" is not a concrete reason. PostgreSQL handles millions of rows and thousands of requests per second without heroics.

## Key Rules

- Default to PostgreSQL for any new project — it handles relational, document (JSONB), and time-series workloads
- Never choose a document database because "it's more flexible" — flexibility in schema is a tradeoff against consistency guarantees
- Any domain involving money, inventory, or bookings requires ACID transactions — do not compromise on this
- Denormalization in a document database is only safe for immutable data; mutable referenced data always causes consistency problems eventually
- Migrate away from PostgreSQL only after profiling shows a concrete bottleneck that a specialized database solves
- If using JSONB columns in PostgreSQL, add GIN indexes on the JSON fields being queried — unindexed JSONB queries are full table scans
