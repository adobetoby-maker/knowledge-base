# Skill: PDF Content Extraction

## Overview
PDFs are structurally unreliable: the format was designed for printing, not data extraction. Text may be encoded as individual characters with no word boundary information, tables may be positioned-text without logical structure, and scanned documents have no text layer at all. The correct tool depends on the PDF type, and robust pipelines handle all three cases: searchable text PDFs, structured PDFs with tables, and scanned PDFs requiring OCR.

## Implementation

### Detecting PDF Type
```ts
import pdf from 'pdf-parse';
import fs from 'fs';

async function detectPDFType(filePath: string) {
  const buffer = fs.readFileSync(filePath);
  const data = await pdf(buffer);

  const textLength = data.text.replace(/\s/g, '').length;
  const pageCount = data.numpages;
  const avgCharsPerPage = textLength / pageCount;

  if (avgCharsPerPage < 50) {
    return 'scanned'; // likely image-based, needs OCR
  }
  return 'searchable';
}
```

### Text Extraction: pdf-parse (Simple)
Best for: plain text extraction from searchable PDFs. Fast, no native dependencies.

```ts
import pdf from 'pdf-parse';

export async function extractPDFText(buffer: Buffer): Promise<{
  text: string;
  pageCount: number;
  pages: string[];
}> {
  const chunks: string[] = [];

  const data = await pdf(buffer, {
    pagerender: (pageData) => {
      return pageData.getTextContent().then((content: any) => {
        const text = content.items
          .map((item: any) => item.str)
          .join(' ');
        chunks.push(text);
        return text;
      });
    },
  });

  return {
    text: data.text,
    pageCount: data.numpages,
    pages: chunks,
  };
}
```

### Text Extraction: pdfjs-dist (Structured)
Better for: preserving layout, extracting by page, accessing metadata. Runs in Node.js and browser.

```ts
import * as pdfjsLib from 'pdfjs-dist/legacy/build/pdf';

export async function extractPagesWithPositions(buffer: ArrayBuffer) {
  const doc = await pdfjsLib.getDocument({ data: buffer }).promise;
  const pages = [];

  for (let i = 1; i <= doc.numPages; i++) {
    const page = await doc.getPage(i);
    const content = await page.getTextContent();

    const items = content.items.map((item: any) => ({
      text: item.str,
      x: item.transform[4],
      y: item.transform[5],
      width: item.width,
      height: item.height,
      fontSize: item.transform[0],
    }));

    pages.push({ pageNumber: i, items });
  }

  return pages;
}
```

### Page-Level Chunking for RAG
Split by page for RAG ingestion — pages are natural boundaries and page numbers are useful metadata:

```ts
export async function chunkForRAG(pdfBuffer: Buffer, documentId: string) {
  const { pages } = await extractPDFText(pdfBuffer);

  return pages.map((pageText, i) => ({
    content: pageText.trim(),
    metadata: {
      documentId,
      pageNumber: i + 1,
      source: 'pdf',
    },
  })).filter(chunk => chunk.content.length > 100); // skip near-empty pages
}
```

### OCR for Scanned PDFs
```ts
import Tesseract from 'tesseract.js';
import { fromPath } from 'pdf2pic';

export async function ocrPDF(pdfPath: string): Promise<string[]> {
  // Convert each page to image
  const converter = fromPath(pdfPath, {
    density: 300,        // DPI — higher = better OCR, slower
    format: 'png',
    width: 2480,
    height: 3508,
  });

  const pageCount = await getPDFPageCount(pdfPath);
  const pageTexts: string[] = [];

  for (let i = 1; i <= pageCount; i++) {
    const imagePath = await converter(i);
    const { data: { text } } = await Tesseract.recognize(
      imagePath.path,
      'eng',
      { logger: () => {} }
    );
    pageTexts.push(text);
  }

  return pageTexts;
}
```

### Pattern Extraction with Regex
After extracting raw text, apply domain-specific patterns:

```ts
const PATTERNS = {
  date: /\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\w+ \d{1,2},? \d{4})\b/gi,
  amount: /\$[\d,]+\.?\d*/g,
  invoiceNumber: /(?:invoice|inv)[#\s]*([A-Z0-9\-]+)/gi,
  ein: /\b\d{2}-\d{7}\b/g,
};

export function extractInvoiceData(text: string) {
  return {
    dates: Array.from(text.matchAll(PATTERNS.date), m => m[0]),
    amounts: Array.from(text.matchAll(PATTERNS.amount), m => m[0]),
    invoiceNumbers: Array.from(text.matchAll(PATTERNS.invoiceNumber), m => m[1]),
  };
}
```

### Confidence-Based Human Review Queue
```ts
export async function processWithConfidence(
  pdfBuffer: Buffer,
  documentId: string
) {
  const { text, pages } = await extractPDFText(pdfBuffer);
  const extracted = extractInvoiceData(text);

  // Low-confidence heuristic: important fields not found
  const confidence = calculateConfidence(extracted);

  if (confidence < 0.7) {
    await db.reviewQueue.create({
      documentId,
      reason: 'low_extraction_confidence',
      confidence,
    });
  }

  return { extracted, confidence, needsReview: confidence < 0.7 };
}
```

## Key Rules
- Never assume PDFs have extractable text — always detect scanned vs searchable before choosing extraction strategy.
- pdf-parse is the simplest option for basic text; use pdfjs-dist when you need coordinates or structured content.
- OCR at 300 DPI minimum — lower resolution produces unacceptable accuracy for financial/legal documents.
- Chunk by page for RAG, not by arbitrary token count — page boundaries are semantically meaningful.
- Malformed PDFs are common — always wrap extraction in try/catch and fall back to OCR if text extraction fails or returns empty.
- Post-process extracted text with regex patterns for known field types — raw LLM classification of unstructured text is less reliable than regex for structured patterns like amounts, dates, IDs.
- Route low-confidence extractions to human review — automated extraction is never 100% reliable on real-world PDFs.
