# Local Model: Text Chunking Strategies for RAG

## Overview
Chunking determines how documents are split before embedding and retrieval. The chunk size governs a core tradeoff: large chunks preserve more context per chunk but produce less precise retrieval (the relevant sentence is buried in a large chunk). Small chunks improve retrieval precision but may lack the context needed to generate a good answer. The right strategy depends on your content structure and query patterns.

## Implementation / Key Points

### Fixed-Size Chunking (Baseline)
```python
def chunk_fixed(text: str, chunk_size: int = 512, overlap: int = 50) -> list[str]:
    words = text.split()
    chunks = []
    start = 0
    while start < len(words):
        end = min(start + chunk_size, len(words))
        chunk = ' '.join(words[start:end])
        chunks.append(chunk)
        start += chunk_size - overlap  # overlap preserves context at boundaries
    return chunks
```
**Pros:** Simple, predictable, uniform embedding cost.  
**Cons:** Splits sentences/paragraphs mid-thought; context loss at chunk boundaries.  
**When to use:** Baseline to compare against; when content has no structural markers.

### Semantic Chunking (Split on Natural Boundaries)
```python
import re

def chunk_semantic(text: str, max_tokens: int = 500) -> list[str]:
    # Split on double newline (paragraph), then sentence, then word
    paragraphs = re.split(r'\n\n+', text)
    
    chunks = []
    current = []
    current_tokens = 0
    
    for para in paragraphs:
        para_tokens = len(para.split())  # approximate
        
        if current_tokens + para_tokens > max_tokens and current:
            chunks.append('\n\n'.join(current))
            current = [para]
            current_tokens = para_tokens
        else:
            current.append(para)
            current_tokens += para_tokens
    
    if current:
        chunks.append('\n\n'.join(current))
    
    return chunks
```
**Pros:** Preserves paragraph-level coherence; chunks are natural reading units.  
**Cons:** Variable chunk sizes; very long paragraphs may exceed limits.

### Hierarchical Chunking
```
Document
  └── Section (H2)
        └── Subsection (H3)
              └── Paragraph chunks

Embed at multiple levels:
- Section summaries → for broad topic retrieval
- Paragraph chunks → for specific answer retrieval
```
```python
def chunk_hierarchical(doc: str) -> dict:
    sections = re.split(r'^## ', doc, flags=re.MULTILINE)
    result = []
    for section in sections:
        lines = section.strip().split('\n')
        title = lines[0]
        body_chunks = chunk_semantic('\n'.join(lines[1:]))
        result.append({
            'title': title,
            'summary': body_chunks[0] if body_chunks else '',
            'chunks': body_chunks,
        })
    return result
```
**When to use:** Technical documentation, legal documents, long-form content where section context matters.

### Code Chunking (Function/Class Level)
```python
import ast

def chunk_python_code(source: str) -> list[str]:
    tree = ast.parse(source)
    chunks = []
    
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.ClassDef)):
            start_line = node.lineno - 1
            end_line = node.end_lineno
            chunk_lines = source.splitlines()[start_line:end_line]
            chunks.append('\n'.join(chunk_lines))
    
    return chunks
```
**When to use:** Codebase Q&A, code search. Splitting at function/class boundaries preserves semantic units.

### Chunk Size Tradeoffs
| Chunk Size | Retrieval Precision | Context Per Chunk | Embedding Cost |
|---|---|---|---|
| 128 tokens | High (specific) | Low (may lack context) | Low |
| 256 tokens | Good | Adequate | Low |
| 512 tokens | Moderate | Good | Medium |
| 1024 tokens | Lower | High | Higher |
| 2048+ tokens | Low | Very high | High |

**Sweet spot for most use cases: 256-512 tokens with 50-token overlap.**

### Overlap Strategy
Overlap prevents important context from being split across chunks:
```
Chunk 1: tokens 1-512
Chunk 2: tokens 462-974  (50-token overlap with chunk 1)
Chunk 3: tokens 924-1436 (50-token overlap with chunk 2)
```
Without overlap, a sentence split across a boundary may be unfindable by retrieval.

### Metadata Attachment
```python
chunks_with_metadata = [
    {
        "text": chunk,
        "metadata": {
            "source": "docs/api-reference.md",
            "section": "Authentication",
            "chunk_index": i,
            "total_chunks": len(chunks),
        }
    }
    for i, chunk in enumerate(chunks)
]
```
Metadata enables filtered retrieval ("only from section X") and source citation.

## Key Rules
- Start with fixed-size 512 tokens with 50-token overlap as your baseline, then iterate
- Semantic chunking on paragraph boundaries is almost always better than fixed-size for natural language
- Code must be chunked at function/class level — splitting code mid-function breaks retrieval
- Overlap at chunk boundaries is non-negotiable for fixed-size chunking — prevents context loss
- Test retrieval quality with real queries before deploying — chunk size affects answer quality more than model size
- Store source metadata with every chunk — you need to cite sources and enable filtered retrieval
