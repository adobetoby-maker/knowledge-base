# Pattern: Audit Log Viewer

## Overview
Audit logs are the chain of custody for your application's state changes. Without them, you can't answer "who deleted that record?" or "what changed that configuration?" They're also required for SOC 2, HIPAA, and similar compliance frameworks. The log must be immutable — if admins can delete entries, the log is worthless as evidence.

## Implementation

### Data Model
```sql
CREATE TABLE audit_log (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type   TEXT NOT NULL,       -- 'user.created', 'invoice.deleted', 'settings.updated'
  actor_id     UUID,                -- NULL for system events
  actor_email  TEXT,                -- denormalized — preserved if actor is deleted
  resource_type TEXT NOT NULL,      -- 'user', 'invoice', 'api_key'
  resource_id  TEXT NOT NULL,       -- the affected record's ID
  changes      JSONB,               -- { field: [oldValue, newValue] }
  metadata     JSONB,               -- ip_address, user_agent, request_id
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- No UPDATE, no DELETE — append only
-- Enforce via DB policy or application layer
```

### Logging Helper
```typescript
async function audit(params: {
  eventType: string;
  actorId?: string;
  actorEmail?: string;
  resourceType: string;
  resourceId: string;
  changes?: Record<string, [unknown, unknown]>; // [before, after]
  metadata?: Record<string, unknown>;
}) {
  // Fire-and-forget with error capture — never block the main operation
  db.auditLog.create(params).catch(err => captureException(err));
}

// Usage
await audit({
  eventType: 'invoice.updated',
  actorId: currentUser.id,
  actorEmail: currentUser.email,
  resourceType: 'invoice',
  resourceId: invoice.id,
  changes: {
    status: ['draft', 'sent'],
    amount: [1000, 1200],
  },
  metadata: { ipAddress: req.ip, requestId: req.headers['x-request-id'] },
});
```

### Audit Log UI
```tsx
function AuditLogViewer() {
  const [filters, setFilters] = useState({
    actorEmail: '',
    resourceType: '',
    dateFrom: '',
    dateTo: '',
  });

  const { data } = useAuditLog(filters);

  return (
    <div>
      <AuditFilters value={filters} onChange={setFilters} />
      <ExportButton filters={filters} />

      {data.events.map(event => (
        <AuditEntry key={event.id} event={event} />
      ))}
    </div>
  );
}

function AuditEntry({ event }) {
  const [expanded, setExpanded] = useState(false);

  return (
    <div className="audit-entry">
      <div className="audit-header" onClick={() => setExpanded(!expanded)}>
        <EventBadge type={event.eventType} />
        <span className="actor">
          {event.actorEmail ?? <em>System</em>}
        </span>
        <span className="resource">
          {event.resourceType} <code>{event.resourceId.slice(0, 8)}...</code>
        </span>
        <time title={event.createdAt}>{formatRelative(event.createdAt)}</time>
        {event.metadata?.ipAddress && (
          <span className="ip">{event.metadata.ipAddress}</span>
        )}
      </div>

      {expanded && event.changes && (
        <ChangeDiff changes={event.changes} />
      )}
    </div>
  );
}

function ChangeDiff({ changes }) {
  return (
    <table className="diff">
      <thead><tr><th>Field</th><th>Before</th><th>After</th></tr></thead>
      <tbody>
        {Object.entries(changes).map(([field, [before, after]]) => (
          <tr key={field}>
            <td>{field}</td>
            <td className="removed">{JSON.stringify(before)}</td>
            <td className="added">{JSON.stringify(after)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
```

### CSV Export
```typescript
async function exportAuditLog(filters: AuditFilters): Promise<Response> {
  const events = await db.auditLog.findMany({ where: buildWhere(filters) });

  const rows = events.map(e => [
    e.createdAt.toISOString(),
    e.eventType,
    e.actorEmail ?? 'system',
    e.resourceType,
    e.resourceId,
    e.metadata?.ipAddress ?? '',
    e.changes ? JSON.stringify(e.changes) : '',
  ]);

  const csv = [
    ['Timestamp', 'Event', 'Actor', 'Resource Type', 'Resource ID', 'IP', 'Changes'],
    ...rows,
  ].map(r => r.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(',')).join('\n');

  return new Response('﻿' + csv, {
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="audit-log-${Date.now()}.csv"`,
    },
  });
}
```

## Key Rules
- Audit log is append-only — no UPDATE, no DELETE — enforce at DB or application layer
- Denormalize actor email at write time — if the actor account is deleted, the log must still show who did it
- Log the diff (before/after), not just "record was updated" — without the diff, the log has no forensic value
- System/automated events use `actorId = null` with a descriptive event type — distinguish from user actions
- Always log IP address and request ID in metadata for security investigations
- Filters must include actor, resource type, and date range at minimum
- Export to CSV for compliance audits — lawyers and auditors don't use your admin panel
- Show "System" for null actors, not blank — blank is confusing
- The viewer UI is read-only — no delete, no edit buttons anywhere on the page
- Capture audit write errors separately — never allow an audit failure to block the primary operation
