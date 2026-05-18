# Pattern: Public Service Status Page

A status page showing service health, incident timeline, and computed uptime. Covers status indicator states, incident log, email/RSS subscription, and uptime calculation.

## Status Model

Services can be in one of four states. Model them as a discriminated union so TypeScript enforces exhaustive handling.

```tsx
type ServiceStatus = 'operational' | 'degraded' | 'partial_outage' | 'major_outage';

type Service = {
  id: string;
  name: string;
  description: string;
  status: ServiceStatus;
  uptimeRecords: UptimeRecord[]; // 90 days of daily records
};

type Incident = {
  id: string;
  title: string;
  status: 'investigating' | 'identified' | 'monitoring' | 'resolved';
  severity: 'minor' | 'major' | 'critical';
  affectedServices: string[];
  updates: IncidentUpdate[];
  createdAt: string;
  resolvedAt?: string;
};
```

## Status Indicator Component

```tsx
const STATUS_CONFIG: Record<ServiceStatus, { label: string; color: string; dotClass: string }> = {
  operational:    { label: 'Operational',    color: 'text-green-700',  dotClass: 'bg-green-500' },
  degraded:       { label: 'Degraded',       color: 'text-yellow-700', dotClass: 'bg-yellow-500 animate-pulse' },
  partial_outage: { label: 'Partial Outage', color: 'text-orange-700', dotClass: 'bg-orange-500 animate-pulse' },
  major_outage:   { label: 'Major Outage',   color: 'text-red-700',    dotClass: 'bg-red-500 animate-pulse' },
};

function StatusBadge({ status }: { status: ServiceStatus }) {
  const config = STATUS_CONFIG[status];
  return (
    <span className={cn('flex items-center gap-2 text-sm font-medium', config.color)}>
      <span className={cn('w-2 h-2 rounded-full', config.dotClass)} />
      {config.label}
    </span>
  );
}
```

Pulse animation on non-operational states creates a sense of active monitoring rather than a static label.

## Overall System Status Banner

Derive overall status from the worst individual service:

```tsx
function getOverallStatus(services: Service[]): ServiceStatus {
  if (services.some(s => s.status === 'major_outage')) return 'major_outage';
  if (services.some(s => s.status === 'partial_outage')) return 'partial_outage';
  if (services.some(s => s.status === 'degraded')) return 'degraded';
  return 'operational';
}

function SystemStatusBanner({ status }: { status: ServiceStatus }) {
  const isHealthy = status === 'operational';
  return (
    <div className={cn(
      'rounded-xl p-6 text-center',
      isHealthy ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'
    )}>
      <StatusBadge status={status} />
      <p className={cn('mt-1 text-sm', isHealthy ? 'text-green-700' : 'text-red-700')}>
        {isHealthy
          ? 'All systems operational'
          : 'Some services are experiencing issues'
        }
      </p>
    </div>
  );
}
```

## Computed Uptime Percentage

Display a 90-day uptime bar (GitHub-style) and compute percentage:

```tsx
function UptimeBar({ records }: { records: UptimeRecord[] }) {
  const last90 = records.slice(-90);
  const uptimePct = (last90.filter(r => r.status === 'operational').length / last90.length * 100).toFixed(2);

  return (
    <div className="space-y-1">
      <div className="flex gap-0.5">
        {last90.map((record, i) => (
          <Tooltip key={i} content={`${record.date}: ${record.status}`}>
            <div className={cn(
              'h-8 flex-1 rounded-sm cursor-pointer',
              record.status === 'operational' ? 'bg-green-500' :
              record.status === 'degraded' ? 'bg-yellow-500' :
              'bg-red-500'
            )} />
          </Tooltip>
        ))}
      </div>
      <div className="flex justify-between text-xs text-muted-foreground">
        <span>90 days ago</span>
        <span>{uptimePct}% uptime</span>
        <span>Today</span>
      </div>
    </div>
  );
}
```

Always show "90 days" not just a percentage — a single number hides recent vs historical patterns.

## Incident Timeline

```tsx
function IncidentTimeline({ incident }: { incident: Incident }) {
  return (
    <div className="border rounded-lg p-5 space-y-4">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h3 className="font-semibold">{incident.title}</h3>
          <p className="text-sm text-muted-foreground">
            Affected: {incident.affectedServices.join(', ')}
          </p>
        </div>
        <IncidentStatusBadge status={incident.status} />
      </div>

      <div className="space-y-3 border-l-2 border-muted pl-4">
        {incident.updates.map(update => (
          <div key={update.id}>
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <span className="font-medium capitalize">{update.status}</span>
              <span>·</span>
              <time dateTime={update.createdAt}>{formatRelative(update.createdAt)}</time>
            </div>
            <p className="text-sm mt-1">{update.body}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
```

## Subscription to Updates

Provide RSS and email subscription. Email subscription just saves to your database and sends on incident create/update.

```tsx
<div className="flex gap-2">
  <Button variant="outline" size="sm" asChild>
    <a href="/status/rss.xml" type="application/rss+xml">
      <RssIcon size={14} className="mr-2" />
      Subscribe via RSS
    </a>
  </Button>
  <SubscribeEmailButton />
</div>
```

RSS is the easiest subscription mechanism — a static `rss.xml` regenerated on each incident update. Email requires a database and sending service.

## Key Rules

- Model status as four discrete states; `degraded` and `partial_outage` are distinct (performance vs availability)
- Derive overall status by taking the worst individual service — never manually set it
- Show 90-day bars, not just a percentage — bars reveal patterns; percentages hide them
- Pulse animation on non-operational dots signals active status, not a stale snapshot
- Include `<time dateTime="ISO-string">` on all incident timestamps for machine readability and screen readers
- Always show incident updates in reverse chronological order (newest first)
