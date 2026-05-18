# Running Inference On-Device (Browser/Mobile)

## Why On-Device

On-device inference eliminates the server roundtrip (latency), removes the API cost, and keeps user data local (privacy). The tradeoff is significant: models are smaller, quantization reduces quality, and initial load time (model download + WASM compilation) is measured in seconds to minutes.

On-device is not a default choice — it's a deliberate tradeoff for specific use cases.

## WebLLM / MLC for Browser Inference

WebLLM (https://webllm.mlc.ai) runs quantized LLMs in the browser via WebGPU. The execution engine is MLC-LLM compiled to WebAssembly + WebGPU shaders.

Setup:
```js
import { CreateMLCEngine } from "@mlc-ai/web-llm";
const engine = await CreateMLCEngine("Llama-3.2-1B-Instruct-q4f32_1-MLC", {
  initProgressCallback: (progress) => console.log(progress.text),
});
const reply = await engine.chat.completions.create({
  messages: [{ role: "user", content: "Hello" }],
});
```

WebGPU is required for hardware acceleration. Browsers without WebGPU fall back to CPU via WASM, which is 10–50x slower. Check `navigator.gpu` before loading the engine and show a "not supported" message rather than a 5-minute hang on CPU fallback.

## WASM-Based Models

For environments without WebGPU (older browsers, Firefox with WebGPU disabled), WASM-only inference is an option for very small models (≤500M parameters). Libraries: `llama.cpp` compiled to WASM (`llama-cpp-wasm`), `transformers.js` for encoder models.

`transformers.js` runs BERT-class models in browser without WebGPU — viable for classification, embedding, and NER tasks where the output space is constrained. For generative inference, WASM-only is too slow for most users.

## Quantization Tradeoffs

Model size on device is primarily determined by quantization:

| Quantization | Bits/weight | Quality loss | 1B model size | 7B model size |
|---|---|---|---|---|
| FP16 | 16 | None (baseline) | ~2GB | ~14GB |
| INT8 | 8 | Minimal | ~1GB | ~7GB |
| INT4/Q4 | 4 | Moderate | ~500MB | ~4GB |
| INT2 | 2 | Significant | ~250MB | ~2GB |

For browser inference, Q4 (4-bit) is the standard. It fits 1B–3B models in VRAM while keeping quality acceptable for classification/extraction tasks. Generative quality at Q4 with a 1B model is noticeably worse than a server-side 7B — set user expectations accordingly.

Never run a model >3B parameters in the browser. Beyond that, download time alone exceeds user patience.

## Warm-Up Time

First inference is always slow:
1. Model download: 500MB–2GB over the network (one-time, then cached in IndexedDB/Origin Private File System)
2. WASM compilation and shader compilation: 5–30s depending on browser/GPU
3. Model load into VRAM: 2–10s

Show explicit progress UI for each phase. Users abandon invisible loads after 3–5 seconds. After the first load, subsequent page visits use the cached model — warm-up drops to 2–5s for shader recompilation.

Prefetch and cache the model during an idle window (e.g., on app install as a Service Worker precache step) rather than blocking the user's first inference request.

## Which Tasks Justify On-Device

**Strong on-device candidates:**
- Privacy-sensitive text processing (medical notes, personal documents, legal text)
- Offline functionality requirement (field apps, embedded tools)
- Very high volume / cost-sensitive classification where quality tradeoff is acceptable
- Interactive demos where API key exposure would be a security risk

**Poor on-device candidates:**
- Tasks requiring models >3B for acceptable quality
- Users on low-end mobile (limited VRAM, slow WASM)
- Any task where server-side processing adds <500ms total latency
- Long-form generation (slow, quality suffers at small model sizes)

The default should be server inference. On-device is an optimization for specific constraints, not a general architecture preference.

## Key Rules

- Check `navigator.gpu` before initializing WebLLM; surface a clear error on unsupported browsers rather than a silent WASM-only slowdown.
- Use Q4 quantization for browser inference; never attempt to load a model >3B in the browser.
- Show download and compile progress with an explicit UI — invisible loads >3s cause abandonment.
- Prefetch and cache the model during idle time (Service Worker install), not on first user interaction.
- Justify on-device with a specific constraint (privacy, offline, cost); don't default to it because it's technically possible.
- Test on low-end hardware (2GB integrated GPU); what runs fine on your M3 MacBook may hang a Chromebook.
