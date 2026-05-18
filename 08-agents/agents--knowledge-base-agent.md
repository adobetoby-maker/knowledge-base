# Knowledge Base Agent

A knowledge base (KB) agent answers questions by querying a document store and citing sources, and may update the KB with new verified information. The design challenge is avoiding hallucination while remaining useful when the KB is incomplete.

## Semantic Search Over Documents

Use embedding-based semantic search, not keyword search, as the primary retrieval path. Keyword search fails for paraphrased queries; semantic search finds conceptually matching chunks even when terminology differs.

Retrieval strategy:
1. Embed the user query.
2. Retrieve top-K chunks by cosine similarity (K = 5–10 depending on chunk size).
3. If K chunks are retrieved but similarity scores drop sharply after chunk 2-3, limit context injection to the high-similarity subset.
4. Optionally rerank the retrieved chunks with a cross-encoder for better precision.

Chunk size matters: 256–512 tokens per chunk with 64-token overlap is a reliable default. Larger chunks improve context but reduce precision; smaller chunks improve precision but can split concepts mid-thought.

## Citation in Responses

Every factual claim in the response must be traceable to a specific chunk. Implement citation as:
- Include source metadata (document title, section, URL or path, date) in the chunk representation.
- Instruct the agent to append `[Source: X]` inline for each claim drawn from a source.
- Never let the agent synthesize across sources without noting when claims come from different documents.

Citations serve two purposes: user trust, and debugging. When a response is wrong, the citation tells you which chunk was the problem — bad source vs. bad reasoning vs. both.

## Confidence Threshold for "I Don't Know"

If retrieved chunks are low-similarity (all scores below 0.65 cosine similarity, for example) or none of the chunks contain information relevant to the query, the agent must say so explicitly rather than synthesizing from tangentially related content.

Define the threshold per corpus — a narrow technical corpus can use a higher threshold (0.75) because good answers should be tightly matched; a general corpus might use 0.60. Tune against labeled examples of "answerable" vs. "unanswerable" queries.

The phrase the agent uses matters: "I don't have reliable information about this in the knowledge base" is correct. "Based on related information, I believe..." is dangerous — it produces confident-sounding hallucination.

## Updating the KB with New Verified Facts

KB updates require a write gate: not every piece of information encountered should be persisted. Before writing:
1. Verify the claim against at least one authoritative source (not a secondary summary of the source).
2. Check for conflict with existing KB entries. If a conflict exists, flag it for human review rather than overwriting.
3. Tag the entry with source, date, and confidence level.
4. Never allow the agent to update the KB autonomously from its own reasoning output — only from verified external sources.

Stale KB entries are a long-term problem. Tag entries with a freshness date and flag entries older than a domain-appropriate threshold (6 months for fast-moving topics, 2 years for stable reference material).

## Key Rules

- Use semantic search (embedding-based) as the primary retrieval path; keyword search is a fallback for exact identifiers.
- Every factual claim must be inline-cited to a specific source chunk.
- Define a similarity score threshold below which the agent says "I don't know" rather than guessing.
- Never synthesize a confident answer from low-similarity or tangentially related chunks.
- KB writes require external source verification and conflict-checking — never write from internal reasoning.
- Tag KB entries with source, date, and freshness deadline.
