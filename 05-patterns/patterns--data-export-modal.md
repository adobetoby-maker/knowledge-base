# Pattern: Data Export Modal

## Overview
A data export flow is user-initiated, potentially long-running, and must handle large datasets without blocking the UI or timing out HTTP connections. The modal serves as the configuration step; the actual export runs asynchronously. Small exports (< 10k rows) can stream directly as a download. Large exports must be emailed or made available via a polling link — holding a browser tab open for 10 minutes is not a viable UX.

## Implementation

### Modal State Machine
```
idle → configuring → validating (checking row count) → processing → complete | error
```

### Configuration Form
```tsx
interface ExportConfig {
  format: 'csv' | 'json' | 'xlsx';
  dateRange: 'all' | '30d' | '90d' | 'custom';
  customStart?: string;
  customEnd?: string;
  fields: string[];   // selected column IDs
}

const ALL_FIELDS = [
  { id: 'id', label: 'ID' },
  { id: 'name', label: 'Name' },
  { id: 'email', label: 'Email' },
  { id: 'created_at', label: 'Created At' },
  { id: 'status', label: 'Status' },
];

function ExportModal({ onClose }: { onClose: () => void }) {
  const [config, setConfig] = useState<ExportConfig>({
    format: 'csv',
    dateRange: 'all',
    fields: ALL_FIELDS.map(f => f.id),
  });
  const [rowEstimate, setRowEstimate] = useState<number | null>(null);
  const [phase, setPhase] = useState<'config' | 'processing' | 'done' | 'error'>('config');
  const [downloadUrl, setDownloadUrl] = useState<string | null>(null);
  const [progress, setProgress] = useState(0);

  // Fetch row estimate when config changes
  useEffect(() => {
    const abort = new AbortController();
    fetchRowCount(config, abort.signal).then(setRowEstimate).catch(() => {});
    return () => abort.abort();
  }, [config.dateRange, config.customStart, config.customEnd]);

  const handleExport = async () => {
    setPhase('processing');
    const isLarge = (rowEstimate ?? 0) > 50_000;

    if (isLarge) {
      // Email delivery for large exports
      await triggerEmailExport(config);
      setPhase('done');
    } else {
      // Streaming download
      try {
        const url = await streamingExport(config, p => setProgress(p));
        setDownloadUrl(url);
        setPhase('done');
        triggerDownload(url, `export.${config.format}`);
      } catch {
        setPhase('error');
      }
    }
  };
  // ...
}
```

### Large Export: Email Delivery
```ts
// Server: POST /api/exports
async function POST(req: Request) {
  const config = await req.json();
  const jobId = await queueExportJob(config, session.userId);
  // Job runs in background, emails download link on completion
  return Response.json({ jobId, delivery: 'email' });
}
```

Show the user: "Your export is being prepared. You'll receive an email with the download link within a few minutes."

### Small Export: Streaming Response
```ts
// Server: GET /api/exports/stream?config=...
async function GET(req: Request) {
  const config = parseConfig(req);
  const rows = await fetchRows(config);

  if (config.format === 'csv') {
    const csv = rowsToCSV(rows, config.fields);
    return new Response(csv, {
      headers: {
        'Content-Type': 'text/csv',
        'Content-Disposition': `attachment; filename="export_${Date.now()}.csv"`,
      },
    });
  }

  if (config.format === 'xlsx') {
    const buffer = await generateXLSX(rows, config.fields);
    return new Response(buffer, {
      headers: {
        'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'Content-Disposition': `attachment; filename="export_${Date.now()}.xlsx"`,
      },
    });
  }
}
```

### Field Selection UX
```tsx
<fieldset>
  <legend>Include fields</legend>
  <label>
    <input
      type="checkbox"
      checked={config.fields.length === ALL_FIELDS.length}
      onChange={e => setConfig(c => ({
        ...c,
        fields: e.target.checked ? ALL_FIELDS.map(f => f.id) : [],
      }))}
    />
    Select all
  </label>
  {ALL_FIELDS.map(f => (
    <label key={f.id}>
      <input
        type="checkbox"
        checked={config.fields.includes(f.id)}
        onChange={e => setConfig(c => ({
          ...c,
          fields: e.target.checked
            ? [...c.fields, f.id]
            : c.fields.filter(id => id !== f.id),
        }))}
      />
      {f.label}
    </label>
  ))}
</fieldset>
```

## Key Rules
- Always fetch row estimate before starting export — show it as "~12,450 rows" so users know what to expect.
- Threshold for email delivery vs streaming: 50k rows or 10 MB estimated size.
- Never leave the user with only a progress bar and no ETA for large exports — switch to "email delivery" flow and let them close the modal.
- `Content-Disposition: attachment` is required for browser download — without it, the browser may render the response inline.
- Include a timestamp in the filename — prevents confusion when users export multiple times.
- The download link generated for email delivery must expire (1 hour, presigned S3/R2 URL).
- Fields selected but not available (e.g., user deleted columns) must be silently omitted, not error.
