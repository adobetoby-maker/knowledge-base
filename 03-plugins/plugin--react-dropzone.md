# react-dropzone

## When to Use

Use `react-dropzone` for file upload UI — drag-and-drop zones, file selection, multi-file handling, preview before upload.

For general drag-and-drop (reordering, kanban), use `@dnd-kit/core` instead.

```bash
npm install react-dropzone
```

## Basic Dropzone

```typescript
import { useDropzone } from 'react-dropzone'

interface FileDropzoneProps {
  onFiles: (files: File[]) => void
  accept?: Record<string, string[]>
  maxSize?: number
  multiple?: boolean
}

export function FileDropzone({
  onFiles,
  accept = { 'image/*': [], 'application/pdf': ['.pdf'] },
  maxSize = 10 * 1024 * 1024,  // 10MB
  multiple = false,
}: FileDropzoneProps) {
  const { getRootProps, getInputProps, isDragActive, fileRejections } = useDropzone({
    onDrop: (acceptedFiles) => onFiles(acceptedFiles),
    accept,
    maxSize,
    multiple,
  })
  
  return (
    <div>
      <div
        {...getRootProps()}
        className={cn(
          'border-2 border-dashed rounded-md p-8 text-center cursor-pointer transition-colors',
          isDragActive ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50'
        )}
      >
        <input {...getInputProps()} />
        <Upload className="h-8 w-8 mx-auto mb-2 text-muted-foreground" />
        <p className="text-sm font-medium">
          {isDragActive ? 'Drop the file here' : 'Drag a file here, or click to select'}
        </p>
        <p className="text-xs text-muted-foreground mt-1">PDF, PNG, JPG up to 10MB</p>
      </div>
      
      {fileRejections.length > 0 && (
        <p className="text-sm text-destructive mt-1">
          {fileRejections[0].errors[0].message}
        </p>
      )}
    </div>
  )
}
```

## File Preview Before Upload

```typescript
function FileUploadWithPreview() {
  const [previews, setPreviews] = useState<Array<{ file: File; url: string }>>([])
  
  function handleFiles(files: File[]) {
    const newPreviews = files.map(file => ({
      file,
      url: URL.createObjectURL(file),  // temporary object URL
    }))
    setPreviews(newPreviews)
  }
  
  // Cleanup object URLs on unmount:
  useEffect(() => {
    return () => previews.forEach(p => URL.revokeObjectURL(p.url))
  }, [previews])
  
  return (
    <div>
      <FileDropzone onFiles={handleFiles} accept={{ 'image/*': [] }} />
      <div className="flex gap-2 mt-2">
        {previews.map(({ file, url }) => (
          <div key={url} className="relative">
            <img src={url} alt={file.name} className="h-16 w-16 object-cover rounded" />
            <button
              onClick={() => {
                URL.revokeObjectURL(url)
                setPreviews(prev => prev.filter(p => p.url !== url))
              }}
              className="absolute -top-1 -right-1 bg-destructive text-white rounded-full h-4 w-4 flex items-center justify-center text-xs"
            >×</button>
          </div>
        ))}
      </div>
    </div>
  )
}
```

## Uploading to Supabase Storage

```typescript
async function uploadFile(file: File, userId: string): Promise<string> {
  const ext = file.name.split('.').pop()
  const path = `${userId}/${Date.now()}.${ext}`
  
  const { data, error } = await supabase.storage
    .from('attachments')
    .upload(path, file, {
      contentType: file.type,
      upsert: false,
    })
  
  if (error) throw new Error(`Upload failed: ${error.message}`)
  
  return data.path  // store this path in DB
}
```

## File Validation

Client validation is for UX; always validate on server too:

```typescript
const { getRootProps, getInputProps, fileRejections } = useDropzone({
  accept: {
    'image/jpeg': ['.jpg', '.jpeg'],
    'image/png': ['.png'],
    'application/pdf': ['.pdf'],
  },
  maxSize: 10 * 1024 * 1024,
  maxFiles: 5,
  validator: (file) => {
    // Custom validation:
    if (file.name.includes('..')) {
      return { code: 'invalid-name', message: 'Invalid file name' }
    }
    return null
  },
})
```

## Showing Upload Progress

```typescript
function handleFiles(files: File[]) {
  files.forEach(async (file) => {
    setUploadProgress(prev => ({ ...prev, [file.name]: 0 }))
    
    // Supabase doesn't provide progress events — use XMLHttpRequest for progress:
    const xhr = new XMLHttpRequest()
    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable) {
        setUploadProgress(prev => ({ ...prev, [file.name]: Math.round(e.loaded / e.total * 100) }))
      }
    })
    // ... configure and send xhr
  })
}
```
