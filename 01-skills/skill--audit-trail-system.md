# Skill: Comprehensive Audit Trail System

## Overview
An audit trail answers the question "who did what, to what, when, and from where?" It must be tamper-evident (append-only), complete (captures all changes, not just application-layer events), and queryable (useful for compliance reviews and debugging). Application-layer logging (writing to an audit table in app code) misses changes made directly via SQL, migrations, or admin scripts. Trigger-based logging at the database layer captures everything, regardless of how the change was made.

## Implementation

### Audit Log Table Schema
```sql
CREATE TABLE audit_log (
  id            BIGSERIAL PRIMARY KEY,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- What changed
  table_name    TEXT NOT NULL,
  record_id     TEXT NOT NULL,       -- the PK of the changed row (cast to text)
  operation     TEXT NOT NULL,       -- INSERT | UPDATE | DELETE

  -- Before/after state
  old_data      JSONB,               -- NULL for INSERT
  new_data      JSONB,               -- NULL for DELETE
  changed_keys  TEXT[],              -- keys that actually changed (for UPDATE)

  -- Who did it
  actor_id      TEXT,                -- user_id, service name, or null for system
  actor_ip      INET,
  actor_ua      TEXT,                -- user-agent for browser actions
  app_context   JSONB                -- request_id, session_id, etc.
);

-- Append-only: revoke UPDATE and DELETE on this table for application role
REVOKE UPDATE, DELETE ON audit_log FROM app_user;

-- Indexes for common queries
CREATE INDEX ON audit_log (table_name, record_id, created_at DESC);
CREATE INDEX ON audit_log (actor_id, created_at DESC);
CREATE INDEX ON audit_log (created_at DESC);
```

### Postgres Trigger Function
```sql
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_old_data JSONB;
  v_new_data JSONB;
  v_changed  TEXT[];
  v_record_id TEXT;
BEGIN
  -- Capture old/new as JSONB
  IF TG_OP = 'INSERT' THEN
    v_new_data := to_jsonb(NEW);
    v_record_id := NEW.id::text;
  ELSIF TG_OP = 'UPDATE' THEN
    v_old_data := to_jsonb(OLD);
    v_new_data := to_jsonb(NEW);
    v_record_id := NEW.id::text;
    -- Compute changed keys
    SELECT array_agg(key)
    INTO v_changed
    FROM jsonb_each(v_old_data) o
    WHERE o.value IS DISTINCT FROM (v_new_data -> o.key);
  ELSIF TG_OP = 'DELETE' THEN
    v_old_data := to_jsonb(OLD);
    v_record_id := OLD.id::text;
  END IF;

  INSERT INTO audit_log (
    table_name, record_id, operation,
    old_data, new_data, changed_keys,
    actor_id, actor_ip, actor_ua, app_context
  ) VALUES (
    TG_TABLE_NAME, v_record_id, TG_OP,
    v_old_data, v_new_data, v_changed,
    current_setting('app.actor_id',     true),
    current_setting('app.actor_ip',     true)::inet,
    current_setting('app.actor_ua',     true),
    current_setting('app.context',      true)::jsonb
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;
```

### Attaching the Trigger
```sql
-- Attach to any table that needs auditing
CREATE TRIGGER audit_users
  AFTER INSERT OR UPDATE OR DELETE ON users
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

CREATE TRIGGER audit_invoices
  AFTER INSERT OR UPDATE OR DELETE ON invoices
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();
```

### Setting Actor Context per Request
```ts
// In your database connection/transaction setup:
export async function withAuditContext(
  db: Pool,
  actor: { id?: string; ip?: string; ua?: string; requestId?: string },
  fn: (client: PoolClient) => Promise<void>
) {
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    // Set session-local variables that the trigger reads
    await client.query(`
      SELECT
        set_config('app.actor_id',  $1, true),
        set_config('app.actor_ip',  $2, true),
        set_config('app.actor_ua',  $3, true),
        set_config('app.context',   $4, true)
    `, [
      actor.id ?? '',
      actor.ip ?? '',
      actor.ua ?? '',
      JSON.stringify({ requestId: actor.requestId }),
    ]);
    await fn(client);
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
```

### Querying the Audit Log
```ts
// All changes to a specific record
export async function getRecordHistory(tableName: string, recordId: string) {
  return db.query(`
    SELECT
      id, created_at, operation,
      old_data, new_data, changed_keys,
      actor_id, actor_ip
    FROM audit_log
    WHERE table_name = $1 AND record_id = $2
    ORDER BY created_at DESC
  `, [tableName, recordId]);
}

// All actions by a specific user
export async function getUserActivity(actorId: string, limit = 50) {
  return db.query(`
    SELECT table_name, record_id, operation, created_at, new_data
    FROM audit_log
    WHERE actor_id = $1
    ORDER BY created_at DESC
    LIMIT $2
  `, [actorId, limit]);
}
```

## Key Rules
- Trigger-based logging at the DB level captures all changes including direct SQL — application-layer-only logging has gaps.
- The audit table must be append-only: revoke UPDATE and DELETE on the audit table from the application database user.
- Store full before/after JSONB snapshots, not just the changed field — this enables point-in-time reconstruction.
- Use `current_setting('app.actor_id', true)` in the trigger — the `true` parameter means "don't error if not set."
- Never store sensitive fields (passwords, tokens, SSNs) in old_data/new_data — exclude them in the trigger or encrypt before storage.
- Index `(table_name, record_id, created_at DESC)` — the most common query is "give me the history of this specific record."
- For RLS: users should see only their own audit entries (actor_id = current_user); admins see all. Never allow users to see the audit trail of other users' records.
