# Skill: Server-Side File Processing Pipeline

## What This Covers

Processing uploaded files on the server: handling multipart uploads safely, validating content type beyond the file extension, scanning for viruses, offloading CPU-intensive work to a processing queue, and reporting progress back to the client via WebSocket.

## Multipart Upload Handling

Parse the incoming `multipart/form-data` stream without buffering the entire file in memory. Node's built-in `req.body` parsers buffer everything — use a streaming parser instead.

```ts
import Busboy from 'busboy'

export async function POST(req: Request) {
  const contentType = req.headers.get('content-type') ?? ''
  if (!contentType.includes('multipart/form-data')) {
    return Response.json({ error: 'Expected multipart/form-data' }, { status: 400 })
  }
  
  const bb = Busboy({ headers: Object.fromEntries(req.headers), limits: {
    fileSize: 50 * 1024 * 1024,  // 50 MB hard limit
    files: 1,                    // one file per request
  }})
  
  return new Promise((resolve) => {
    bb.on('file', (fieldname, stream, info) => {
      const { filename, mimeType } = info
      // pipe stream to S3 or temp file — do not collect into memory
      const uploadStream = s3.upload({ Bucket: '...', Key: tmpKey, Body: stream })
      uploadStream.promise().then(() => resolve(Response.json({ key: tmpKey })))
    })
    
    bb.on('limitReached', () => {
      resolve(Response.json({ error: 'File exceeds size limit' }, { status: 413 }))
    })
    
    req.body?.pipeTo(new WritableStream({ write(chunk) { bb.write(chunk) }, close() { bb.end() } }))
  })
}
```

Upload to a quarantine bucket/prefix first (`uploads/quarantine/`). Only move to the permanent location after validation and scanning pass.

## Content Type Validation Beyond Extension

File extensions are user-supplied and untrustworthy. A user can rename `malware.exe` to `document.pdf`. Validate the actual file magic bytes (file signature).

```ts
import { fileTypeFromStream } from 'file-type'  // inspects magic bytes

async function validateContentType(stream: ReadableStream, declaredType: string): Promise<string> {
  const result = await fileTypeFromStream(stream)
  
  if (!result) throw new Error('Cannot determine file type from content')
  
  const ALLOWED_TYPES: Record<string, string[]> = {
    'application/pdf': ['pdf'],
    'image/jpeg': ['jpg', 'jpeg'],
    'image/png': ['png'],
    'image/webp': ['webp'],
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['docx'],
  }
  
  if (!ALLOWED_TYPES[result.mime]) {
    throw new Error(`File type ${result.mime} is not allowed`)
  }
  
  // Mismatch between declared and actual type is a red flag
  if (result.mime !== declaredType) {
    console.warn(`Content-type mismatch: declared ${declaredType}, actual ${result.mime}`)
  }
  
  return result.mime
}
```

## Virus Scanning Integration (ClamAV)

Scan files before making them accessible. ClamAV's `clamd` daemon exposes a socket interface; `clamscan` CLI is simpler for low-volume use.

```ts
import { createConnection } from 'net'

async function scanFile(filePath: string): Promise<{ clean: boolean; threat?: string }> {
  return new Promise((resolve, reject) => {
    const socket = createConnection('/var/run/clamav/clamd.ctl')
    
    socket.write(`SCAN ${filePath}\n`)
    
    socket.on('data', (data) => {
      const response = data.toString()
      if (response.includes('OK')) {
        resolve({ clean: true })
      } else if (response.includes('FOUND')) {
        const threat = response.split(':')[1]?.trim()
        resolve({ clean: false, threat })
      }
      socket.end()
    })
    
    socket.on('error', reject)
    socket.setTimeout(30_000, () => reject(new Error('ClamAV scan timeout')))
  })
}
```

If the scan fails (ClamAV unreachable), fail closed — reject the file rather than allowing it through. Log the failure and alert ops.

For SaaS deployments: consider cloud-based scanning APIs (Cloudmersive, VirusTotal Enterprise) instead of running ClamAV yourself.

## Processing Queue for CPU-Intensive Work

Never process images, extract PDF text, or transcode video synchronously in a request handler. These operations block the event loop and time out under load. Enqueue a job and respond immediately.

```ts
// In the upload route handler, after validation:
const jobId = await queue.add('process-upload', {
  fileKey: tmpKey,
  userId: user.id,
  fileType: validatedMimeType,
  originalName: filename,
})

return Response.json({ jobId, status: 'queued' })

// Worker (runs in a separate process):
queue.process('process-upload', async (job) => {
  const { fileKey, userId, fileType } = job.data
  
  // Download from quarantine, process, upload to permanent location
  if (fileType === 'application/pdf') {
    await extractTextFromPdf(fileKey)
  } else if (fileType.startsWith('image/')) {
    await generateThumbnails(fileKey)
  }
  
  await moveFromQuarantineToPermanent(fileKey, userId)
  await updateDatabase(fileKey, 'ready')
  
  // Notify client via WebSocket or push notification
  await notifyClient(userId, jobId, 'complete')
})
```

## Progress Reporting via WebSocket

For long-running processing (e.g., video transcoding, large document parsing), report progress to the client rather than making them poll.

```ts
// Server: push updates through a WebSocket connection keyed by jobId
wss.on('connection', (ws, req) => {
  const jobId = new URL(req.url, 'http://x').searchParams.get('jobId')
  activeConnections.set(jobId, ws)
  
  ws.on('close', () => activeConnections.delete(jobId))
})

// In the worker, emit progress events
async function processLargeFile(fileKey: string, jobId: string) {
  const ws = activeConnections.get(jobId)
  const send = (data: object) => ws?.send(JSON.stringify(data))
  
  send({ stage: 'scanning', progress: 0 })
  await scanFile(fileKey)
  
  send({ stage: 'processing', progress: 25 })
  await extractContent(fileKey)
  
  send({ stage: 'thumbnails', progress: 75 })
  await generateThumbnails(fileKey)
  
  send({ stage: 'complete', progress: 100, resultUrl: permanentUrl })
}
```

For serverless (no persistent WebSocket): use Server-Sent Events (SSE) or a polling endpoint (`GET /api/jobs/:id/status`) instead.

## Key Rules

- Upload to a quarantine location first; move to permanent only after scanning and validation pass
- Validate file type from magic bytes, not the declared MIME type or extension
- Fail closed on scan errors — an unscanned file should never reach users
- Enqueue CPU-intensive processing; never block a request handler
- Set hard size limits at the parser level before reading any bytes
- Use WebSocket or SSE for progress on long jobs; polling is acceptable if WebSocket isn't available
- Keep quarantine files for 24 hours before auto-deleting unclaimed uploads
