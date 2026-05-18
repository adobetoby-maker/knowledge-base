# Agents: Knowledge Retrieval in Agents

## Overview
Retrieval-Augmented Generation (RAG) extends an agent's knowledge beyond its training data by retrieving relevant documents at query time and including them in context. The retrieval step is where most RAG failures occur — not in the generation. If the wrong chunks are retrieved, the model generates confident-sounding incorrect answers. If no relevant chunks are retrieved, the model hallucinates from training data. Retrieval quality is the ceiling on RAG quality.

## Retrieval Methods

**Semantic search (dense retrieval)**
- Embeds query and documents into the same vector space
- Retrieves by cosine similarity
- Best for: conceptual queries where exact wording differs from source ("what are the requirements?")
- Weakness: misses exact string matches (product codes, names, technical terms)

**Keyword search (sparse retrieval)**
- BM25 or TF-IDF based
- Retrieves by term overlap
- Best for: exact term queries ("SKU-12345", "configure_timeout setting")
- Weakness: misses conceptual matches when phrasing differs

**Hybrid retrieval (best default)**
- Runs both semantic and keyword search in parallel
- Combines results using Reciprocal Rank Fusion (RRF) or linear interpolation
- Covers both exact-match and conceptual queries
- Recommended for production systems where query types vary

## Relevance Filtering

Retrieving top-K results is not always correct — if K=5 but only 1 result is relevant, the other 4 introduce noise that can mislead the model.

**Score threshold filtering**: only include results with similarity score above a minimum (e.g., 0.7 for cosine similarity). Calibrate threshold on a sample query set.

**Relevance re-ranking**: use a cross-encoder model (slower, more accurate than bi-encoder similarity) to re-rank the top-K results and filter out low-relevance chunks.

**Result count vs fixed K**: variable result count based on relevance is better than always returning exactly K results. Return 1 high-quality result rather than padding with low-relevance chunks.

## Chunk Design

Retrieval quality is determined partly at indexing time:
- **Chunk size**: 200–500 tokens is the typical sweet spot — large enough for context, small enough for precision
- **Chunk overlap**: 50–100 token overlap between adjacent chunks prevents context splitting at boundaries
- **Metadata per chunk**: include source document ID, section title, date — include in context for citation
- **Hierarchical chunking**: store both fine-grained chunks (for precise retrieval) and parent context (for surrounding context) — retrieve fine, include parent

## Including Retrieved Context in the Prompt

Provide retrieved chunks in a dedicated section, with source metadata:
```
## Retrieved Knowledge
Source: [document name, section, date]
---
[chunk text]

Source: [document name, section, date]
---
[chunk text]
```

Instruct the model to cite sources and to say "I don't know" if retrieved context doesn't answer the question — prevents model from falling back to training data when retrieval returns nothing relevant.

## Query Formulation

The retrieval query should not always be the raw user message:
- User: "How do I fix the error I saw yesterday?" → poor retrieval query
- Reformulated: "authentication error troubleshooting" → better retrieval query
- Use a query formulation step: extract the core information need from the user's message, then retrieve

For multi-turn conversations, the retrieval query should incorporate the conversation context, not just the latest message.

## Key Rules

- Hybrid retrieval (semantic + keyword) outperforms either alone for mixed query types
- Score threshold filtering > fixed top-K — don't include low-relevance chunks
- Include source metadata with every chunk in context — enables citation and debugging
- Query formulation is a step distinct from retrieval — reformulate before searching
- Instruct the model to cite sources and not use training data when retrieval is insufficient
- Chunk design is an indexing-time decision that affects retrieval quality — optimize it upfront
