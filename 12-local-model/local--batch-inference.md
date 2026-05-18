# Local Model: Batch Inference Optimization

## Overview
Local models run one forward pass per request by default, leaving GPU compute idle between requests. Batch inference processes multiple prompts together in a single forward pass, dramatically improving throughput for offline workloads. Continuous batching (as implemented in llama.cpp and vLLM) extends this to live traffic by dynamically filling the batch as requests arrive, without waiting for all slots to complete before accepting new ones.

## Why Batching Matters

```
Single request: GPU utilization ~20-40% (most time waiting for memory bandwidth)
Batch of 4:     GPU utilization ~60-80% (compute bound, not memory bound)
Batch of 8+:    GPU utilization ~80-95% (near theoretical maximum throughput)

Throughput (tokens/second) scales roughly with batch size up to the memory limit
Latency per request increases proportionally with batch size
```

## Offline Batch Processing Pattern

```ts
interface BatchJob {
  id: string;
  prompt: string;
}

async function processBatch(
  jobs: BatchJob[],
  batchSize: number,
  model: string
): Promise<Map<string, string>> {
  const results = new Map<string, string>();

  // Process in chunks
  for (let i = 0; i < jobs.length; i += batchSize) {
    const batch = jobs.slice(i, i + batchSize);

    // Send all requests concurrently (server handles batching internally)
    const responses = await Promise.all(
      batch.map(job =>
        fetch('http://localhost:8080/completion', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            prompt: job.prompt,
            n_predict: 512,
            temperature: 0.1,
          }),
        }).then(r => r.json())
      )
    );

    for (let j = 0; j < batch.length; j++) {
      results.set(batch[j].id, responses[j].content);
    }

    console.log(`Processed ${Math.min(i + batchSize, jobs.length)} / ${jobs.length}`);
  }

  return results;
}

// Usage: classify 10,000 support tickets
const tickets = await db.tickets.findUnclassified();
const results = await processBatch(
  tickets.map(t => ({ id: t.id, prompt: `Classify this ticket: ${t.body}` })),
  batchSize: 8,  // adjust based on VRAM
  model: 'llama3.1:8b'
);
```

## Continuous Batching (llama.cpp server)

```bash
# llama.cpp --parallel enables continuous batching
# New requests fill slots as previous requests complete
./llama-server \
  -m /models/model-Q4_K_M.gguf \
  --n-gpu-layers 99 \
  --parallel 8 \          # 8 simultaneous request slots
  --ctx-size 2048 \       # per-slot context (8 × 2048 = 16K total KV cache)
  --batch-size 512 \      # prompt tokens processed per forward pass
  --port 8080
```

## VRAM Calculation for Batch Size

```
Total VRAM = Model weights + (batch_size × per_slot_KV_cache)

Per-slot KV cache = 2 × num_layers × num_kv_heads × head_dim × ctx_size × bytes_per_element
Rough estimate: ~0.5 MB per 1K context tokens for a 7B model at Q4

Example: 7B Q4_K_M, --parallel 8, --ctx-size 4096:
  Model:      ~5 GB
  KV cache:   8 slots × 4096 tokens × ~0.5 MB/1K tokens ≈ 16 GB
  Total:      ~21 GB ← requires A100 or equivalent

Practical configuration for 24 GB VRAM:
  --parallel 4 --ctx-size 4096    → 8 GB KV cache + 5 GB model = 13 GB
  --parallel 2 --ctx-size 8192    → 8 GB KV cache + 5 GB model = 13 GB
  --parallel 8 --ctx-size 2048    → 8 GB KV cache + 5 GB model = 13 GB
```

## Throughput vs Latency Tradeoff

```
Low batch size (1-2):
  → Low latency per request (~500ms for 200 tokens)
  → Low throughput (~20 tokens/sec total)
  → Use for: interactive chat, real-time applications

Medium batch size (4-8):
  → Moderate latency per request (~1-2s for 200 tokens)
  → High throughput (~60-100 tokens/sec total)
  → Use for: API serving with mixed load

Large batch size (16+):
  → High latency per request (~3-5s for 200 tokens)
  → Maximum throughput (~100-150 tokens/sec total)
  → Use for: offline processing, bulk classification, data labeling
```

## Queue Management for Concurrent Requests

```ts
import PQueue from 'p-queue';

// Limit concurrent requests to match server's --parallel setting
const queue = new PQueue({ concurrency: 8 });

async function generateWithQueue(prompt: string): Promise<string> {
  return queue.add(async () => {
    const response = await fetch('http://localhost:8080/completion', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt, n_predict: 512 }),
    });
    const data = await response.json();
    return data.content;
  });
}

// Now safe to call concurrently without overwhelming the server
const results = await Promise.all(prompts.map(p => generateWithQueue(p)));
```

## Key Rules
- **Match concurrency to `--parallel`** — sending more requests than server slots causes queuing in the server; match your client concurrency to the server's slot count.
- **Batch offline tasks, stream interactive ones** — batch processing for classification/extraction jobs; single requests for chat.
- **KV cache is the VRAM multiplier** — `--parallel × --ctx-size × factor` determines KV cache VRAM; this often exceeds model weight VRAM.
- **Use `p-queue` to bound client concurrency** — `Promise.all()` on 1,000 requests floods the server; a bounded queue prevents this.
- **Measure throughput, not just latency** — a batch of 8 might have 2x the per-request latency but 5x the total throughput.
- **Warm up before benchmarking** — first batch always slower due to model loading; discard the first measurement.
