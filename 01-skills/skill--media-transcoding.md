# Media Transcoding

Video and audio transcoding converts source files into formats optimized for delivery. Source files are large and often in container formats (MOV, AVI, MKV) that browsers don't support. Transcoding is CPU-heavy, takes minutes, and should never happen synchronously in a web request.

## The Pipeline Architecture

Never transcode in the upload handler. The correct architecture is:

1. Client uploads file directly to object storage via presigned URL (S3, R2, GCS)
2. Storage event (webhook or queue message) triggers a transcoding job
3. Transcoding worker processes the file asynchronously
4. On completion, output files land in CDN-accessible storage
5. Worker fires a webhook or writes to DB to signal completion
6. App updates the media record status from `pending` → `ready`

This keeps your web servers out of the I/O path entirely and lets transcoding scale independently.

## FFmpeg for Server-Side Transcoding

FFmpeg is the standard. Run it as a child process from Node.js or Python, or use a wrapper (`fluent-ffmpeg` for Node).

**MP4 (H.264 + AAC)** — maximum compatibility, works in every browser and mobile OS:
```bash
ffmpeg -i input.mov \
  -c:v libx264 -crf 23 -preset medium \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  output.mp4
```

`-movflags +faststart` moves the MP4 index to the beginning of the file so browsers can start playback before the full download completes. This is not optional for good UX.

**WebM (VP9 + Opus)** — smaller files, open codec, no licensing cost, slightly worse browser support than H.264:
```bash
ffmpeg -i input.mov \
  -c:v libvpx-vp9 -crf 30 -b:v 0 \
  -c:a libopus -b:a 128k \
  output.webm
```

Produce both MP4 and WebM and let the `<video>` tag pick via `<source>`.

## Thumbnail Extraction

Extract a frame for the poster image at 10% into the video (avoids black frames at the start):

```bash
ffmpeg -i input.mp4 \
  -ss 10% -vframes 1 \
  -vf "scale=640:-1" \
  thumbnail.jpg
```

Generate multiple thumbnails (e.g., at 10%, 30%, 50%) and let users pick a cover image or auto-select via content analysis.

## Progress Reporting

FFmpeg outputs progress to stderr. Parse the `time=` field from ffmpeg's progress output and calculate percentage complete from duration. Write progress to a Redis key or database row that the client polls (or push via SSE/WebSocket).

```
frame=  432 fps= 24 q=23.0 size=   4096kB time=00:00:18.00 bitrate=...
```

Never make the client wait for transcoding to complete before showing the UI. Show a progress bar with the polled percentage and swap in the final video when status transitions to `ready`.

## Multiple Format Outputs

Run format outputs in parallel within the same FFmpeg command using multiple `-map` and output file arguments. This is more efficient than running separate FFmpeg processes because the input is decoded once.

For large files or high concurrency, use a job queue (BullMQ, Inngest, SQS) with dedicated transcoding workers — not your application servers. Transcoding maxes out CPU; mixing it with request handling degrades response times.

## Storage Layout

```
uploads/          ← original source files (private, retention policy applies)
media/{id}/
  original.{ext}  ← copy of source (or just a reference)
  720p.mp4
  720p.webm
  thumbnail.jpg
  thumbnail-30pct.jpg
```

Never serve from `uploads/` directly. Serve only from `media/` after transcoding is complete.

## Key Rules

- Never transcode synchronously in a request handler — always via job queue
- Use presigned upload URLs; keep transcoding workers off web server processes
- Output both MP4 (H.264) and WebM (VP9) for maximum browser compatibility
- Always use `-movflags +faststart` on MP4 output
- Extract thumbnail at ~10% of duration to avoid black or title-card frames
- Report progress via polling or SSE, never block the UI on transcode completion
- Store originals separately from transcoded outputs; apply retention policy to originals
