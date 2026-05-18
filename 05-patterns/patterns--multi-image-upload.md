# Pattern: Multiple Image Upload

## Overview
Multi-image upload is fundamentally different from single-file upload: the user curates a set of images before committing, order matters (product gallery sequence, listing photos), and failures must be recoverable per-image without discarding successfully uploaded files. Treating the whole batch as atomic — retry everything on any failure — destroys user trust on slow connections.

## Implementation

### State Model
```ts
type UploadStatus = 'pending' | 'uploading' | 'done' | 'error';

interface UploadFile {
  id: string;
  file: File;
  preview: string;        // Object URL from URL.createObjectURL
  status: UploadStatus;
  progress: number;       // 0-100
  uploadedUrl?: string;   // set on success
  error?: string;
}
```

### Selection and Validation
```tsx
const MAX_COUNT = 10;
const MAX_TOTAL_MB = 50;
const ACCEPTED = ['image/jpeg', 'image/png', 'image/webp'];

function handleSelect(event: React.ChangeEvent<HTMLInputElement>) {
  const selected = Array.from(event.target.files ?? []);
  const violations: string[] = [];

  const valid = selected.filter(f => {
    if (!ACCEPTED.includes(f.type)) { violations.push(`${f.name}: unsupported type`); return false; }
    if (f.size > 10 * 1024 * 1024) { violations.push(`${f.name}: exceeds 10 MB`); return false; }
    return true;
  });

  const combined = [...files, ...valid.map(toUploadFile)];
  if (combined.length > MAX_COUNT) {
    violations.push(`Maximum ${MAX_COUNT} images`);
  }
  const totalMB = combined.reduce((s, f) => s + f.file.size, 0) / 1024 / 1024;
  if (totalMB > MAX_TOTAL_MB) {
    violations.push(`Total size exceeds ${MAX_TOTAL_MB} MB`);
  }

  if (violations.length) setErrors(violations);
  setFiles(combined.slice(0, MAX_COUNT));
  event.target.value = ''; // allow re-selecting same file
}

function toUploadFile(file: File): UploadFile {
  return {
    id: crypto.randomUUID(),
    file,
    preview: URL.createObjectURL(file),
    status: 'pending',
    progress: 0,
  };
}
```

### Grid Preview
```tsx
<div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(120px, 1fr))', gap: 8 }}>
  {files.map((f, i) => (
    <div key={f.id} style={{ position: 'relative', aspectRatio: '1' }}>
      <img
        src={f.preview}
        alt={`Upload ${i + 1}`}
        style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 4 }}
      />
      {/* Remove button */}
      <button
        onClick={() => removeFile(f.id)}
        aria-label={`Remove ${f.file.name}`}
        style={{ position: 'absolute', top: 4, right: 4 }}
        disabled={f.status === 'uploading'}
      >
        ✕
      </button>
      {/* Per-image progress */}
      {f.status === 'uploading' && (
        <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 4 }}>
          <div style={{ width: `${f.progress}%`, height: '100%', background: '#3b82f6' }} />
        </div>
      )}
      {f.status === 'error' && (
        <button onClick={() => retryFile(f.id)} style={{ position: 'absolute', bottom: 4, right: 4 }}>
          Retry
        </button>
      )}
    </div>
  ))}
</div>
```

### Upload with Per-File Progress
```tsx
async function uploadFile(entry: UploadFile) {
  setFileStatus(entry.id, 'uploading');

  const formData = new FormData();
  formData.append('file', entry.file);

  try {
    // XMLHttpRequest for progress events; fetch doesn't support upload progress
    const url = await new Promise<string>((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) setFileProgress(entry.id, Math.round(e.loaded / e.total * 100));
      };
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve(JSON.parse(xhr.responseText).url);
        } else {
          reject(new Error(`HTTP ${xhr.status}`));
        }
      };
      xhr.onerror = () => reject(new Error('Network error'));
      xhr.open('POST', '/api/upload');
      xhr.send(formData);
    });
    setFileUploaded(entry.id, url);
  } catch (err) {
    setFileError(entry.id, (err as Error).message);
  }
}

// Upload all pending in order (or parallel with concurrency limit)
async function uploadAll() {
  const pending = files.filter(f => f.status === 'pending' || f.status === 'error');
  for (const f of pending) await uploadFile(f);
}
```

### Memory Cleanup
```tsx
useEffect(() => {
  return () => {
    files.forEach(f => URL.revokeObjectURL(f.preview));
  };
}, []); // revoke on unmount only
```

## Key Rules
- Validate file type AND size before creating previews — don't waste Object URLs on invalid files.
- Use `XMLHttpRequest` for upload progress, not `fetch` — the Fetch API does not expose upload progress events.
- Preserve upload order: the `id` array order = final submitted order. Don't sort by upload completion.
- `URL.revokeObjectURL` on unmount only — revoking while the image is still visible in the grid breaks the preview.
- Retry must only re-upload the specific failed file, not restart the whole batch.
- Reset `<input type="file">` value after selection so the same file can be re-selected after removal.
- Disable the Remove button while a file is uploading — cancelling mid-upload without aborting the XHR leaves orphaned server files.
