# Local Model: Multi-Modal with Local Models

## Overview
Running multi-modal AI locally requires assembling a pipeline from separate specialized models—no single local model matches the breadth of a hosted multi-modal API. LLaVA/Llava-Next handles image understanding, whisper.cpp handles transcription, and ComfyUI handles image generation. Understanding the hardware requirements for each before committing avoids deploying to hardware that can't run the pipeline. The key insight is that each model has a fixed VRAM cost and they must coexist or be swapped in/out.

## Image Understanding — LLaVA via Ollama

```ts
import Ollama from 'ollama';
import fs from 'fs';

// Read image as base64
const imageBase64 = fs.readFileSync('/path/to/image.png').toString('base64');

const response = await ollama.chat({
  model: 'llava:13b',  // or llava:7b for less VRAM
  messages: [{
    role: 'user',
    content: 'Describe what you see in this image. What text is visible?',
    images: [imageBase64],
  }],
});

console.log(response.message.content);
// → "The image shows a dashboard with a bar chart. The title reads 'Monthly Revenue'..."
```

## Audio Transcription — whisper.cpp

```ts
// whisper.cpp offers a Node.js binding or can be called as subprocess
import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

async function transcribeAudio(audioPath: string, language = 'en'): Promise<string> {
  // whisper.cpp CLI
  const { stdout } = await execFileAsync('whisper-cli', [
    '-m', '/models/ggml-base.en.bin',  // model path
    '-f', audioPath,
    '-l', language,
    '--output-txt',
    '--no-timestamps',
  ]);
  return stdout.trim();
}

// For longer audio, use chunking:
// Split into 30-second segments, transcribe each, concatenate
// whisper context window is 30 seconds; longer input is truncated
```

## Image Generation — ComfyUI API

```ts
// Use the ComfyUI REST API (or MCP tools in session)
async function generateImage(prompt: string, width = 512, height = 512): Promise<Buffer> {
  // Enqueue a workflow
  const queueResponse = await fetch('http://localhost:8188/prompt', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      prompt: buildWorkflow(prompt, width, height),
      client_id: 'my-app',
    }),
  });
  const { prompt_id } = await queueResponse.json();

  // Poll for completion
  let outputImage: string | null = null;
  while (!outputImage) {
    await new Promise(r => setTimeout(r, 1000));
    const historyRes = await fetch(`http://localhost:8188/history/${prompt_id}`);
    const history = await historyRes.json();
    const job = history[prompt_id];
    if (job?.outputs) {
      const imgInfo = Object.values(job.outputs)[0].images[0];
      outputImage = imgInfo.filename;
    }
  }

  // Download the image
  const imgRes = await fetch(`http://localhost:8188/view?filename=${outputImage}`);
  return Buffer.from(await imgRes.arrayBuffer());
}
```

## Multi-Modal Pipeline: Transcribe → Analyze → Respond

```ts
async function processVoiceWithImage(audioPath: string, imagePath: string) {
  // Step 1: Transcribe audio
  const question = await transcribeAudio(audioPath);
  console.log('Question:', question);
  // → "What does this chart show?"

  // Step 2: Analyze image with question context
  const imageBase64 = fs.readFileSync(imagePath).toString('base64');
  const analysis = await ollama.chat({
    model: 'llava:13b',
    messages: [{
      role: 'user',
      content: question,
      images: [imageBase64],
    }],
  });

  return analysis.message.content;
}
```

## Hardware Requirements

```
Model               VRAM Required    RAM Fallback (slow)
---------------------------------------------------------
llava:7b            ~6 GB            ~12 GB RAM
llava:13b           ~10 GB           ~20 GB RAM
whisper-base        ~200 MB          works fine on CPU
whisper-large-v3    ~3 GB            ~6 GB RAM on CPU
ComfyUI SD1.5       ~4 GB            not practical
ComfyUI SDXL        ~8 GB            not practical
ComfyUI Flux.1-dev  ~16 GB           not practical

Coexistence strategy:
- whisper runs CPU-only; no VRAM competition
- Unload LLaVA before loading Flux; ollama pull handles this
- Or: separate machines for generation vs understanding
```

## Batching Images for Efficiency

```ts
// Process multiple images more efficiently by reusing the model context
async function analyzeImageBatch(images: string[], prompt: string) {
  const results: string[] = [];

  // Sequential is usually necessary (VRAM-bound)
  // But you can pre-load the model with a warm-up call
  await ollama.chat({ model: 'llava:7b', messages: [{ role: 'user', content: 'hello', images: [] }] });

  for (const imagePath of images) {
    const base64 = fs.readFileSync(imagePath).toString('base64');
    const response = await ollama.chat({
      model: 'llava:7b',
      messages: [{ role: 'user', content: prompt, images: [base64] }],
    });
    results.push(response.message.content);
  }

  return results;
}
```

## Key Rules
- **Check VRAM before deployment** — multi-modal pipelines are VRAM-constrained; confirm hardware can run the chosen models.
- **Whisper on CPU** — audio transcription is fast enough on CPU and frees GPU for image models.
- **LLaVA quality scales with size** — llava:7b misses text in images; llava:13b is meaningfully better at OCR-adjacent tasks.
- **ComfyUI via API not subprocess** — ComfyUI's REST API is stable; calling it as a subprocess is fragile.
- **whisper context is 30 seconds** — split audio files longer than 30 seconds into chunks; overlap by 1–2 seconds to avoid cut words.
- **Prompt quality matters for LLaVA** — "describe this image" produces generic output; "list all text visible, describe the chart type and any trends" produces actionable output.
