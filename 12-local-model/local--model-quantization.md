# Local Model: GGUF Quantization Levels

## Overview
GGUF quantization compresses a model's weights from 16-bit or 32-bit floats to lower-precision integers, trading model quality for speed and memory reduction. Choosing the wrong quantization level means either wasting VRAM on quality you won't notice, or degrading accuracy so much the model fails your task. Q4_K_M is the practical default for most tasks—it fits in reasonable VRAM and produces quality indistinguishable from FP16 on most benchmarks.

## Quantization Levels Reference

```
Format      Bits/weight   Quality vs FP16   Relative Size   Notes
----------------------------------------------------------------------
FP16        16            Baseline          100%            Gold standard; needs most VRAM
Q8_0        8             ~99%              50%             Nearly lossless; good for code
Q6_K        6             ~98%              38%             Sweet spot for quality-conscious
Q5_K_M      5             ~97%              30%             Slightly better than Q4 for tasks
Q4_K_M      4             ~95%             25%             RECOMMENDED default
Q4_K_S      4             ~94%             24%             Slightly smaller, slightly worse
Q3_K_M      3             ~90%             19%             Noticeable degradation; use cautiously
Q2_K        2             ~75-80%           13%             Significant degradation; rarely useful
IQ4_XS      ~4 (iMatrix)  ~95%             22%             Better than Q4_K for same size
IQ3_M       ~3 (iMatrix)  ~92%             17%             Better than Q3_K for same size
```

## What "K" and "M/S/L" Mean

```
K = K-quants: quantize different weight matrices at different precision
  → attention weights and important layers stay higher precision
  → less important layers go lower
  → better quality per bit than uniform quantization

M/S/L = size variant:
  M = medium (balanced) — recommended
  S = small (slightly smaller file, slightly lower quality)
  L = large (slightly bigger file, slightly better quality)
  XS = extra small

iMatrix (IQ quants) = importance matrix:
  → uses calibration data to identify which weights matter most
  → weights those weights more carefully during quantization
  → produces better quality at the same file size vs K-quants
  → requires an imatrix calibration file during quantization
```

## VRAM Requirements by Model Size + Quantization

```
Model         Q4_K_M     Q8_0      FP16
Llama 3.1 8B  ~5 GB      ~9 GB     ~16 GB
Llama 3.1 70B ~40 GB     ~70 GB    ~140 GB
Qwen2.5 7B    ~5 GB      ~8 GB     ~15 GB
Qwen2.5 14B   ~9 GB      ~15 GB    ~28 GB
Phi-3 mini    ~2.5 GB    ~4 GB     ~7 GB
Mistral 7B    ~5 GB      ~8 GB     ~15 GB

Rule of thumb: multiply parameter count by bytes per weight
  Q4_K_M ≈ params × 0.5 bytes (4 bits = 0.5 bytes)
  Q8_0   ≈ params × 1 byte
  FP16   ≈ params × 2 bytes
  Plus ~1-2 GB overhead for KV cache at typical context lengths
```

## Choosing the Right Quantization

```
Task: general chat, summarization, classification
→ Q4_K_M: quality is indistinguishable from FP16 for most users

Task: code generation, function calling, structured JSON output
→ Q8_0: code quality is more sensitive to quantization than text
→ Or: Q5_K_M as a middle ground

Task: math, reasoning, multi-step logic
→ Q6_K or Q8_0: numerical reasoning degrades noticeably below Q5

Task: production API with high throughput (batching many requests)
→ Q4_K_M: maximize requests per GPU; quality is sufficient

Task: maximum possible quality, have the VRAM
→ FP16 or Q8_0: no quality compromise

Task: severely constrained VRAM (8 GB laptop GPU, 7B model)
→ IQ4_XS: best quality at smallest size via iMatrix
```

## Practical: Downloading the Right Variant

```bash
# Ollama (handles quantization selection automatically based on VRAM)
ollama pull llama3.1:8b-instruct-q4_K_M
ollama pull llama3.1:8b-instruct-q8_0

# Manual download from Hugging Face (TheBloke / bartowski repos have pre-quantized GGUF)
# Model name pattern: ModelName-Q4_K_M.gguf

# Load in llama.cpp
./llama-server \
  -m /models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf \
  --n-gpu-layers 35 \   # offload all layers to GPU (adjust to VRAM)
  --ctx-size 8192 \     # context window (larger = more VRAM)
  --port 8080
```

## Key Rules
- **Q4_K_M is the default** — it's the community-agreed sweet spot: 25% of FP16 size with 95% of quality.
- **Q8_0 for code** — code generation and structured output degrade more than text at lower precision.
- **Never Q2_K for production** — quality loss is visible; only useful for extreme VRAM constraints with quality tradeoffs you've explicitly accepted.
- **iMatrix quants (IQ) beat K-quants at same size** — when available, IQ4_XS is better than Q4_K_S.
- **Measure, don't guess** — run your actual task against Q4_K_M vs Q8_0 before assuming you need higher quality.
- **Context window multiplies VRAM** — a 7B model at Q4_K_M fits in 5 GB, but add 32K context and the KV cache adds 2–4 GB.
