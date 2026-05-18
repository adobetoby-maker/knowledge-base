# Pattern: Drag-and-Drop Media Uploader

Multi-file upload with drag-and-drop, preview, type/size validation, progress tracking, and S3 presigned URL uploads.

## Why Presigned URLs, Not Server Proxying

Uploading files through your server doubles bandwidth costs and increases latency. With S3 presigned URLs, the client uploads directly to S3 while your server only handles authentication and database records. This is the correct pattern for anything beyond tiny files.

Flow:
1. Client requests a presigned URL from your API (passing filename and content type)
2. Your API generates and returns the presigned URL (requires S3 credentials server-side)
3. Client uploads directly to S3 using the presigned URL with a `PUT` request
4. Client notifies your API that the upload is complete
5. Your API saves the file metadata to the database

```tsx
// Step 1–2: Get presigned URL
async function getPresignedUrl(file: File) {
  const res = await fetch('/api/upload/presign', {
    method: 'POST',
    body: JSON.stringify({ filename: file.name, contentType: file.type }),
  });
  return res.json() as Promise<{ uploadUrl: string; fileUrl: string; key: string }>;
}

// Step 3: Upload directly to S3
async function uploadToS3(
  file: File,
  uploadUrl: string,
  onProgress: (pct: number) => void
) {
  return new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.upload.addEventListener('progress', e => {
      if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100));
    });
    xhr.addEventListener('load', () => xhr.status < 400 ? resolve() : reject(new Error('Upload failed')));
    xhr.addEventListener('error', reject);
    xhr.open('PUT', uploadUrl);
    xhr.setRequestHeader('Content-Type', file.type);
    xhr.send(file);
  });
}
```

Use `XMLHttpRequest` over `fetch` for uploads because XHR exposes `upload.onprogress`. `fetch` has no progress events (without `ReadableStream` streams, which adds significant complexity).

## File Validation

Validate before upload — don't waste bandwidth on invalid files.

```tsx
const ACCEPTED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const MAX_SIZE_BYTES = 10 * 1024 * 1024; // 10MB

function validateFile(file: File): string | null {
  if (!ACCEPTED_TYPES.includes(file.type)) {
    return `${file.name}: unsupported type. Accepted: JPG, PNG, WebP, GIF`;
  }
  if (file.size > MAX_SIZE_BYTES) {
    return `${file.name}: too large. Maximum size is 10MB`;
  }
  return null;
}
```

## Drag-and-Drop Zone

```tsx
function DropZone({ onFiles }: { onFiles: (files: File[]) => void }) {
  const [isDragging, setIsDragging] = useState(false);

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const files = Array.from(e.dataTransfer.files);
    onFiles(files);
  };

  return (
    <label
      className={cn(
        'flex flex-col items-center gap-3 rounded-xl border-2 border-dashed p-10 cursor-pointer transition-colors',
        isDragging ? 'border-primary bg-primary/5' : 'border-muted-foreground/25 hover:border-primary/50'
      )}
      onDragOver={e => { e.preventDefault(); setIsDragging(true); }}
      onDragLeave={() => setIsDragging(false)}
      onDrop={handleDrop}
    >
      <UploadIcon className="w-10 h-10 text-muted-foreground" />
      <div className="text-center">
        <span className="font-medium">Drag files here or click to browse</span>
        <p className="text-sm text-muted-foreground mt-1">JPG, PNG, WebP, GIF up to 10MB</p>
      </div>
      <input
        type="file"
        multiple
        accept={ACCEPTED_TYPES.join(',')}
        className="sr-only"
        onChange={e => onFiles(Array.from(e.target.files ?? []))}
      />
    </label>
  );
}
```

Wrapping the input in a `<label>` means the entire drop zone is clickable to open the file browser.

## Upload Queue with Progress

```tsx
type UploadItem = {
  file: File;
  preview: string; // object URL for image preview
  status: 'pending' | 'uploading' | 'done' | 'error';
  progress: number;
  errorMessage?: string;
  fileUrl?: string;
};

function useUploadQueue() {
  const [items, setItems] = useState<UploadItem[]>([]);

  const addFiles = useCallback((files: File[]) => {
    const newItems: UploadItem[] = files.map(file => ({
      file,
      preview: URL.createObjectURL(file),
      status: 'pending',
      progress: 0,
    }));
    setItems(prev => [...prev, ...newItems]);
    newItems.forEach(item => uploadFile(item.file, item.preview));
  }, []);

  const uploadFile = async (file: File, previewId: string) => {
    const update = (patch: Partial<UploadItem>) =>
      setItems(prev => prev.map(i => i.preview === previewId ? { ...i, ...patch } : i));

    const validationError = validateFile(file);
    if (validationError) {
      update({ status: 'error', errorMessage: validationError });
      return;
    }

    update({ status: 'uploading' });
    try {
      const { uploadUrl, fileUrl } = await getPresignedUrl(file);
      await uploadToS3(file, uploadUrl, pct => update({ progress: pct }));
      update({ status: 'done', progress: 100, fileUrl });
    } catch {
      update({ status: 'error', errorMessage: 'Upload failed. Please try again.' });
    }
  };

  // Cleanup object URLs to avoid memory leaks
  const remove = useCallback((previewId: string) => {
    setItems(prev => {
      const item = prev.find(i => i.preview === previewId);
      if (item) URL.revokeObjectURL(item.preview);
      return prev.filter(i => i.preview !== previewId);
    });
  }, []);

  return { items, addFiles, remove };
}
```

## Key Rules

- Use presigned URLs for direct-to-S3 uploads — proxying through your server doubles costs
- Use `XMLHttpRequest` not `fetch` for uploads — XHR exposes `upload.onprogress`
- Validate file type and size before uploading — don't send invalid files over the network
- `URL.createObjectURL` for previews; call `URL.revokeObjectURL` on removal to prevent memory leaks
- Always validate file type by MIME type (`file.type`), not extension — extensions are user-controlled
- Show per-file progress and status, not a single aggregate bar — multi-file uploads have independent states
