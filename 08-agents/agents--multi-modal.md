# Multi-Modal Agents (Vision + Text)

Multi-modal agents process images alongside text. The core challenge is not the API call — it's knowing when vision adds value vs. when it's wasteful, and structuring prompts so image analysis integrates cleanly with text reasoning.

## Model Selection

Not all models process images equally. Use the most capable vision model available for tasks requiring fine-grained detail: reading text in screenshots, analyzing charts, comparing UI elements. Use smaller models only for coarse classification (is this an image of a person, product, or document).

When routing, ask: does this task require reading text from an image, or just identifying what the image depicts? Text extraction from images needs stronger models. Scene classification can use lighter ones.

## Image Input Format

**Base64** — use for images you already have on disk or in memory:

```python
import base64

with open("image.png", "rb") as f:
    b64 = base64.standard_b64encode(f.read()).decode("utf-8")

message = client.messages.create(
    model="claude-opus-4-5",
    messages=[{
        "role": "user",
        "content": [
            {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": b64}},
            {"type": "text", "text": "What does this dashboard show?"}
        ]
    }]
)
```

**URL** — use for publicly accessible images. The model fetches them at inference time; no transfer cost on your side. Avoid for private images or when latency predictability matters (external fetch can fail or be slow).

Supported formats: JPEG, PNG, GIF, WEBP. Max image size varies by provider — check docs for the model you're using. Resize large images before sending; a 4000×3000 photo rarely needs full resolution for most analysis tasks.

## Token Cost of Images

Images consume tokens based on their pixel dimensions, not file size. A full-size 1568×1568 image costs roughly 1600 tokens. A thumbnail costs far less. Budget accordingly when building loops that process many images.

Practical guidelines:
- Resize to the smallest resolution where the relevant detail is still readable
- For UI screenshots, 1280px wide is usually sufficient
- For document text extraction, keep resolution high enough to read all characters clearly
- Never send the same image multiple times in the same conversation — reference it by position in prior messages

## Combining Vision with Text Reasoning

The failure mode is asking the model to do everything in one prompt: "look at this image and write a report." Structure the reasoning instead.

**Two-phase pattern:**

```
Phase 1 — Extract: "Describe everything visible in this chart: axes, labels, trend direction, any anomalies."
Phase 2 — Reason: "Given that description: [description from phase 1], which product line is underperforming and why?"
```

This separates perceptual work from analytical work. It also makes the extracted description auditable — you can log it, validate it, or pass it to a cheaper text-only model for the reasoning step.

For document analysis, extract structured data first (table rows, field values, key-value pairs), then reason over the structure.

## Multi-Image Comparisons

When comparing multiple images (before/after, design variants, chart series), number them explicitly and reference them by number in the prompt:

```python
content = [
    {"type": "text", "text": "Image 1 is the original design. Image 2 is the proposed redesign."},
    {"type": "image", "source": {...}},  # Image 1
    {"type": "image", "source": {...}},  # Image 2
    {"type": "text", "text": "List the visual differences between Image 1 and Image 2."}
]
```

Without explicit numbering, models can confuse which image they're analyzing.

## Agent Loop Integration

When an agent needs to analyze screenshots as part of a task loop (web automation, UI testing):

1. Capture the screenshot at the moment you need analysis — stale screenshots cause wrong decisions
2. Pass the screenshot plus the current task context in a single message
3. Parse the response for structured action decisions (click, type, navigate) before proceeding
4. Do not keep old screenshots in context beyond where they're needed — they waste tokens

## Key Rules

- Resize images to the minimum useful resolution — oversized images waste tokens without improving analysis
- Use base64 for private images; use URL only for public, stable assets
- Split extraction from reasoning in two-phase prompts for auditable, verifiable results
- Number images explicitly in multi-image prompts to avoid cross-image confusion
- Avoid sending duplicate images in the same conversation turn
- Budget token cost per image when designing loops that process many images
- Use stronger vision models for OCR/text extraction; lighter models suffice for coarse classification
