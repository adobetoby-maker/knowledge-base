# MCP: ComfyUI Workflow

## Overview
The ComfyUI MCP tools bridge image generation into an automated workflow session. Rather than manually constructing workflow JSON from scratch, the pattern is to start with `analyze_workflow` on an existing workflow to understand its node structure, modify only what needs changing, then enqueue and poll for completion. `suggest_settings` resolves the common uncertainty of which sampler/scheduler combination to use for a given checkpoint.

## Core Tools

| Tool | Purpose |
|---|---|
| `analyze_workflow` | Understand node graph of an existing workflow |
| `enqueue_workflow` | Submit a workflow for generation |
| `get_job_status` | Poll status of queued/running job |
| `get_queue` | See all pending jobs |
| `get_history` | Retrieve recent completed jobs |
| `list_output_images` | List generated image files |
| `suggest_settings` | Get checkpoint/sampler recommendations |
| `list_local_models` | See available checkpoints and LoRAs |
| `clear_queue` | Cancel all pending jobs (use when stuck) |
| `get_logs` | Debug ComfyUI server errors |

## Workflow: Generate from Existing Workflow
```
1. list_local_models()
   → identify available checkpoints
   → e.g., "dreamshaperXL_v21.safetensors"

2. suggest_settings(checkpoint: "dreamshaperXL_v21.safetensors")
   → recommended sampler, scheduler, steps, CFG scale

3. get_workflow(name: "txt2img-base")
   → retrieve stored workflow JSON

4. analyze_workflow(workflow: <workflow JSON>)
   → identifies: KSampler node IDs, CLIP text encode nodes, model loader nodes
   → tells you which node_id to target for prompt changes

5. modify_workflow(workflow: <JSON>, changes: {
     node_id: "6",        // CLIPTextEncode (positive)
     inputs: { text: "ultra detailed portrait, golden hour lighting, 8k" }
   })

6. enqueue_workflow(workflow: <modified JSON>)
   → returns job_id: "abc123"
```

## Polling for Completion
```
// Poll every few seconds
get_job_status(job_id: "abc123")
→ status: "pending" | "running" | "complete" | "error"
→ when complete: progress: 100, output_images: ["output/ComfyUI_00123.png"]

// If status stays "pending" for > 2 minutes:
get_queue()
→ check if job is actually in queue or lost
→ if empty queue with no result: clear_queue() and re-enqueue
```

## Workflow: Text-to-Image from Scratch
```
// Use a template workflow rather than building from nodes manually
create_workflow(
  type: "txt2img",
  checkpoint: "dreamshaperXL_v21.safetensors",
  positive_prompt: "...",
  negative_prompt: "...",
  width: 1024,
  height: 1024,
  steps: 30,
  cfg_scale: 7.0,
  sampler: "dpmpp_2m",
  scheduler: "karras"
)
→ returns workflow JSON ready to enqueue
```

## Getting Results
```
// After job completes
list_output_images(limit: 5)
→ returns file paths of recent outputs
→ e.g., "/Users/drive/ComfyUI/output/ComfyUI_00123.png"

// Read the image to display it
read("/Users/drive/ComfyUI/output/ComfyUI_00123.png")
→ image displayed visually in session
```

## Debugging Issues
```
// Job errored
get_job_status(job_id: "abc123")
→ status: "error", error: "CUDA out of memory"

// Resolution: reduce batch size, resolution, or steps
// Then clear and re-enqueue

// ComfyUI not responding
get_logs()
→ check for: model load errors, VRAM exhaustion, missing node packages

// Queue stuck / ghost jobs
clear_queue()
→ removes all pending jobs
→ then re-enqueue your workflow
```

## Key Rules
- **`analyze_workflow` before modifying** — node IDs are UUIDs; don't guess which node is the positive prompt.
- **`suggest_settings` for unknown checkpoints** — sampler/scheduler combos that work well vary by model architecture (SD1.5 vs SDXL vs Flux).
- **Poll `get_job_status`, don't assume completion** — generation takes 10–60+ seconds; always wait for `status === "complete"`.
- **`clear_queue` when stuck** — ghost jobs can block the queue indefinitely; clearing is safe (just re-enqueue).
- **Use `create_workflow` for new generations** — don't construct raw ComfyUI JSON node graphs by hand; use the template helper.
- **Check `list_local_models` before referencing a checkpoint** — model names are case-sensitive and include file extension.
