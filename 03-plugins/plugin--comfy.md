# Plugin: comfy@comfyui-mcp

**What it provides:** ComfyUI image generation — create, queue, and retrieve AI-generated images.
**When to reach for it:** Generating images for client sites, creating hero images, generating design mockups.

## Key Skills
- `comfy:gen` — generate an image from a text prompt
- `comfy:flux-txt2img` — Flux model text-to-image (highest quality)
- `comfy:qwen-txt2img` — Qwen model text-to-image
- `comfy:qwen-image-edit` — edit an existing image with instructions
- `comfy:z-image-txt2img` — alternative model
- `comfy:director` — director mode for scene composition
- `comfy:debug` — debug workflow failures
- `comfy:troubleshooting` — diagnose ComfyUI issues
- `comfy:gallery` — view recent generated images
- `comfy:batch` — batch generation
- `comfy:install` — install custom nodes

## Key MCP Tools

```javascript
// Generate an image
mcp__plugin_comfy_comfyui__enqueue_workflow({ workflow: {...} })

// Check generation status
mcp__plugin_comfy_comfyui__get_job_status({ job_id: "..." })

// Get generated image
mcp__plugin_comfy_comfyui__list_output_images({})

// List available models
mcp__plugin_comfy_comfyui__list_local_models({})

// Check system status
mcp__plugin_comfy_comfyui__get_system_stats({})

// Search for custom nodes to install
mcp__plugin_comfy_comfyui__search_custom_nodes({ query: "..." })

// Get workflow from image (extracts embedded workflow)
mcp__plugin_comfy_comfyui__workflow_from_image({ image_path: "..." })
```

## Image Gen via manage-worker-bee API
For client projects, use the proxied image gen endpoint:
```typescript
// POST /api/image-gen in manage-worker-bee
const response = await fetch('https://manage.worker-bee.app/api/image-gen', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    prompt: "professional auto repair shop, modern, clean, Twin Falls Idaho",
    width: 1200,
    height: 630,
    steps: 20,
    checkpoint: "flux"  // optional
  })
})
const { image } = await response.json()
// image = "data:image/png;base64,..."
```

## Prompt Engineering for Site Images
For client website images, prompt structure:
```
[subject], [setting], [style], [mood], [technical specs]

Examples:
"Toyota Camry in auto repair shop, mechanic working, professional photography, warm lighting, 16:9 composition"
"Semi truck on Idaho highway at sunset, logistics company branding, photorealistic, wide angle"
"Language learning app interface, colorful UI, modern flat design, white background"
```

## Common Failure Modes
1. **ComfyUI not running** — check system stats: `get_system_stats` — if offline, `start_comfyui`
2. **Model not found** — list available models: `list_local_models` — use exact model name
3. **Job queued but not completing** — check queue: `get_queue` — clear if stuck: `clear_queue`
4. **Out of VRAM** — run `clear_vram`, then retry with lower resolution or fewer steps
