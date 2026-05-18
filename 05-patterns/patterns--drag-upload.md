# Pattern: Drag-and-Drop File Upload

## Problem

Drag-and-drop upload fails silently without `preventDefault` on `dragover`. The `dragleave` event fires spuriously when the cursor moves over child elements, causing the dropzone highlight to flicker. File validation must happen before the upload starts, not after. And progress display requires tracking per-file upload state.

## The preventDefault Requirement

`dragover` must call `preventDefault()` — this is what signals to the browser that the element accepts drops. Without it, dropping a file navigates the browser to the file URL:

```ts
function handleDragOver(e: React.DragEvent) {
  e.preventDefault();                // REQUIRED: tells browser this is a drop target
  e.dataTransfer.dropEffect = 'copy';
}
```

## The Child Element Problem (dragenter/dragleave Counter)

When the cursor moves from the dropzone boundary to a child element inside it, `dragleave` fires on the parent and `dragenter` fires on the child — making the parent think the drag has left. Fix with a counter:

```tsx
function DropZone({ onFiles }: { onFiles: (files: File[]) => void }) {
  const [dragDepth, setDragDepth] = useState(0);
  const isOver = dragDepth > 0;

  function handleDragEnter(e: React.DragEvent) {
    e.preventDefault();
    setDragDepth(d => d + 1);
  }

  function handleDragLeave(e: React.DragEvent) {
    e.preventDefault();
    setDragDepth(d => d - 1);  // only goes to 0 when cursor truly leaves the zone
  }

  function handleDragOver(e: React.DragEvent) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'copy';
  }

  function handleDrop(e: React.DragEvent) {
    e.preventDefault();
    setDragDepth(0);  // reset regardless of counter value
    const files = Array.from(e.dataTransfer.files);
    processFiles(files);
  }

  function processFiles(files: File[]) {
    const valid = files.filter(validate);
    if (valid.length < files.length) {
      toast.error('Some files were rejected. Check type and size limits.');
    }
    onFiles(valid);
  }
  // ...
}
```

WHY counter instead of `e.relatedTarget`: `relatedTarget` is often `null` for security reasons (e.g., dragging from another origin), making it unreliable for detecting whether the drag is truly leaving.

## File Validation Before Upload

Validate type and size before starting the upload. Never rely on server-side rejection alone — that wastes the upload and produces a confusing error message:

```ts
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
const MAX_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB

type ValidationResult = { valid: boolean; error?: string };

function validate(file: File): boolean {
  if (!ALLOWED_TYPES.includes(file.type)) {
    toast.error(`${file.name}: unsupported file type`);
    return false;
  }
  if (file.size > MAX_SIZE_BYTES) {
    toast.error(`${file.name}: file too large (max 10 MB)`);
    return false;
  }
  return true;
}
```

## Upload with Progress Display

Track per-file progress using a `Record<filename, number>`:

```ts
type UploadState = {
  status: 'pending' | 'uploading' | 'done' | 'error';
  progress: number;
  error?: string;
};

async function uploadFile(
  file: File,
  onProgress: (pct: number) => void
): Promise<string> {
  const form = new FormData();
  form.append('file', file);

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.upload.onprogress = e => {
      if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100));
    };
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve(JSON.parse(xhr.responseText).url);
      } else {
        reject(new Error(`Upload failed: ${xhr.status}`));
      }
    };
    xhr.onerror = () => reject(new Error('Network error'));
    xhr.open('POST', '/api/upload');
    xhr.send(form);
  });
}
```

WHY `XMLHttpRequest` instead of `fetch` for progress: `fetch` does not expose upload progress. Use `xhr.upload.onprogress` for per-file progress bars.

## Dropzone Visual Feedback

```tsx
<div
  onDragEnter={handleDragEnter}
  onDragLeave={handleDragLeave}
  onDragOver={handleDragOver}
  onDrop={handleDrop}
  className={`rounded-xl border-2 border-dashed p-8 text-center transition-colors ${
    isOver ? 'border-indigo-500 bg-indigo-50' : 'border-gray-300 bg-gray-50'
  }`}
  aria-label="Drop files here or click to browse"
>
  <p>{isOver ? 'Release to upload' : 'Drag files here or click to browse'}</p>
</div>
```

## Key Rules

- `dragover` requires `e.preventDefault()` or drops don't work — this is the most common bug
- Use an enter/leave counter to prevent flickering on child element boundaries
- Validate file type and size client-side before starting the upload
- `XMLHttpRequest` is required for upload progress — `fetch` has no upload progress API
- Reset `dragDepth` to 0 on drop, not just decrement, to handle edge cases
