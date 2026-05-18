# Image Captioning with Local Vision Models

Local vision models — primarily LLaVA variants and Moondream — can generate image captions without sending data to a cloud API. This matters for internal product photos, medical images, proprietary documents, or any context where images shouldn't leave your infrastructure. The tradeoff is quality: local vision models lag behind GPT-4V and Claude on complex scenes, small text, and spatial reasoning, but perform well for standard object/scene description.

## Model Options via Ollama

**LLaVA 1.6 (34B)**: Best quality among local options. Requires ~24GB VRAM. Useful for complex scenes, document images, or product photos where accuracy matters.

**LLaVA 1.6 (7B/13B)**: Good for standard captioning tasks. Runs on consumer hardware with 8–16GB VRAM.

**Moondream 2**: Optimized for speed and small footprint (~1.8B parameters). Suited for alt text generation at scale where throughput > accuracy. Can run on CPU for small batches.

Pull via Ollama: `ollama pull llava:13b` or `ollama pull moondream`.

## Base64 Image Encoding

Ollama's vision API accepts images as base64-encoded strings. Encode in Python:

```python
import base64

with open("image.jpg", "rb") as f:
    image_b64 = base64.b64encode(f.read()).decode("utf-8")

response = ollama.chat(
    model="llava:13b",
    messages=[{
        "role": "user",
        "content": "Describe this image.",
        "images": [image_b64]
    }]
)
```

Resize large images before encoding. Vision models typically downsample to 336×336 or 672×672 internally; sending a 4K image wastes bandwidth and increases latency without improving quality. Resize to the model's native resolution first (check model card), or cap at 1024px on the longest side.

## Caption Length Control

Different use cases need different caption lengths. Be explicit in the prompt:

- **Alt text**: "Describe this image in one sentence, 10–15 words, suitable for a screen reader."
- **Product description**: "Describe the product in 2–3 sentences covering appearance, material, and any visible features."
- **Detailed description**: "Provide a thorough description of this image in 100–150 words, including objects, spatial relationships, colors, and context."

Local models left unconstrained will generate mid-length descriptions by default — not suitable for either terse alt text or detailed catalogs.

## Structured Output

For programmatic pipelines, request structured output rather than free text:

```
Return JSON with these fields:
{
  "alt_text": "Brief description for screen readers (under 125 characters)",
  "description": "Detailed description in 2-3 sentences",
  "objects": ["list", "of", "main", "objects"],
  "dominant_colors": ["blue", "white"]
}
```

LLaVA models follow this reasonably well when the structure is clear. Validate the JSON schema after extraction — local models occasionally drop fields or add extra keys.

## Batch Processing

For large image sets (product catalogs, document archives), process in parallel. Ollama serves one request at a time by default; run multiple Ollama instances on different ports, or use a queue with concurrent async requests:

- For CPU inference: 2–4 concurrent processes
- For GPU inference: 1 process per GPU; pipeline the encoding step

Track failed or low-confidence captions separately. If the response contains "I can't tell" or "the image appears to be blank," flag for manual review rather than saving a bad caption.

## Key Rules

- Use LLaVA 13B for quality, Moondream for throughput
- Resize images to the model's native resolution before encoding — don't send raw 4K images
- Always specify caption length explicitly in the prompt
- Request structured JSON output for programmatic pipelines, validate schema
- Run multiple instances for batch jobs; Ollama is single-threaded per instance
- Flag "I can't tell" or blank-image responses for manual review
- Local vision models are unreliable on small text in images — route OCR tasks to a dedicated model or cloud
