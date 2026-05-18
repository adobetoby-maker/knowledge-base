# Pattern: CSV Export Download

## Overview
Client-side CSV generation fails on large datasets (browser memory limits), produces broken Excel files (encoding), and can't include server-only data. Streaming from the server handles arbitrarily large exports, the UTF-8 BOM fixes Excel's tendency to garble non-ASCII characters, and the correct Content-Disposition header ensures the browser downloads rather than displays the file.

## Implementation

### Server: Streaming CSV Response
```typescript
// Route handler — streams rows as they're fetched
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const filters = parseFilters(searchParams);

  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();

      // UTF-8 BOM — required for Excel to open without garbling UTF-8
      controller.enqueue(encoder.encode('﻿'));

      // Header row
      const headers = ['ID', 'Email', 'Name', 'Created At', 'Status'];
      controller.enqueue(encoder.encode(toCsvRow(headers) + '\n'));

      // Stream rows in chunks — don't load all into memory
      let cursor: string | undefined;
      do {
        const rows = await db.users.findMany({
          where: buildWhere(filters),
          orderBy: { createdAt: 'asc' },
          take: 500,
          cursor: cursor ? { id: cursor } : undefined,
          skip: cursor ? 1 : 0,
        });

        for (const row of rows) {
          const csvRow = toCsvRow([
            row.id,
            row.email,
            row.name,
            row.createdAt.toISOString(), // ISO 8601 — not locale-dependent
            row.status,
          ]);
          controller.enqueue(encoder.encode(csvRow + '\n'));
        }

        cursor = rows.length === 500 ? rows[rows.length - 1].id : undefined;
      } while (cursor);

      controller.close();
    },
  });

  const filename = `users-export-${new Date().toISOString().slice(0, 10)}.csv`;

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Cache-Control': 'no-store',
      'Transfer-Encoding': 'chunked',
    },
  });
}
```

### CSV Escaping
```typescript
function toCsvRow(fields: (string | number | null | undefined)[]): string {
  return fields
    .map(field => {
      if (field === null || field === undefined) return '';
      const str = String(field);
      // Escape if contains comma, quote, or newline
      if (str.includes(',') || str.includes('"') || str.includes('\n') || str.includes('\r')) {
        return `"${str.replace(/"/g, '""')}"`; // double-quote escaping per RFC 4180
      }
      return str;
    })
    .join(',');
}
```

### Client: Export Button
```tsx
function ExportButton({ filters }: { filters: ExportFilters }) {
  const [exporting, setExporting] = useState(false);

  const handleExport = async () => {
    setExporting(true);
    try {
      const params = new URLSearchParams(filters);
      const response = await fetch(`/api/export/users?${params}`);
      if (!response.ok) throw new Error('Export failed');

      // Stream to download — works for large files without buffering in JS
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `users-export-${new Date().toISOString().slice(0, 10)}.csv`;
      a.click();
      URL.revokeObjectURL(url);
    } finally {
      setExporting(false);
    }
  };

  return (
    <button onClick={handleExport} disabled={exporting}>
      {exporting ? 'Exporting...' : 'Export CSV'}
    </button>
  );
}
```

### Background Export for Large Datasets
```typescript
// For exports > 100k rows — queue a job, email the link
async function requestLargeExport(userId: string, filters: ExportFilters) {
  const jobId = await exportQueue.add({ userId, filters });
  return { jobId, message: 'Your export is being prepared. We\'ll email you when it\'s ready.' };
}
```

## Key Rules
- Always generate CSV on the server — never in the browser for production data
- Include UTF-8 BOM (`﻿`) at the start — Excel won't open UTF-8 without it correctly
- Use `Content-Disposition: attachment; filename="..."` — without it the browser may display raw CSV
- Stream in chunks (500-1000 rows) — never `findMany()` all records at once
- Use ISO 8601 for all dates (`2026-05-18T14:30:00.000Z`) — locale formats break in Excel
- Escape per RFC 4180: fields with commas, quotes, or newlines are wrapped in double quotes; internal quotes doubled
- Disable the export button during export to prevent duplicate requests
- For very large exports (>100k rows), use a background job + email link instead of a synchronous response
- Include the date in the filename (`export-2026-05-18.csv`) — prevents overwriting previous exports
- `Cache-Control: no-store` — export results are dynamic, must not be cached
