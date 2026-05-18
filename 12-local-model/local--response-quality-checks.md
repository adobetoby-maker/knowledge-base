# Local Model: Output Quality Gates

## Overview
Local models, especially smaller quantized ones, produce outputs with more frequent failure modes than large cloud models: hallucinated facts, truncated responses, malformed JSON, and outputs that drift from the requested format. Automated quality gates catch these failures before they surface to users, enabling retry logic and graceful degradation.

## Implementation / Key Points

### Hallucination Signal Detection
```python
HEDGING_PATTERNS = [
    r'\bi (think|believe|assume|guess)\b',
    r'\b(might|may|could|possibly|perhaps|probably)\b',
    r'\bi\'m not (sure|certain|confident)\b',
    r'\bi don\'t (know|have information)\b',
    r'\bas far as i know\b',
    r'\bit\'s possible that\b',
]

def has_hallucination_signals(response: str, query_type: str = 'factual') -> bool:
    """Check for hedging language that signals low-confidence or hallucination."""
    if query_type != 'factual':
        return False  # hedging is appropriate in opinion/creative tasks
    
    import re
    response_lower = response.lower()
    for pattern in HEDGING_PATTERNS:
        if re.search(pattern, response_lower):
            return True
    return False

# Usage
response = run_model("What is the capital of France?")
if has_hallucination_signals(response, query_type='factual'):
    # Flag for review or retry
    log_warning("Response contains hedging language", response)
```

### JSON Format Compliance Check
```python
import json

def validate_json_output(response: str, required_keys: list[str]) -> tuple[bool, dict | None]:
    """Verify model output is valid JSON with required keys."""
    # Strip common wrapper text ("Here is the JSON:", "```json", etc.)
    cleaned = response.strip()
    if '```json' in cleaned:
        cleaned = cleaned.split('```json')[1].split('```')[0].strip()
    elif '```' in cleaned:
        cleaned = cleaned.split('```')[1].split('```')[0].strip()
    
    # Find JSON object in response
    import re
    json_match = re.search(r'\{.*\}', cleaned, re.DOTALL)
    if not json_match:
        return False, None
    
    try:
        parsed = json.loads(json_match.group())
    except json.JSONDecodeError:
        return False, None
    
    # Check required keys exist and are not None
    for key in required_keys:
        if key not in parsed or parsed[key] is None:
            return False, None
    
    return True, parsed
```

### Length Sanity Checks
```python
def check_response_length(
    response: str,
    min_words: int = 5,
    max_words: int = 1000,
    task_type: str = 'general'
) -> str | None:
    """Returns failure reason or None if length is acceptable."""
    words = len(response.split())
    
    if words < min_words:
        return f"Response too short ({words} words) — likely truncated or empty"
    
    if words > max_words:
        return f"Response too long ({words} words) — likely off-topic padding"
    
    # Task-specific checks
    if task_type == 'classification' and words > 10:
        return f"Classification response too verbose ({words} words)"
    
    if task_type == 'extraction' and words > 200:
        return f"Extraction response unusually long ({words} words)"
    
    return None
```

### Classification Confidence Threshold
```python
def validate_classification(
    response: str,
    valid_classes: list[str],
    allow_unknown: bool = False
) -> tuple[str | None, float]:
    """Returns (predicted_class, confidence). Returns (None, 0) if invalid."""
    response_lower = response.strip().lower()
    
    # Exact match
    for cls in valid_classes:
        if cls.lower() == response_lower:
            return cls, 1.0
    
    # Contained match
    for cls in valid_classes:
        if cls.lower() in response_lower:
            return cls, 0.8
    
    if allow_unknown:
        return 'unknown', 0.5
    
    return None, 0.0

# Usage
predicted, confidence = validate_classification(
    response="The sentiment is POSITIVE",
    valid_classes=['positive', 'negative', 'neutral']
)
if confidence < 0.8:
    retry_or_escalate()
```

### Retry with Fallback Pattern
```python
async def run_with_quality_gate(
    prompt: str,
    validators: list,
    max_retries: int = 3,
    fallback_response = None
):
    for attempt in range(max_retries):
        response = await run_model(prompt)
        
        failures = []
        for validate in validators:
            result = validate(response)
            if result is not None:  # result is an error message
                failures.append(result)
        
        if not failures:
            return response
        
        # Add failure context to next attempt
        prompt = f"{prompt}\n\nNote: Previous attempt failed: {failures[0]}. Try again."
    
    # All retries exhausted
    return fallback_response or "Unable to generate a valid response"
```

### Quality Gate Checklist
```python
QUALITY_GATES = [
    lambda r: "too short" if len(r.split()) < 5 else None,
    lambda r: "contains hedging" if has_hallucination_signals(r) else None,
    lambda r: validate_json_output(r, ['category', 'confidence'])[0] or "invalid JSON",
]
```

## Key Rules
- Apply quality gates before returning output to users — catch truncation, format failures, and hedging
- Hedging language ("I think", "might", "possibly") on factual queries is a hallucination signal worth flagging
- Always extract JSON from the response rather than assuming the full response is valid JSON — models often add wrapper text
- Length sanity checks catch truncation (too short) and padding/hallucination (too long)
- Retry with context about what failed — telling the model what went wrong often fixes the next attempt
- Quality gates should be fast and cheap — regex and length checks, not another model call
- Log all quality gate failures — patterns in failures guide prompt improvement
