# Document Q&A with a Local Model

## Why This Pattern Exists

Stuffing an entire document into a local model's context window is unreliable. Local models (7B–13B) have limited context (4k–32k tokens), and long contexts degrade answer quality — the model "forgets" the beginning by the time it reaches the end. Retrieval-first architecture keeps the generation prompt small and focused, yielding more accurate answers than naive full-document approaches.

## Chunking Strategy

Chunk size determines retrieval granularity. Too large: irrelevant text dilutes the signal. Too small: answers get split across chunk boundaries.

- **Target 400–600 tokens per chunk** for most prose documents. This fits 2–4 chunks comfortably in a 4k context alongside the question and answer template.
- **Overlap by 10–15%** (50–80 tokens). Sentences that straddle chunk boundaries still get retrieved. Overlap at the end of chunk N is repeated at the start of chunk N+1.
- **Respect semantic boundaries**: split at paragraph breaks, not mid-sentence. Use a recursive splitter that tries paragraph → sentence → word order.
- **Store metadata per chunk**: document ID, chunk index, page number, section title. You'll need these for citation.

## Retrieval Before Generation

1. Embed the user's question with the same embedding model used at ingest time (model drift breaks recall).
2. Vector-search your store (FAISS, Chroma, pgvector) for the top-k nearest chunks (k=5 is a good default).
3. Re-rank the top-k with a cross-encoder if available — cross-encoders score query+chunk jointly and outperform cosine similarity alone.
4. Pass the top 3–4 chunks to the generation prompt. Don't pass all 5 — marginal chunks add noise.

## Citation of Source Chunks

Assign each chunk a reference tag before injecting it into the prompt:

```
[1] (doc: policy.pdf, p.4): "...chunk text..."
[2] (doc: policy.pdf, p.7): "...chunk text..."
```

Instruct the model: "Answer using only the provided context. Cite sources as [1], [2]."

Post-process the answer to verify cited numbers exist in the context you sent. If the model hallucinates a `[3]` when you only provided two chunks, strip the citation or flag it.

## Handling "Not in the Document"

Set a confidence threshold: if the top retrieved chunk has cosine similarity below 0.65, answer with a canned "I couldn't find information about that in the document" response rather than generating. Below this threshold the model will fabricate.

In the system prompt, explicitly instruct: "If the context does not contain enough information to answer the question, say so. Do not invent facts."

Test this with known out-of-scope questions during development. Models with instruction-following gaps (smaller quantized models especially) will still hallucinate — lower the threshold or switch models for high-stakes use.

## Prompt Structure

```
System: You are a document assistant. Answer only from the provided context.
        Cite chunks as [1], [2]. If the answer is not in the context, say so.

Context:
[1] (source, page): ...
[2] (source, page): ...

Question: {user_question}
Answer:
```

Keep the system prompt short. Local models have weaker instruction-following; verbose system prompts get ignored. One clear rule per sentence.

## Key Rules

- Never embed with one model and retrieve with another — cosine distance only works within the same embedding space.
- Overlap chunks by 10–15%; never zero-overlap for prose documents.
- Gate generation behind a similarity threshold (0.65); below it, refuse rather than hallucinate.
- Include source metadata in every chunk at ingest; you can't reconstruct it at query time.
- Verify cited reference numbers exist in the context you actually sent — don't trust the model's output blindly.
- Keep generation context to 3–4 chunks maximum; more degrades answer coherence on small models.
