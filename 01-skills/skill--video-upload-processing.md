# Skill: Video Upload Pipeline

## Overview
Video upload has three stages that must be decoupled: receiving the raw file, transcoding it to a delivery format, and making it available for playback. Uploading through your server doubles bandwidth costs and creates timeouts. Transcoding synchronously blocks the user. Storing and serving the raw upload creates massive storage costs and bad playback performance. Each stage needs its own solution.

## Implementation

### Stage 1: Direct Upload to Storage (Bypass Your Server)
Generate a presigned URL server-side; client uploads directly to S3/R2/GCS:

```ts
// Server: POST /api/videos/upload-url
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const s3 = new S3Client({ region: 'us-east-1' });

export async function getUploadUrl(userId: string, filename: string) {
  const key = `uploads/${userId}/${Date.now()}-${filename}`;

  const command = new PutObjectCommand({
    Bucket: process.env.S3_RAW_BUCKET,
    Key: key,
    ContentType: 'video/*',
    Metadata: { userId },
  });

  const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 3600 });

  // Record pending video in DB
  const video = await db.videos.create({
    userId,
    s3Key: key,
    status: 'pending_upload',
  });

  return { uploadUrl, videoId: video.id, s3Key: key };
}
```

```ts
// Client: upload directly to S3
async function uploadVideo(file: File, uploadUrl: string, onProgress: (pct: number) => void) {
  await new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) onProgress(Math.round(e.loaded / e.total * 100));
    };
    xhr.onload = () => xhr.status < 300 ? resolve() : reject(new Error(`S3 upload failed: ${xhr.status}`));
    xhr.onerror = () => reject(new Error('Network error'));
    xhr.open('PUT', uploadUrl);
    xhr.setRequestHeader('Content-Type', file.type);
    xhr.send(file);
  });
}
```

### Stage 2: Trigger Transcoding
After S3 upload, trigger transcoding via webhook or queue. Use S3 event notifications → SQS → worker:

```ts
// S3 event triggers this Lambda/worker function
async function handleS3Upload(event: S3Event) {
  const key = event.Records[0].s3.object.key;
  const video = await db.videos.findByS3Key(key);

  await db.videos.update({ status: 'processing' }, { where: { id: video.id } });

  // Option A: AWS MediaConvert
  const job = await mediaconvert.createJob({
    Role: MEDIACONVERT_ROLE_ARN,
    Settings: {
      Inputs: [{ FileInput: `s3://${RAW_BUCKET}/${key}` }],
      OutputGroups: [{
        Name: 'HLS',
        OutputGroupSettings: {
          Type: 'HLS_GROUP_SETTINGS',
          HlsGroupSettings: {
            Destination: `s3://${OUTPUT_BUCKET}/videos/${video.id}/`,
          },
        },
        Outputs: [
          { VideoDescription: { Width: 1280, Height: 720, CodecSettings: { Codec: 'H_264' } } },
          { VideoDescription: { Width: 640, Height: 360, CodecSettings: { Codec: 'H_264' } } },
        ],
      }],
    },
  });

  await db.videos.update({ transcodeJobId: job.Job.Id }, { where: { id: video.id } });
}
```

### Stage 3: Thumbnail Extraction
Extract thumbnails at multiple timestamps using FFmpeg or a cloud service:

```bash
# FFmpeg: extract at 0s (poster), 5s, 10s (preview)
ffmpeg -i input.mp4 \
  -ss 0 -vframes 1 -q:v 2 thumb_0.jpg \
  -ss 5 -vframes 1 -q:v 2 thumb_5.jpg \
  -ss 10 -vframes 1 -q:v 2 thumb_10.jpg
```

```ts
// Store thumbnail URLs
await db.videos.update({
  thumbnailUrl: `https://cdn.example.com/videos/${videoId}/thumb_0.jpg`,
  previewThumbnailUrl: `https://cdn.example.com/videos/${videoId}/thumb_5.jpg`,
}, { where: { id: videoId } });
```

### Stage 4: Completion Webhook
Transcoding service calls back when done:

```ts
// POST /api/videos/transcode-complete
async function handleTranscodeComplete(req: Request) {
  const { jobId, status, outputKey } = await req.json();
  const video = await db.videos.findByJobId(jobId);

  if (status === 'COMPLETE') {
    await db.videos.update({
      status: 'ready',
      hlsPlaylistUrl: `https://cdn.example.com/${outputKey}/index.m3u8`,
      // Store OUTPUT URL, never raw input URL
    }, { where: { id: video.id } });

    await notifyUserVideoReady(video.userId, video.id);
  } else {
    await db.videos.update({ status: 'error' }, { where: { id: video.id } });
  }
}
```

### HLS Playback
```tsx
import Hls from 'hls.js';

function VideoPlayer({ hlsUrl }: { hlsUrl: string }) {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    if (!videoRef.current) return;
    if (Hls.isSupported()) {
      const hls = new Hls();
      hls.loadSource(hlsUrl);
      hls.attachMedia(videoRef.current);
      return () => hls.destroy();
    } else if (videoRef.current.canPlayType('application/vnd.apple.mpegurl')) {
      // Safari native HLS
      videoRef.current.src = hlsUrl;
    }
  }, [hlsUrl]);

  return <video ref={videoRef} controls style={{ width: '100%' }} />;
}
```

## Key Rules
- Store the processed output URL in the DB, not the raw upload URL — the raw file may be deleted after transcoding.
- The client uploads directly to S3/R2 using a presigned URL — never proxy the video bytes through your server.
- Track video status in DB: `pending_upload` → `processing` → `ready` | `error`. Poll or WebSocket for UI updates.
- Extract thumbnails from the raw input, not the transcoded output — faster and available before transcoding completes.
- HLS adaptive streaming is the standard output format — it adjusts quality based on bandwidth and is supported natively on Safari and via hls.js everywhere else.
- Always delete the raw upload after successful transcoding to reduce storage costs — raw H.264 from phones is 3–5x larger than transcoded output.
