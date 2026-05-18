# Local Model: Cost vs Quality Tradeoffs for Local Deployment

## Overview
Local model deployment has high upfront hardware costs and near-zero per-request costs. Cloud API deployment has zero upfront cost and per-token billing. The break-even point — where local hardware pays for itself — depends on your request volume, token counts, and API pricing. Privacy requirements and latency constraints can override the cost math entirely.

## Implementation / Key Points

### Break-Even Calculation
```
Hardware cost: $X (one-time)
API cost per 1M tokens: $Y (e.g., $0.10 for Haiku, $3.00 for Sonnet)
Monthly tokens: Z

Monthly API cost = (Z / 1,000,000) * Y
Break-even months = X / Monthly API cost

Example:
- Mac Mini M4 Pro: $1,400
- Haiku: $0.10 per 1M output tokens  
- 100M tokens/month: $10/month API cost
- Break-even: 1400 / 10 = 140 months (11 years) — use the API

- Sonnet: $15 per 1M output tokens
- 100M tokens/month: $1,500/month API cost  
- Break-even: 1400 / 1500 = ~1 month — use local
```

### Hardware Cost Reference (2024-2025)
| Hardware | VRAM | Best Fit | Cost |
|---|---|---|---|
| Mac Mini M4 Pro | 24GB unified | 8B-14B models at Q8 | ~$1,400 |
| Mac Studio M3 Ultra | 192GB unified | 70B models | ~$4,000 |
| RTX 4080 | 16GB VRAM | 13B models at Q4 | ~$700 (GPU only) |
| RTX 4090 | 24GB VRAM | 13B at Q8 or 30B at Q4 | ~$1,600 |
| 2x RTX 4090 | 48GB combined | 70B at Q4 | ~$3,200+ |

### Quality Tradeoffs by Tier
```
Cloud Flagship (GPT-4o, Claude Sonnet):
- Best quality on complex reasoning, code, analysis
- $3-15 per 1M tokens
- 500ms-2s latency per request
- No privacy concerns (data leaves your infrastructure)

Cloud Small (Haiku, GPT-4o-mini):  
- Good quality for classification, extraction, simple generation
- $0.10-0.40 per 1M tokens
- 300-800ms latency
- Data still leaves your infrastructure

Local Large (Llama 3.1 70B, Mistral Large):
- Quality approaching GPT-4o for many tasks
- ~$0 per token (hardware amortized)
- 100-500ms on good hardware (GPU/Apple Silicon)
- Data stays on-premises

Local Small (Llama 3.2 8B, Mistral Nemo 12B):
- Quality sufficient for classification, extraction, simple tasks
- ~$0 per token
- 50-200ms on consumer hardware
- Data stays on-premises
```

### When Privacy Overrides Cost Math
Regulatory requirements and data sensitivity create hard requirements for local:
```
Always local for:
- Medical records (HIPAA in US)
- Financial data with PII
- Legal documents with privilege
- Customer PII (GDPR restrictions on cross-border transfers)
- Proprietary IP / trade secrets
- Law enforcement / classified data

Cloud acceptable for:
- Non-PII public data
- Anonymized/aggregated data
- Content moderation of public posts
- General-purpose text generation
```

### Latency Comparison (Rough)
| Scenario | Latency |
|---|---|
| Local 8B model, RTX 4090 | 50-150ms |
| Local 8B model, M4 Pro | 100-300ms |
| Local 70B model, M3 Ultra | 200-800ms |
| Cloud Haiku | 300-600ms |
| Cloud Sonnet | 500ms-2s |
| Cloud Opus/GPT-4o | 1-5s |

Local models win on latency for small-to-medium models on modern hardware.

### Decision Framework
```
1. Does data contain PII or restricted data? → Local required
2. Is offline/airgapped operation required? → Local required
3. Calculate monthly API cost at projected volume
4. If API cost > hardware cost / 18 months → Local wins on cost
5. Does quality of available local model meet requirements? → Test on eval dataset
6. If all checks pass → Deploy local
```

## Key Rules
- Privacy requirements are non-negotiable — they override cost analysis
- Run break-even analysis before committing to hardware — API costs are often lower than expected for moderate volume
- Quality gap between local 7B and cloud Sonnet is significant — always run task-specific eval before assuming local is sufficient
- Apple Silicon (unified memory) is currently the best price/performance for local inference on consumer hardware
- Latency advantage of local matters most for interactive, real-time applications
- Quantization (Q4 vs Q8) trades quality for VRAM — test both on your eval dataset before choosing
