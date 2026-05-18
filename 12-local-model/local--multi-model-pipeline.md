# Local Model: Multi-Model Pipelines

## Overview
Not every task in an application requires the same model. Using a large model for everything is expensive (API cost or VRAM) and slow. A multi-model pipeline assigns each sub-task to the smallest, fastest model capable of doing it well. The key design question is which tasks can be parallelized, which must be sequential, and where the quality floor is for each step.

## Implementation / Key Points

### Task Routing by Capability
```
User query
    ↓
[Router: small model] → classify query type (fast, cheap)
    ├── "simple_factual" → small local model (fast answer)
    ├── "complex_reasoning" → large model (accurate answer)
    └── "code_generation" → code-specialized model
```

```python
TASK_MODEL_MAP = {
    'classification': 'llama3.2:3b',      # fast, small
    'extraction': 'llama3.2:3b',           # fast, structured
    'simple_qa': 'llama3.1:8b',            # moderate
    'complex_reasoning': 'llama3.1:70b',   # quality required
    'code_generation': 'qwen2.5-coder:14b', # specialized
    'summarization': 'llama3.1:8b',        # moderate
}

async def route_and_run(query: str, context: str = '') -> str:
    # Step 1: cheap classification to pick model
    task_type = await classify_task(query)  # uses 3B model
    model = TASK_MODEL_MAP.get(task_type, 'llama3.1:8b')
    
    # Step 2: run actual query with appropriate model
    return await run_model(model, query, context)
```

### Large Model for Generation, Small for Classification
```python
# Common pattern: classify first, generate only when needed
async def handle_support_ticket(ticket: str) -> dict:
    
    # Step 1: classify with small model (fast, cheap)
    category = await run_model('llama3.2:3b', 
        f"Classify this support ticket: '{ticket}'\n"
        "Return one word: billing, technical, shipping, other")
    
    # Step 2: check if it's a common pattern (cache lookup)
    cached_response = get_cached_response(category, ticket)
    if cached_response:
        return cached_response
    
    # Step 3: generate response only if needed — use larger model
    response = await run_model('llama3.1:8b',
        f"You are a support agent. Category: {category}\n"
        f"Ticket: {ticket}\n"
        "Write a helpful response.")
    
    return {'category': category, 'response': response}
```

### Distilled Model for Common Patterns
```python
# Train a tiny classifier on your most common query patterns
# then use the full model only for the long tail

from functools import lru_cache

@lru_cache(maxsize=1000)
def get_cached_classification(input_hash: str) -> str | None:
    """Check if we've classified this exact input before."""
    return classification_cache.get(input_hash)

async def classify_smart(text: str) -> str:
    text_hash = hash(text)
    
    # Check semantic cache first (embedding similarity)
    similar = find_similar_cached(text, threshold=0.95)
    if similar:
        return similar.category
    
    # Fall back to model
    category = await run_model('llama3.2:3b', classify_prompt(text))
    
    # Cache the result
    store_classification(text, text_hash, category)
    return category
```

### Whisper for Transcription (Separate Model)
```python
import whisper

# Audio transcription is a separate model, not LLM
transcription_model = whisper.load_model("base")  # or "small", "medium"

async def handle_voice_input(audio_file: str) -> str:
    # Step 1: transcribe with Whisper (specialized for audio)
    transcript = transcription_model.transcribe(audio_file)['text']
    
    # Step 2: pass transcript to LLM for understanding/response
    return await run_model('llama3.1:8b', 
        f"User said: {transcript}\nRespond helpfully.")
```

### Embedding Model Separate from Generation
```python
# Embeddings and generation are fundamentally different tasks
# Use a dedicated embedding model, not your chat model

from sentence_transformers import SentenceTransformer

embed_model = SentenceTransformer('all-MiniLM-L6-v2')  # 80MB, fast
# Never use your 8B chat model for embeddings — 50x the cost, similar quality

async def rag_pipeline(query: str, documents: list[str]) -> str:
    # Step 1: embed query with small embedding model
    query_embedding = embed_model.encode(query)
    
    # Step 2: retrieve relevant chunks (vector similarity)
    relevant_chunks = vector_search(query_embedding, top_k=3)
    
    # Step 3: generate answer with LLM
    context = '\n\n'.join(relevant_chunks)
    return await run_model('llama3.1:8b',
        f"Context:\n{context}\n\nQuestion: {query}\nAnswer:")
```

### Pipeline Architecture
```
Audio input → [Whisper] → transcript
                              ↓
Text query → [Embed model] → vector → [Vector DB] → relevant chunks
                                                          ↓
                               ← ← ← [8B LLM: generate answer]
                               ↓
                    [3B model: classify response type]
                               ↓
                    Route to appropriate follow-up action
```

## Key Rules
- Use the smallest model that meets quality requirements for each sub-task
- Never use your chat LLM for embeddings — use a dedicated embedding model (sentence-transformers)
- Audio transcription belongs to Whisper or equivalent, not an LLM
- Classification and routing tasks work well with 3B models — save the 8B for generation
- Parallelize independent pipeline steps — don't wait for classification before starting context retrieval
- Cache classification results — the same or semantically similar inputs will recur
- Test each model independently on its sub-task before wiring the pipeline together
