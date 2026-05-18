# plugin--googleapis — Google APIs Node.js Client

## What It Is
The `googleapis` npm package is the official Node.js client for all Google APIs (Drive, Sheets, Calendar, Gmail, etc.). It handles OAuth2 token refresh, JSON serialization, and typed response shapes.

## Authentication — Service Account Pattern
Service accounts are the right choice for server-to-server access. Never use OAuth2 user flows for background jobs.

```ts
import { google } from 'googleapis';

const auth = new google.auth.GoogleAuth({
  credentials: JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_JSON!),
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });
```

**Why credentials over keyFile**: In deployed environments (Vercel, Cloud Run) you won't have a filesystem path. Serialize the JSON key to an env var and parse it at runtime.

**Scope minimization**: Request only the scopes your service actually needs. A service account with Drive full-access is a credential leak waiting to happen. Use `drive.readonly` when you only read.

## Drive API

```ts
const drive = google.drive({ version: 'v3', auth });

// List files — always specify fields to avoid massive payloads
const res = await drive.files.list({
  q: "mimeType='application/vnd.google-apps.spreadsheet'",
  fields: 'nextPageToken, files(id, name, modifiedTime)',
  pageSize: 100,
});
```

**Never omit `fields`**: Without it, Google returns every field on every file, including thumbnails. This is slow and eats quota.

## Pagination — Always Handle `nextPageToken`

```ts
async function listAllFiles(drive: drive_v3.Drive) {
  const files: drive_v3.Schema$File[] = [];
  let pageToken: string | undefined;

  do {
    const res = await drive.files.list({
      fields: 'nextPageToken, files(id, name)',
      pageSize: 1000,
      pageToken,
    });
    files.push(...(res.data.files ?? []));
    pageToken = res.data.nextPageToken ?? undefined;
  } while (pageToken);

  return files;
}
```

Assuming one page is enough silently truncates results. Always loop.

## Sheets API

```ts
// Read a range
const res = await sheets.spreadsheets.values.get({
  spreadsheetId: SHEET_ID,
  range: 'Sheet1!A1:E100',
});
const rows = res.data.values ?? [];

// Write a range
await sheets.spreadsheets.values.update({
  spreadsheetId: SHEET_ID,
  range: 'Sheet1!A1',
  valueInputOption: 'USER_ENTERED',  // interprets formulas; use RAW to skip
  requestBody: { values: [['Name', 'Email'], ['Alice', 'alice@example.com']] },
});
```

## Batch Requests to Reduce Quota Usage

Each API call costs quota. For Sheets, use `batchUpdate` or `batchGet` when touching multiple ranges:

```ts
const res = await sheets.spreadsheets.values.batchGet({
  spreadsheetId: SHEET_ID,
  ranges: ['Sheet1!A:A', 'Sheet2!B:B'],
});
```

For Drive metadata updates on multiple files, use `batch()` from the HTTP client — but in practice, sequential awaits with exponential backoff is simpler and enough for most workloads.

## Quota and Rate Limit Handling

- **100 requests/100 seconds/user** is the default Sheets limit.
- On `429` or `403 rateLimitExceeded`, back off with jitter and retry.
- For bulk writes, batch into chunks of 50 and add a 200ms delay between chunks.

```ts
async function withRetry<T>(fn: () => Promise<T>, attempts = 3): Promise<T> {
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (err: any) {
      if (err?.code === 429 && i < attempts - 1) {
        await new Promise(r => setTimeout(r, 1000 * 2 ** i));
      } else throw err;
    }
  }
  throw new Error('unreachable');
}
```

## Calendar API

```ts
const calendar = google.calendar({ version: 'v3', auth });

const events = await calendar.events.list({
  calendarId: 'primary',
  timeMin: new Date().toISOString(),
  maxResults: 50,
  singleEvents: true,
  orderBy: 'startTime',
});
```

For service accounts accessing a user's calendar, the user must share the calendar with the service account email and the service account must be granted domain-wide delegation in Google Workspace.

## Key Rules
- Use `GoogleAuth` with `credentials` from env var — never rely on a keyFile path in production.
- Always specify `fields` in Drive list calls to minimize payload and quota.
- Always paginate with `nextPageToken` — never assume one page is the full result.
- Use `batchGet`/`batchUpdate` for Sheets when touching multiple ranges in one operation.
- Retry on `429` with exponential backoff; do not retry `403 forbidden` (it's a permissions error, not rate limiting).
- Scope service accounts to the minimum required permissions.
