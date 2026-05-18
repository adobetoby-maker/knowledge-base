# Document Processing Agent

A document agent loads, parses, and analyzes documents to answer questions, extract structured data, or classify content. The main engineering challenge is handling documents larger than the context window without losing coherence.

## Document Loading

Different formats need different loading strategies:

**PDF** — use `pdfjs-dist` (browser) or `pdf-parse` / `pypdf` (server). Always extract text layer first; fall back to OCR only if text layer is absent or garbled. Scanned PDFs have no text layer — detect by checking if extracted text is empty or mostly whitespace.

**DOCX** — use `mammoth` (Node) or `python-docx`. Mammoth converts to clean HTML, which you can strip to plain text. Preserves heading structure, which is useful for chunking.

**Markdown** — read directly. Strip front matter before passing to the model.

**HTML** — use `cheerio` or `defuddle` to extract main content. Strip nav, footer, sidebar. What's left is usually the document body.

Always normalize to plain text or structured Markdown before passing to the model. Raw HTML or binary formats confuse analysis.

## Chunking Strategy

Documents longer than ~80k tokens must be chunked. The strategy depends on the task:

**For Q&A and retrieval:** Chunk by semantic unit — paragraphs or sections. Overlap chunks by 10-15% so answers near chunk boundaries aren't cut off. Use embeddings to retrieve the relevant chunks, then send only those to the model.

**For extraction (structured data pull):** Chunk by natural boundaries — pages for PDFs, sections for documents with headers. Process each chunk independently and merge results.

**For summarization:** Hierarchical. Summarize each chunk, then summarize the summaries. This produces a coherent top-level summary even for very long documents. The intermediate summaries are also useful artifacts.

**For classification:** Sample the first ~2000 tokens (introduction/abstract), last ~1000 tokens, and one middle section. Classification rarely needs the full document.

Avoid fixed-length character chunking — it splits sentences mid-thought and degrades quality.

## Extraction Tasks

Structure extraction prompts to return machine-readable output. For table extraction:

```
Extract all rows from the table. Return JSON array where each row is an object with keys matching the column headers. If a cell is empty, use null. Do not infer or fill in missing data.
```

Always specify what to do with missing or ambiguous data — "use null" is better than letting the model guess or skip rows.

For key-value extraction (invoice fields, form data):

```
Extract the following fields from this document. Return JSON. If a field is not present, return null for that key. Fields: invoice_number, invoice_date, vendor_name, total_amount, due_date.
```

Listing exact field names prevents the model from inventing alternative names for the same field.

## Multi-Document Analysis

When comparing or synthesizing across multiple documents, do not concatenate them all into one prompt. The model loses track of which claim came from which source.

**Instead:**
1. Process each document individually — extract claims, summaries, or key facts
2. Label each result with its source document
3. Pass labeled summaries to a synthesis step

```python
summaries = []
for doc_path, doc_text in documents:
    summary = extract_summary(doc_text)
    summaries.append(f"[{doc_path}]: {summary}")

synthesis_prompt = "\n\n".join(summaries) + "\n\nCompare and contrast the positions above."
```

This keeps attribution clear and avoids the model confusing which document said what.

## Handling Long Documents with Map-Reduce

For summarization of very long documents:

```python
# Map: summarize each chunk
chunk_summaries = [summarize_chunk(chunk) for chunk in chunks]

# Reduce: synthesize summaries
final_summary = synthesize(chunk_summaries)
```

If the reduce step is still too long, apply reduce recursively until the result fits in a single context window.

## Q&A Over Documents

Do not stuff the entire document into context and ask questions. This is wasteful and often less accurate than retrieval.

1. Embed document chunks at load time (or cache embeddings)
2. On each question, embed the question and retrieve top-k relevant chunks
3. Construct prompt: context chunks + question
4. Return answer with citations pointing to source chunk indices

Citations are critical for document Q&A — users need to verify answers against source material.

## Key Rules

- Normalize all formats to plain text or structured Markdown before passing to the model
- Detect scanned PDFs (empty text layer) and route to OCR before processing
- Chunk by semantic boundaries, not fixed character counts
- Never concatenate multiple documents directly — label and process separately before synthesis
- Always specify how to handle missing data in extraction prompts (null, skip, flag)
- Use map-reduce for summarization of documents longer than one context window
- Return citations in Q&A tasks so answers are verifiable against source material
