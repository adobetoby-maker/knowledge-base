# Local Model: LLM Server Setup

## Overview
Running a local LLM as a server—rather than calling it as a library—decouples your application from the model runtime, enables multiple clients to share one loaded model, and allows hot-swapping models without restarting the application. The three main options (llama.cpp server, Ollama, LM Studio) trade off between control, ease, and production-readiness. Ollama is the fastest path to a working server; llama.cpp gives the most control for production optimization.

## Option 1: Ollama (Easiest, Production-Capable)

```bash
# Install
brew install ollama        # macOS
# or: curl -fsSL https://ollama.com/install.sh | sh   # Linux

# Start server (runs on :11434 by default)
ollama serve

# Pull a model
ollama pull llama3.1:8b

# OpenAI-compatible API endpoint
# Ollama exposes: http://localhost:11434/api/generate
#                 http://localhost:11434/api/chat
#                 http://localhost:11434/v1/chat/completions (OpenAI compat)
```

```ts
// Use OpenAI SDK pointed at Ollama
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'http://localhost:11434/v1',
  apiKey: 'ollama', // Required by SDK but ignored by Ollama
});

const response = await client.chat.completions.create({
  model: 'llama3.1:8b',
  messages: [{ role: 'user', content: 'Hello' }],
});
```

## Option 2: llama.cpp Server (Maximum Control)

```bash
# Build (macOS with Metal GPU acceleration)
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
cmake -B build -DGGML_METAL=ON
cmake --build build --config Release -j 8

# Start server with tuned parameters
./build/bin/llama-server \
  -m /models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf \
  --n-gpu-layers 99 \      # offload all layers to GPU; reduce if VRAM insufficient
  --threads 8 \            # CPU threads for layers NOT on GPU
  --ctx-size 8192 \        # context window size (VRAM grows linearly with this)
  --batch-size 512 \       # prompt evaluation batch size
  --ubatch-size 512 \      # micro-batch for token generation
  --parallel 4 \           # simultaneous request slots
  --port 8080 \
  --host 0.0.0.0 \         # bind to all interfaces (use 127.0.0.1 for local-only)
  --metrics \              # expose /metrics endpoint for Prometheus
  --log-disable            # reduce log noise in production
```

```bash
# Health check endpoint
curl http://localhost:8080/health
# → {"status":"ok"}
```

## Option 3: LM Studio (GUI + Server)

```bash
# LM Studio runs a local server at http://localhost:1234
# Enable: Local Server tab → Start Server
# OpenAI-compatible: http://localhost:1234/v1/chat/completions

# Useful for: development and testing; not for production automation
# Limitation: no CLI control, requires GUI interaction to change models
```

## Model Warm-Up on Startup

```ts
// Send a warm-up request after server starts
// This loads the model into VRAM; first real request won't have cold-start latency

async function waitForServerReady(baseUrl: string, maxAttempts = 30) {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      const res = await fetch(`${baseUrl}/health`);
      if (res.ok) {
        // Server is responding — do a warm-up generation to load model into VRAM
        await fetch(`${baseUrl}/completion`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ prompt: 'Hi', max_tokens: 1, temperature: 0 }),
        });
        console.log('LLM server ready');
        return;
      }
    } catch {
      // Server not ready yet — wait and retry
    }
    await new Promise(r => setTimeout(r, 2000));
  }
  throw new Error('LLM server did not become ready within timeout');
}
```

## Key Configuration Parameters

```
--n-gpu-layers (llama.cpp):
  99 = offload all layers to GPU
  0 = CPU only (slow but works without GPU)
  Adjust if VRAM insufficient: reduce by 5-10 until it fits

  Rule: start at 99, watch VRAM usage, reduce if OOM

--ctx-size:
  Default: 512 (too small for most tasks)
  Practical: 4096–16384 for conversation/RAG
  VRAM cost: each 4K context ≈ 0.5 GB for 7B model at Q4

--threads:
  For CPU-only: set to physical core count (not hyperthreads)
  For GPU with some CPU layers: 4–8 is usually enough

--parallel (llama.cpp) / num_parallel (Ollama):
  Number of simultaneous requests
  Each slot reserves its own KV cache (VRAM multiplier)
  Start with 1; increase if your workload is concurrent
```

## Monitoring

```bash
# llama.cpp exposes /metrics if --metrics flag set
curl http://localhost:8080/metrics
# → Prometheus-format metrics: prompt_tokens, generated_tokens, requests_in_flight

# Ollama logs
journalctl -u ollama -f   # systemd
# or: check ollama serve stdout for request logs
```

## Key Rules
- **Warm-up on startup** — the first inference loads the model into VRAM; send a dummy request before accepting user traffic.
- **`--n-gpu-layers 99` first, then reduce** — easier to reduce if OOM than to guess the right number.
- **`--ctx-size` is a VRAM multiplier** — don't set it larger than your task requires.
- **Ollama for development, llama.cpp for production** — Ollama is easier; llama.cpp gives you control over batching, concurrency, and exact resource limits.
- **Bind to 127.0.0.1 in production** — don't expose the LLM server directly to the network; proxy through your application.
- **`--parallel` multiplies KV cache VRAM** — 4 parallel slots ≈ 4x KV cache; balance concurrency vs memory.
