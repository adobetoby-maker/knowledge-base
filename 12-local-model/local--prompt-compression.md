# Local Model: Prompt Compression

## Overview
Smaller local models process context more slowly than large cloud models, and inference cost scales linearly with token count. Compressing prompts reduces latency without necessarily reducing quality — many prompts contain redundancy, verbose formatting, and padding that adds tokens without adding information. The goal is maximum information density per token.

## Implementation / Key Points

### Compression Techniques

**1. Remove markdown formatting from instructions**
```
Before (78 tokens):
## Task
You are an expert customer service representative.
### Instructions
- Read the customer email carefully
- Identify the main issue
- Respond professionally
- Be concise and helpful

After (32 tokens):
You are a customer service agent. Read the email, identify the issue, respond professionally and concisely.
```

**2. Abbreviate consistently (define once)**
```
# Define abbreviation in system prompt, use throughout
System: "In this conversation: U=user, O=order, Ref=reference, ACT=action required"

# Then in examples:
Good: "U asks about O status → check Ref → respond with shipping info"
vs.
Bad: "The user is asking about their order status → check the order reference number → respond with the current shipping information"
```

**3. Compress examples**
```
# Bad: verbose examples
Example 1: If the customer says "I want to return my product", you should respond with "I'm sorry to hear that. I'd be happy to help you with a return..."

# Good: condensed examples  
Examples:
"return request" → "Initiate return process, ask for order number"
"order status" → "Look up order, provide tracking if available"
```

**4. JSON for structured instructions (not prose)**
```
# Bad: prose constraints (verbose)
Please make sure your response is no more than 3 sentences. Only include information that is directly relevant. Do not add pleasantries or filler words.

# Good: structured constraints
Format: {sentences: max 3, style: direct, no_filler: true}
```

**5. Instruction deduplication**
Scan for repeated constraints. "Be concise" appearing 3 times adds tokens without effect.
```python
def deduplicate_instructions(prompt: str) -> str:
    sentences = prompt.split('.')
    seen = set()
    unique = []
    for s in sentences:
        normalized = s.strip().lower()
        if normalized not in seen:
            seen.add(normalized)
            unique.append(s)
    return '.'.join(unique)
```

### Measuring Compression Effect
```python
import tiktoken  # approximate token count for most models

enc = tiktoken.get_encoding("cl100k_base")

original_tokens = len(enc.encode(original_prompt))
compressed_tokens = len(enc.encode(compressed_prompt))
reduction = (original_tokens - compressed_tokens) / original_tokens

print(f"Token reduction: {reduction:.0%}")
# Now run quality check on your test dataset
# Accept the compression only if quality_delta < threshold
```

### Quality vs Speed Tradeoff Analysis
```python
for compression_level in ['none', 'light', 'medium', 'aggressive']:
    prompt = apply_compression(base_prompt, level=compression_level)
    quality = run_quality_check(prompt, test_dataset)
    latency = measure_latency(prompt, n=50)
    print(f"{compression_level}: {count_tokens(prompt)} tokens, "
          f"quality={quality:.2f}, p50={latency}ms")

# Pick the compression level where quality drop < 3% and latency gain > 20%
```

### Safe vs Risky Compressions
| Compression | Safety | Notes |
|---|---|---|
| Remove redundant sentences | Safe | No information lost |
| Compress examples to 1-2 | Safe | Keep diverse examples |
| Remove markdown headers | Safe | Models don't need `##` to understand structure |
| Remove pleasantries from instructions | Safe | "Please" adds no information |
| Truncate examples significantly | Risky | Test quality before deploying |
| Remove output format specification | Risky | Small models need explicit format guidance |
| Remove all examples | Risky | Few-shot examples often critical for small models |

## Key Rules
- Always measure quality on your test dataset after compressing — quality can degrade unexpectedly
- Small models need output format specified explicitly — don't compress away format instructions
- Few-shot examples are often more valuable token-per-token than instruction text — compress instructions first
- Consistent abbreviations defined once are high-compression, low-risk
- Target the prompt sections that are longest first — 100-token savings on a 500-token section is 20%
- Compression is worth pursuing when context is > 50% of the model's context window
