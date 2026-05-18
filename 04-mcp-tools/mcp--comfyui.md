# MCP: ComfyUI — Image Generation

## What It Does

ComfyUI is a node-based stable diffusion interface. The ComfyUI MCP exposes tools to create, manage, and run image generation workflows.

## Tool Reference

```
mcp__plugin_comfy_comfyui__get_system_stats        ← Check if ComfyUI is running
mcp__plugin_comfy_comfyui__start_comfyui            ← Start if not running
mcp__plugin_comfy_comfyui__list_local_models        ← Available checkpoints
mcp__plugin_comfy_comfyui__enqueue_workflow(workflow_json)
mcp__plugin_comfy_comfyui__get_job_status(prompt_id)
mcp__plugin_comfy_comfyui__get_history(prompt_id)
mcp__plugin_comfy_comfyui__list_output_images
mcp__plugin_comfy_comfyui__create_workflow(description)  ← Generate workflow from description
mcp__plugin_comfy_comfyui__search_models(query)
mcp__plugin_comfy_comfyui__download_model(url, name, type)
```

## Basic Image Generation Flow

1. Check if ComfyUI is running: `get_system_stats()`
2. If not running: `start_comfyui()`
3. Check available models: `list_local_models()`
4. Create or provide a workflow JSON
5. Queue it: `enqueue_workflow(workflow_json)` → returns `prompt_id`
6. Poll for completion: `get_job_status(prompt_id)`
7. Get output: `get_history(prompt_id)` → image paths

## Via manage-worker-bee API (Recommended)

For simple generation from project code, use the manage-worker-bee image-gen API which handles the ComfyUI complexity:

```typescript
const response = await fetch('https://manage.worker-bee.app/api/image-gen', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': process.env.MANAGE_API_KEY,
  },
  body: JSON.stringify({
    prompt: 'professional product photo, white background, high quality',
    width: 1024,
    height: 1024,
    steps: 20,
  })
})

const { image } = await response.json()
// image = "data:image/png;base64,..."
```

## Workflow Structure

ComfyUI workflows are JSON node graphs. Each node has an `id`, `class_type`, and `inputs`:

```json
{
  "1": {
    "class_type": "CheckpointLoaderSimple",
    "inputs": { "ckpt_name": "realistic_vision_v5.safetensors" }
  },
  "2": {
    "class_type": "CLIPTextEncode",
    "inputs": {
      "text": "your prompt here",
      "clip": ["1", 1]
    }
  },
  "3": {
    "class_type": "KSampler",
    "inputs": {
      "model": ["1", 0],
      "positive": ["2", 0],
      "negative": ["4", 0],
      "seed": 42,
      "steps": 20,
      "cfg": 7,
      "sampler_name": "dpm_2",
      "scheduler": "karras",
      "denoise": 1
    }
  }
}
```

## Generating Workflows with AI

```
create_workflow("Generate a realistic photo of a car repair shop interior, bright lighting, professional photography")
```

Returns a workflow JSON that can be directly passed to `enqueue_workflow`.

## Model Types

| Type | Location | Used For |
|------|----------|---------|
| Checkpoint | models/checkpoints/ | Base model |
| LoRA | models/loras/ | Style/character adaptation |
| VAE | models/vae/ | Latent space decoder |
| Embedding | models/embeddings/ | Token embeddings |

Common checkpoint names available in the local setup:
- `realistic_vision_v5.safetensors` — photorealistic
- `dreamshaper_8.safetensors` — general purpose, artistic

## Upscaling

After generation, use upscale nodes in the workflow or:
```
mcp__plugin_comfy_comfyui__modify_workflow(workflow_json, "add 4x upscaling after generation")
```

## Performance Notes

- Image generation takes 15-60 seconds depending on steps, resolution, and hardware
- Steps 15-20: good quality, fast. Steps 30+: diminishing returns
- Resolution above 1024×1024 requires significant VRAM
- Poll with `get_job_status` every 2-3 seconds, not every 100ms
