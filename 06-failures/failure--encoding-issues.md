# Failure: Character Encoding Issues

## Common Symptoms

- `?` or `â€™` appearing instead of apostrophes or quotes
- Emojis showing as `????`
- Form submissions with special characters failing
- PDF generation with accented characters showing boxes
- CSV files opened in Excel showing garbled text

## Root Cause Map

| Symptom | Likely cause |
|---|---|
| `â€™` instead of `'` | UTF-8 content read as Latin-1 |
| `?` boxes | UTF-8 string written to non-UTF-8 column |
| `????` for emojis | MySQL `utf8` charset (not `utf8mb4`) |
| Excel garbling CSV | Missing BOM for Windows Excel |
| PDF box characters | Font doesn't include the character |

## Database: Always Use UTF-8

Postgres:
```sql
-- Check current encoding
SHOW server_encoding;
-- Should be UTF8
```

MySQL — use `utf8mb4` not `utf8`:
```sql
-- MySQL's 'utf8' is broken — only 3 bytes, can't store emoji
-- utf8mb4 is the real UTF-8
ALTER TABLE posts CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

## Excel CSV: Add BOM

Windows Excel doesn't recognize UTF-8 without a BOM (Byte Order Mark):

```ts
function createExcelFriendlyCSV(data: string): Blob {
  const BOM = '﻿'  // UTF-8 BOM
  return new Blob([BOM + data], { type: 'text/csv;charset=utf-8' })
}
```

Without the BOM, accented characters (é, ü, ñ) display as garbage in Excel on Windows.

## API: Always Set Content-Type with charset

```ts
// Set charset explicitly — don't leave it to browser inference
return new Response(json, {
  headers: { 'Content-Type': 'application/json; charset=utf-8' }
})
```

## Node.js: File Reading

```ts
// Default encoding is 'utf8' — but be explicit when dealing with user files
const content = await readFile(path, 'utf8')

// For binary files that will be compared or transmitted
const buffer = await readFile(path)  // Returns Buffer
```

## HTML: Declare charset in <head>

```html
<meta charset="UTF-8">
<!-- Must be the first element in <head> or within first 1024 bytes -->
```

## JSON.stringify with Unicode

JavaScript strings are UTF-16 internally. JSON.stringify handles this correctly — no manual encoding needed. Problems arise when:

- Byte strings (Buffer) are stringified incorrectly
- Non-JSON parsers read JSON files without declaring encoding

## Email: MIME Type

```ts
// Nodemailer handles charset automatically for text/html
const mail = {
  from: '"My App" <app@example.com>',
  to: user.email,
  subject: `Welcome, ${user.name}!`,
  html: `<p>Welcome, ${user.name}!</p>`,
  // Nodemailer adds: Content-Type: text/html; charset=utf-8
}
```

## Detecting Mojibake (Corrupted Text)

```ts
// Check if a string contains common mojibake patterns
function hasMojibake(text: string): boolean {
  // Latin-1 decoded as UTF-8 produces these sequences
  return /[\xC0-\xC5][\x80-\xBF]/.test(text)  // 'Ã©' = é misread
    || text.includes('â€™')   // ' (smart apostrophe) misread
    || text.includes('â€œ')   // " (smart quote) misread
}
```

## Key Rules

- Postgres databases should always be `UTF8` — this is the default when created via Supabase.
- MySQL: always create databases with `CHARACTER SET utf8mb4`. The `utf8` alias is broken.
- CSV downloads for users: add the UTF-8 BOM for Excel compatibility.
- Never store text in `BYTEA` (binary) columns unless you're intentionally storing raw bytes — use `TEXT`.
- When in doubt about encoding issues: check the character encoding at each boundary (form → server → DB → API → client).
