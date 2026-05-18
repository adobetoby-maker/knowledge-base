# Agent Pattern: Confidence Scoring

## Overview

Ask the model to score its own confidence on a 0–10 scale, then route low-confidence outputs to human review instead of using them directly. This creates a soft filter without requiring schema validation.

## Why Confidence Scoring

Some tasks can't be validated programmatically:
- "Is this customer complaint urgent enough to escalate?"
- "Does this summary accurately represent the source document?"
- "Is this code change safe to auto-deploy?"

For these, confidence scoring externalizes the model's uncertainty into a decision variable.

## Prompt Pattern

```ts
const prompt = `
${mainTask}

After completing your task, add a confidence section on its own line:
CONFIDENCE: [0-10] [one-sentence reason]

Example:
CONFIDENCE: 8 The source document was clear and complete.
CONFIDENCE: 4 The input text had multiple contradictory statements.
`

interface ScoredOutput {
  content: string
  confidence: number
  reason: string
}

function parseConfidence(output: string): ScoredOutput {
  const match = output.match(/CONFIDENCE:\s*(\d+(?:\.\d+)?)\s+(.+)$/m)
  const content = output.replace(/\nCONFIDENCE:.*$/m, '').trim()
  
  if (!match) {
    return { content, confidence: 0, reason: 'No confidence score found' }
  }
  
  return {
    content,
    confidence: Math.min(10, Math.max(0, parseFloat(match[1]))),
    reason: match[2].trim(),
  }
}
```

## Routing by Confidence

```ts
const THRESHOLDS = {
  autoApprove: 8,    // >= 8: use automatically
  humanReview: 5,    // 5-7: queue for human review
  discard: 5,        // < 5: discard and flag for prompt improvement
}

async function processWithConfidence(task: Task): Promise<ProcessingResult> {
  const raw = await callModel(buildPrompt(task))
  const { content, confidence, reason } = parseConfidence(raw)

  if (confidence >= THRESHOLDS.autoApprove) {
    return { status: 'approved', content, confidence }
  }

  if (confidence >= THRESHOLDS.humanReview) {
    await queueForReview({ task, content, confidence, reason })
    return { status: 'pending_review', confidence }
  }

  await logLowConfidence({ task, content, confidence, reason })
  return { status: 'discarded', confidence, reason }
}
```

## Aggregate Confidence for Batch Jobs

```ts
// Run the same prompt multiple times and average
async function ensembleConfidence(prompt: string, runs = 3): Promise<ScoredOutput> {
  const results = await Promise.all(
    Array.from({ length: runs }, () => callModel(prompt).then(parseConfidence))
  )
  
  const avgConfidence = results.reduce((sum, r) => sum + r.confidence, 0) / runs
  const agreeing = results.filter((r) => r.confidence >= 7).length
  
  // High variance = actually uncertain, even if one run scored high
  const variance = Math.max(...results.map((r) => r.confidence)) - Math.min(...results.map((r) => r.confidence))
  const adjustedConfidence = variance > 3 ? avgConfidence * 0.7 : avgConfidence
  
  return {
    content: results[0].content,  // Use first run's content
    confidence: adjustedConfidence,
    reason: `Ensemble: ${agreeing}/${runs} runs confident, variance ${variance.toFixed(1)}`,
  }
}
```

High variance across runs signals genuine ambiguity. A single high-confidence run surrounded by low-confidence runs is less trustworthy than consistent medium confidence.

## Calibration Over Time

```ts
// Store predictions + outcomes to calibrate thresholds
await supabase.from('confidence_calibration').insert({
  task_type: task.type,
  predicted_confidence: confidence,
  content_hash: hashContent(content),
  // Later, when human reviewer validates or rejects:
  // human_verdict: 'correct' | 'incorrect'
  // Add this column and fill it in the review workflow
})

// Analyze: if predictions with confidence 8 are only correct 60% of the time,
// raise the auto-approve threshold to 9
```

Review calibration monthly. Confidence scores are meaningful only if they correlate with actual accuracy. If they don't, fix the prompt, not the thresholds.

## Limitations

- Models sometimes report high confidence when wrong (hallucinate confidently)
- Confidence is task-specific — calibrate per task type, not globally
- Don't use confidence as the sole gating mechanism for high-stakes decisions
- A model reporting "CONFIDENCE: 9" is not a substitute for domain expert review on medical, legal, or financial output
