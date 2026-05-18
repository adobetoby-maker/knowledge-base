# Review: Data Model Review

## Overview
Data model decisions are expensive to reverse. A missing index requires a migration. A missing foreign key means orphaned rows accumulate silently. A bad normalization decision means either data inconsistency or complex queries forever. Data model reviews are highest-value when they happen before the schema is created, and highest-cost when they happen after millions of rows exist.

## Implementation / Key Points

### Foreign Keys with Indexes
```sql
-- Bad: FK declared but no index on the referencing column
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer 
  FOREIGN KEY (customer_id) REFERENCES customers(id);

-- Good: index the FK column
ALTER TABLE orders ADD COLUMN customer_id UUID NOT NULL
  REFERENCES customers(id);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
```
Most databases (PostgreSQL, MySQL) don't automatically create an index on the referencing column. Without it, queries filtering on `customer_id` do sequential scans. FK violation checks also scan without the index.

### Many-to-Many via Junction Table
```sql
-- Bad: storing arrays of IDs as text or JSONB
CREATE TABLE courses (
  id UUID PRIMARY KEY,
  student_ids TEXT[]  -- don't do this
);

-- Good: junction table
CREATE TABLE course_enrollments (
  course_id UUID REFERENCES courses(id),
  student_id UUID REFERENCES students(id),
  enrolled_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (course_id, student_id)
);
CREATE INDEX idx_enrollments_student ON course_enrollments(student_id);
```
Array-of-IDs breaks foreign key constraints, makes JOINs impossible, and requires array containment operators for filtering.

### Enum Columns with Constraints
```sql
-- Option 1: PostgreSQL native enum (schema change to add values)
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled');
CREATE TABLE orders (status order_status NOT NULL DEFAULT 'pending');

-- Option 2: CHECK constraint (easier to extend)
CREATE TABLE orders (
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled'))
);
```
Unconstrained text columns for status fields accumulate typos and invalid states. Pick either native enum or check constraint; don't leave status as unconstrained text.

### Timestamps on All Tables
```sql
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- ... columns ...
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```
Without timestamps: debugging is impossible (when did this happen?), sync/cache invalidation has no signal, audit trails don't exist.

### Soft Delete vs Archive Strategy
```sql
-- Soft delete: add deleted_at, filter it everywhere
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;
-- Every query must include: WHERE deleted_at IS NULL
-- Partial index helps: CREATE INDEX idx_users_active ON users(id) WHERE deleted_at IS NULL;

-- Archive: move rows to archive table
-- Cleaner queries, harder to restore, requires archive table maintenance
```
Decide and document the strategy before building. Soft delete pollutes queries; archive requires more maintenance. Neither is universally correct.

### Cascade Delete Implications
```sql
-- Review every ON DELETE clause carefully
CREATE TABLE order_items (
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,  -- deleting order deletes items ✓
  product_id UUID REFERENCES products(id) ON DELETE RESTRICT  -- can't delete product with orders ✓
);
```
`ON DELETE CASCADE` is appropriate for child records that have no meaning without the parent. `RESTRICT` prevents deleting a parent that has dependent children. Default (no clause) = `RESTRICT`. Never use `CASCADE` on junction tables linking to "permanent" records.

### Denormalization Decisions — Document Them
```sql
-- users.order_count is denormalized (also computable from COUNT on orders)
-- Reason: hot path in dashboard, orders table too large for count query
-- Consistency: maintained by trigger on order INSERT/DELETE
-- Review: if inconsistency found, orders table is source of truth
COMMENT ON COLUMN users.order_count IS 
  'Denormalized: updated by trigger. Source of truth: COUNT(orders) WHERE user_id=id';
```

### Data Model Review Checklist
- [ ] Every FK column has an index on the referencing side
- [ ] Many-to-many uses junction table, not array of IDs
- [ ] Status/type columns have CHECK constraint or native enum
- [ ] `created_at`, `updated_at` timestamps on every table
- [ ] CASCADE/RESTRICT decisions documented and reviewed
- [ ] Soft delete vs archive strategy decided and documented
- [ ] Denormalized columns have a comment explaining the source of truth
- [ ] No unbounded TEXT columns where domain is constrained

## Key Rules
- FK indexes are not automatic in PostgreSQL — always add an index on the referencing column
- Arrays of IDs in a column are not a many-to-many relationship — they're a denormalization that breaks referential integrity
- Every table must have `created_at` and `updated_at` — without them, debugging production issues becomes guesswork
- Document the rationale for every denormalization decision as a column comment in the migration
- Cascade deletes are powerful and dangerous — review every `ON DELETE CASCADE` for unintended consequences
