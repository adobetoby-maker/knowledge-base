# Skill: AI Image Generation Pipeline

## Overview
Image generation is slow (5–60 seconds), unreliable (model failures, VRAM limits), and produces output that may violate safety policies. A production pipeline uses a job queue so the HTTP request returns immediately, polls or webhooks for results, stores output in persistent object storage, and runs safety checks before serving. Never stream unmoderated AI image output directly to users.

## Architecture

```
Client → POST /api/generate → Job queued → 200 { jobId }
                                              ↓
                              Worker picks up job
                                              ↓
                           Generate via ComfyUI / Replicate / FAL
                                              ↓
                              Safety check output
                                              ↓
                              Upload to R2/S3
                                              ↓
                              Update job status in DB
                                              ↓
Client polls GET /api/generate/[jobId]    ← or webhook callback
```

## ComfyUI API Integration

```ts
// lib/comfyui.ts
const COMFYUI_URL = process.env.COMFYUI_URL ?? 'http://localhost:8188'

export async function generateImage(prompt: string, options: {
  width?: number
  height?: number
  steps?: number
  checkpoint?: string
} = {}): Promise<{ image: string; filename: string; prompt_id: string }> {
  const { width = 512, height = 512, steps = 20, checkpoint = 'v1-5-pruned.ckpt' } = options

  const workflow = buildWorkflow(prompt, { width, height, steps, checkpoint })

  const res = await fetch(`${COMFYUI_URL}/prompt`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ prompt: workflow }),
  })
  const { prompt_id } = await res.json()

  // Poll for completion
  const image = await pollForResult(prompt_id)
  return image
}

async function pollForResult(promptId: string, maxAttempts = 60): Promise<any> {
  for (let i = 0; i < maxAttempts; i++) {
    await new Promise(r => setTimeout(r, 1000))
    const history = await fetch(`${COMFYUI_URL}/history/${promptId}`).then(r => r.json())
    if (history[promptId]?.status?.completed) {
      return history[promptId].outputs
    }
  }
  throw new Error(`Generation timed out after ${maxAttempts}s`)
}
```

## Hosted Alternative: Replicate / FAL

For serverless, no-infrastructure option:

```ts
// FAL hosted generation
import { fal } from '@fal-ai/client'

const result = await fal.subscribe('fal-ai/flux/dev', {
  input: { prompt, image_size: 'landscape_4_3', num_images: 1 },
  onQueueUpdate: (update) => {
    if (update.status === 'IN_PROGRESS') {
      console.log('Generating...', update.logs)
    }
  },
})
// result.images[0].url — temporary CDN URL (expires in ~1 hour, must copy to own storage)
```

## Retry on Failure

```ts
async function generateWithRetry(prompt: string, attempts = 3): Promise<string> {
  for (let i = 0; i < attempts; i++) {
    try {
      return await generateImage(prompt)
    } catch (err) {
      if (i === attempts - 1) throw err
      console.warn(`Generation attempt ${i + 1} failed:`, err)
      await new Promise(r => setTimeout(r, 2000 * (i + 1)))
    }
  }
  throw new Error('unreachable')
}
```

## Store in R2/S3

Hosted generation URLs expire. Always copy to your own storage:

```ts
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3'

async function storeGeneratedImage(imageUrl: string, key: string): Promise<string> {
  const imageResponse = await fetch(imageUrl)
  const buffer = await imageResponse.arrayBuffer()

  await s3.send(new PutObjectCommand({
    Bucket: process.env.R2_BUCKET_NAME,
    Key: `generated/${key}.webp`,
    Body: Buffer.from(buffer),
    ContentType: 'image/webp',
  }))

  return `https://${process.env.R2_PUBLIC_DOMAIN}/generated/${key}.webp`
}
```

## Safety Check

Before storing or serving output:

```ts
// Use Replicate's NSFW classifier or similar
async function isSafe(imageBuffer: Buffer): Promise<boolean> {
  const result = await fal.run('fal-ai/nsfw-image-detection', {
    input: { image_url: toDataURL(imageBuffer) },
  })
  return result.is_safe === true
}

// In the pipeline:
const imageBuffer = await fetchImage(generatedUrl)
if (!await isSafe(imageBuffer)) {
  await db.jobs.update({ status: 'rejected', reason: 'safety_check_failed' })
  return
}
```

## Serve via Signed URL

Don't expose R2/S3 directly to the public:

```ts
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'
import { GetObjectCommand } from '@aws-sdk/client-s3'

const signedUrl = await getSignedUrl(s3, new GetObjectCommand({
  Bucket: process.env.R2_BUCKET_NAME,
  Key: `generated/${imageId}.webp`,
}), { expiresIn: 3600 }) // 1 hour
```

## Key Rules
- Return a job ID immediately — never make the user wait for generation in a single HTTP response
- Copy output from hosted generation services to your own storage — temporary URLs expire
- Run safety checks before marking a job as complete and before serving to users
- Idempotency: if a job is retried, check if output already exists before re-generating
- Log prompts and results for moderation review — not just errors
- Thumbnail generation from the result image helps UX (load fast, click to expand)
