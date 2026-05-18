# Local Model: Benchmarking Models for Your Task

## Overview
Generic benchmarks (MMLU, HellaSwag, HumanEval) measure academic capability on standardized tasks that may bear no resemblance to what your application actually does. A model that scores 85% on MMLU may perform worse on your specific task than one that scores 72%. The only reliable benchmark is one built from your actual production inputs with your actual quality criteria.

## Implementation / Key Points

### Building a Task-Specific Eval Dataset

**Step 1: Collect representative inputs**
```python
# Sample from production logs, user-submitted inputs, or hand-craft
examples = [
    {
        "input": "Customer email: 'I ordered the blue widget last week...'",
        "expected_category": "shipping_inquiry",
        "expected_sentiment": "neutral",
    },
    # 50-100 examples covering the distribution of your real inputs
    # Include: common cases, edge cases, adversarial inputs, failures you've seen
]
```

**Step 2: Define scoring criteria**
```python
# Option A: Exact match (structured output)
def score_exact(output: str, expected: str) -> float:
    return 1.0 if output.strip().lower() == expected.strip().lower() else 0.0

# Option B: LLM-as-judge with rubric (open-ended output)
JUDGE_PROMPT = """
Score the following response on a 1-5 scale:
5 = Completely accurate, helpful, no hallucinations
4 = Mostly correct, minor issues
3 = Partially correct, significant omissions
2 = Mostly wrong or misleading
1 = Completely wrong or harmful

Response to score: {response}
Expected answer: {expected}
Rubric criteria: {criteria}

Return JSON: {"score": <1-5>, "reasoning": "<brief explanation>"}
"""

# Option C: Human review
# For 50-100 examples, human review is feasible and most accurate
```

**Step 3: Run eval against each model**
```python
import time
import json

def evaluate_model(model_name: str, examples: list) -> dict:
    scores = []
    latencies = []
    
    for example in examples:
        start = time.time()
        output = run_model(model_name, example["input"])
        latency = time.time() - start
        
        score = score_response(output, example["expected"])
        scores.append(score)
        latencies.append(latency)
    
    return {
        "model": model_name,
        "quality_score": sum(scores) / len(scores),
        "p50_latency_ms": sorted(latencies)[len(latencies)//2] * 1000,
        "p95_latency_ms": sorted(latencies)[int(len(latencies)*0.95)] * 1000,
        "tokens_per_sec": measure_throughput(model_name),
        "vram_mb": measure_vram(model_name),
    }
```

### Metrics to Compare
| Metric | How to Measure | Why It Matters |
|---|---|---|
| Quality score | Eval dataset with rubric | Does it do the job? |
| Tokens/second | Timed generation, known token count | User-facing latency |
| VRAM (MB) | `nvidia-smi` during inference | Hardware fit |
| p95 latency | Percentile over 100+ calls | Real-world response time |
| Context utilization | Test at 50%, 75%, 100% context | Quality degradation at length |

### When to Re-Run Evals
- Every model upgrade or change
- Before switching quantization levels (Q4 → Q8 affects quality)
- When prompt changes (new system prompt = new baseline)
- Monthly if model is serving production traffic

### Reporting Format
```
Model: llama3.1-8b-q4_km
Quality score: 0.78 / 1.00
P95 latency: 340ms
Tokens/sec: 85
VRAM: 5.2GB

Model: mistral-nemo-12b-q4_km  
Quality score: 0.84 / 1.00
P95 latency: 580ms
Tokens/sec: 45
VRAM: 8.1GB

Decision: 7% quality gain vs 70% latency penalty — use 8b for real-time, 12b for batch
```

## Key Rules
- Generic benchmarks are not your benchmark — build a task-specific eval dataset before choosing a model
- 50-100 examples is enough to differentiate models on a specific task
- LLM-as-judge scoring requires a rubric — vague "is this good?" prompts produce unreliable scores
- Measure tokens/second and VRAM alongside quality — a brilliant model that won't fit in VRAM is useless
- Run evals on every model upgrade — quality can regress with quantization or fine-tuning changes
- Separate your eval from your training data — evaluate on inputs the model hasn't been tuned for
- Document the eval dataset and methodology so comparisons are reproducible
