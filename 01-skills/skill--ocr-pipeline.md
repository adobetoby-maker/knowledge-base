# Skill: OCR Document Pipeline

## Overview
OCR pipelines are only as good as their preprocessing step and postprocessing validation. A perfectly clear image through Tesseract gets ~99% accuracy. A skewed, low-contrast scan gets 60%. Preprocessing (deskew, normalize contrast, grayscale, upscale if needed) is what separates production-grade OCR from a proof of concept. Postprocessing — applying domain-specific regex patterns, computing confidence scores, routing low-confidence results to humans — is what makes the output useful.

## Implementation

### Image Preprocessing with Sharp (Node.js)
```ts
import sharp from 'sharp';

export async function preprocessForOCR(inputBuffer: Buffer): Promise<Buffer> {
  return sharp(inputBuffer)
    .grayscale()                        // remove color noise
    .normalize()                        // stretch contrast to full 0-255 range
    .sharpen()                          // improve edge definition
    .resize(2480, null, {               // normalize to 300 DPI equivalent width
      withoutEnlargement: false,        // upscale small images
      fit: 'inside',
    })
    .png()                              // lossless format for OCR
    .toBuffer();
}
```

### Tesseract OCR (Self-Hosted)
```ts
import Tesseract from 'tesseract.js';

export async function ocrBuffer(
  imageBuffer: Buffer,
  lang = 'eng'
): Promise<{
  text: string;
  confidence: number;
  words: Array<{ text: string; confidence: number; bbox: object }>;
}> {
  const { data } = await Tesseract.recognize(imageBuffer, lang, {
    logger: () => {},  // suppress progress logs
  });

  return {
    text: data.text,
    confidence: data.confidence,  // overall page confidence 0-100
    words: data.words.map(w => ({
      text: w.text,
      confidence: w.confidence,
      bbox: w.bbox,
    })),
  };
}
```

### Google Vision API (Cloud, Higher Accuracy)
Better for: handwriting, mixed languages, complex layouts. More expensive.

```ts
import { ImageAnnotatorClient } from '@google-cloud/vision';

const visionClient = new ImageAnnotatorClient();

export async function googleVisionOCR(imageBuffer: Buffer): Promise<{
  text: string;
  confidence: number;
  blocks: any[];
}> {
  const [result] = await visionClient.documentTextDetection({
    image: { content: imageBuffer.toString('base64') },
  });

  const fullText = result.fullTextAnnotation;
  if (!fullText) return { text: '', confidence: 0, blocks: [] };

  // Calculate average confidence from all paragraphs
  const confidences: number[] = [];
  fullText.pages?.forEach(page => {
    page.blocks?.forEach(block => {
      block.paragraphs?.forEach(para => {
        if (para.confidence) confidences.push(para.confidence);
      });
    });
  });

  const avgConfidence = confidences.length > 0
    ? confidences.reduce((s, c) => s + c, 0) / confidences.length * 100
    : 0;

  return {
    text: fullText.text ?? '',
    confidence: avgConfidence,
    blocks: fullText.pages?.[0]?.blocks ?? [],
  };
}
```

### Domain-Specific Post-Processing
```ts
export interface ExtractedDocument {
  invoiceNumber?: string;
  vendorName?: string;
  totalAmount?: number;
  invoiceDate?: string;
  dueDate?: string;
  lineItems: LineItem[];
  rawText: string;
  confidence: number;
}

const PATTERNS = {
  invoiceNumber: /(?:invoice|inv\.?|#)\s*([A-Z0-9\-]{4,20})/i,
  totalAmount:   /(?:total|amount due|balance due)[:\s]*\$?([\d,]+\.?\d{0,2})/i,
  date:          /\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})\b/g,
};

export function extractInvoiceFields(text: string): Partial<ExtractedDocument> {
  const invoiceMatch = text.match(PATTERNS.invoiceNumber);
  const amountMatch = text.match(PATTERNS.totalAmount);
  const dates = Array.from(text.matchAll(PATTERNS.date), m => m[1]);

  return {
    invoiceNumber: invoiceMatch?.[1],
    totalAmount: amountMatch ? parseFloat(amountMatch[1].replace(',', '')) : undefined,
    invoiceDate: dates[0],
    dueDate: dates[1],
  };
}
```

### Full Pipeline
```ts
export async function processDocument(inputBuffer: Buffer, documentId: string) {
  // 1. Preprocess
  const processedImage = await preprocessForOCR(inputBuffer);

  // 2. OCR
  const { text, confidence, words } = await ocrBuffer(processedImage);

  // 3. Extract fields
  const extracted = extractInvoiceFields(text);

  // 4. Compute confidence score
  const fieldsFilled = Object.values(extracted).filter(Boolean).length;
  const fieldConfidence = fieldsFilled / 4; // 4 expected fields
  const combinedConfidence = (confidence / 100) * 0.6 + fieldConfidence * 0.4;

  // 5. Route to human review if low confidence
  if (combinedConfidence < 0.7 || confidence < 70) {
    await db.reviewQueue.create({
      documentId,
      ocrText: text,
      confidence: combinedConfidence,
      reason: confidence < 70 ? 'low_ocr_confidence' : 'missing_fields',
    });
  }

  return { text, extracted, confidence: combinedConfidence, needsReview: combinedConfidence < 0.7 };
}
```

## Key Rules
- Preprocess every image: grayscale + normalize contrast before OCR — this alone improves accuracy by 10–30%.
- Tessseract is free and sufficient for clear printed text. Use Google Vision for handwriting, mixed scripts, or when accuracy is revenue-critical.
- Never OCR JPEG screenshots of PDFs — convert the original PDF to PNG at 300 DPI first; JPEG compression artifacts ruin OCR accuracy.
- Compute per-word confidence alongside document confidence — low-confidence words are the fields that need human review, not the whole document.
- Regex patterns for known fields (invoice number, amount, dates) are more reliable than asking an LLM to extract from raw OCR text — they're deterministic.
- Route documents with < 70% OCR confidence to human review automatically — don't silently fail.
- Store the raw OCR text alongside extracted fields — enables re-extraction when patterns are improved.
