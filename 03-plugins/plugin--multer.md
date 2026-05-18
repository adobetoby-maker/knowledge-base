# Plugin: Multer (File Uploads)

## Overview
Multer is Express middleware for handling `multipart/form-data`, the encoding type used by HTML file upload forms. Choosing the right storage engine and enforcing MIME validation at the middleware layer—rather than relying on file extensions—is the difference between a secure upload pipeline and a trivial file-type bypass vulnerability. Always treat the temp file as untrusted until your application has processed and moved it.

## Storage Engines

### diskStorage — for large files or when you need the path on disk
```ts
import multer from 'multer';
import path from 'path';
import os from 'os';

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    // Write to OS temp dir, not a public folder
    cb(null, os.tmpdir());
  },
  filename: (_req, file, cb) => {
    // Avoid user-supplied filenames — they can contain path traversal characters
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `upload-${unique}${ext}`);
  },
});
```

### memoryStorage — for small files processed in-memory (e.g., avatars → Sharp)
```ts
const storage = multer.memoryStorage();
// file.buffer is available; file.path is NOT
// Risk: large files exhaust server RAM — always pair with fileSize limit
```

## File Filter (MIME type, not extension)
```ts
const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
]);

const fileFilter: multer.Options['fileFilter'] = (_req, file, cb) => {
  if (ALLOWED_MIME_TYPES.has(file.mimetype)) {
    cb(null, true);
  } else {
    // Pass an Error — multer catches it and calls next(err)
    cb(new Error(`Unsupported file type: ${file.mimetype}`));
  }
};
```

## Size Limits and Field Whitelist
```ts
const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024,  // 5 MB per file
    files: 3,                    // max files per request
    fields: 10,                  // max non-file fields
  },
});

// Whitelist specific field names — rejects unexpected upload fields
router.post('/upload', upload.fields([
  { name: 'avatar', maxCount: 1 },
  { name: 'attachments', maxCount: 3 },
]), handler);
```

## Cleanup in Finally Block
```ts
import fs from 'fs/promises';

async function handler(req: Request, res: Response) {
  const file = req.file; // single file upload
  if (!file) return res.status(400).json({ error: 'No file provided' });

  try {
    // Process: resize, upload to S3, insert DB record, etc.
    const key = await uploadToS3(file.path, file.mimetype);
    await db.insert({ key, userId: req.user.id });
    res.json({ key });
  } finally {
    // Delete temp file regardless of success or failure
    if (file.path) {
      await fs.unlink(file.path).catch(() => {
        // Log but don't crash — disk cleanup failure isn't fatal to the response
      });
    }
  }
}
```

## Error Handling
```ts
// Multer throws MulterError for its own limits, generic Error for fileFilter rejections
app.use((err: Error, req, res, next) => {
  if (err instanceof multer.MulterError) {
    // e.g. LIMIT_FILE_SIZE, LIMIT_UNEXPECTED_FILE
    return res.status(400).json({ error: err.code, message: err.message });
  }
  if (err.message.startsWith('Unsupported file type')) {
    return res.status(415).json({ error: 'UNSUPPORTED_TYPE', message: err.message });
  }
  next(err);
});
```

## Key Rules
- **MIME type check, not extension** — extensions are trivially spoofed; check `file.mimetype` in `fileFilter`.
- **Always use `os.tmpdir()` for disk storage** — never write uploads directly to a public static folder.
- **Delete temp files in a `finally` block** — if you skip cleanup on error paths, disk fills over time.
- **`memoryStorage` requires strict `fileSize` limit** — unbounded in-memory uploads are a DoS vector.
- **Whitelist field names with `upload.fields([])`** — `upload.any()` accepts arbitrary field names and is a security smell.
- **`limits.files`** caps the total file count per request, preventing multipart bombing.
