# Local Model: Building an Eval Suite

## Overview
Generic benchmarks (MMLU, HellaSwag) tell you how a model performs on academic tasks, not on your specific use case. A task-specific eval suite—built from your actual data, graded on your actual quality criteria—is the only reliable way to choose between models, validate fine-tuning results, and catch regressions when upgrading models. The investment in building the eval pays dividends every time you change models, prompts, or quantization levels.

## Eval Suite Structure

```
evals/
├── datasets/
│   ├── classification-test.jsonl       # held-out test set, never used in training
│   ├── extraction-test.jsonl
│   └── qa-test.jsonl
├── scorers/
│   ├── exact-match.ts                  # for classification, entity extraction
│   ├── llm-judge.ts                    # for open-ended text quality
│   └── rouge.ts                        # for summarization
├── run-eval.ts                         # orchestrates eval runs
└── results/
    ├── llama3.1-8b-q4km-2026-05-18.json
    └── qwen2.5-7b-q4km-2026-05-18.json
```

## Eval Dataset Format

```jsonl
// Each line: input + expected output
{"id": "cls-001", "input": "The server is down again, can't access my account",
 "expected": "technical-issue", "difficulty": "easy"}
{"id": "cls-002", "input": "I want to cancel my subscription effective immediately",
 "expected": "cancellation-request", "difficulty": "medium"}
{"id": "cls-003", "input": "Your service is terrible and I demand a refund for last month",
 "expected": "refund-request", "difficulty": "hard"}
```

## Scorer 1: Exact Match (Classification, NER)

```ts
interface EvalExample {
  id: string;
  input: string;
  expected: string;
  difficulty?: string;
}

interface EvalResult {
  id: string;
  expected: string;
  actual: string;
  correct: boolean;
  latencyMs: number;
}

async function runExactMatchEval(
  examples: EvalExample[],
  model: string,
  systemPrompt: string
): Promise<EvalResult[]> {
  const results: EvalResult[] = [];

  for (const example of examples) {
    const start = Date.now();
    const response = await generate(model, example.input, { system: systemPrompt, temperature: 0 });
    const latencyMs = Date.now() - start;

    // Normalize: trim, lowercase, remove punctuation
    const actual = response.trim().toLowerCase().replace(/[.,!?]/g, '');
    const expected = example.expected.toLowerCase();

    results.push({ id: example.id, expected, actual, correct: actual === expected, latencyMs });
  }

  return results;
}
```

## Scorer 2: LLM-as-Judge (Open-Ended Quality)

```ts
async function llmJudgeScore(
  input: string,
  modelOutput: string,
  criteria: string,
  judgeModel = 'llama3.1:70b' // use a stronger model as judge
): Promise<{ score: number; reasoning: string }> {
  const judgePrompt = `Evaluate the following response on a scale of 1-5.

Task: ${criteria}

User input: ${input}
Model response: ${modelOutput}

Scoring rubric:
5 = Fully correct, complete, and well-formatted
4 = Correct with minor issues
3 = Partially correct or missing elements
2 = Mostly incorrect with some right elements
1 = Completely wrong or hallucinated

Respond as JSON: {"score": N, "reasoning": "brief explanation"}`;

  const response = await generate(judgeModel, judgePrompt, { temperature: 0 });
  const parsed = JSON.parse(response.trim());
  return { score: parsed.score, reasoning: parsed.reasoning };
}
```

## Eval Runner with Aggregation

```ts
async function runEval(modelName: string, datasetPath: string) {
  const examples = loadJsonl<EvalExample>(datasetPath);
  const results = await runExactMatchEval(examples, modelName, SYSTEM_PROMPT);

  // Aggregate metrics
  const correct = results.filter(r => r.correct).length;
  const accuracy = correct / results.length;
  const avgLatency = results.reduce((sum, r) => sum + r.latencyMs, 0) / results.length;

  // Per-difficulty breakdown
  const byDifficulty = groupBy(results, (r) => {
    const example = examples.find(e => e.id === r.id)!;
    return example.difficulty ?? 'unknown';
  });

  const report = {
    model: modelName,
    dataset: datasetPath,
    timestamp: new Date().toISOString(),
    overall: { accuracy, correct, total: results.length, avgLatencyMs: avgLatency },
    byDifficulty: Object.fromEntries(
      Object.entries(byDifficulty).map(([k, v]) => [
        k,
        { accuracy: v.filter(r => r.correct).length / v.length, count: v.length }
      ])
    ),
    failures: results.filter(r => !r.correct).map(r => ({
      id: r.id, expected: r.expected, actual: r.actual
    })),
  };

  // Save results
  fs.writeFileSync(`evals/results/${modelName}-${Date.now()}.json`, JSON.stringify(report, null, 2));
  return report;
}
```

## Regression Detection in CI

```ts
// Compare new eval results against baseline
function detectRegression(baseline: EvalReport, current: EvalReport, threshold = 0.02) {
  const accuracyDrop = baseline.overall.accuracy - current.overall.accuracy;
  if (accuracyDrop > threshold) {
    throw new Error(
      `Regression detected: accuracy dropped from ${baseline.overall.accuracy.toFixed(3)}` +
      ` to ${current.overall.accuracy.toFixed(3)} (${(accuracyDrop * 100).toFixed(1)}% drop)`
    );
  }
}

// In CI pipeline:
// 1. Run eval against current model/prompt
// 2. Compare to stored baseline
// 3. Fail if accuracy drops > 2%
// 4. Update baseline on intentional model upgrades
```

## A/B Testing Two Models

```ts
async function compareModels(modelA: string, modelB: string, datasetPath: string) {
  const [reportA, reportB] = await Promise.all([
    runEval(modelA, datasetPath),
    runEval(modelB, datasetPath),
  ]);

  console.log(`\n${modelA}: ${(reportA.overall.accuracy * 100).toFixed(1)}% accuracy, ${reportA.overall.avgLatencyMs.toFixed(0)}ms avg`);
  console.log(`${modelB}: ${(reportB.overall.accuracy * 100).toFixed(1)}% accuracy, ${reportB.overall.avgLatencyMs.toFixed(0)}ms avg`);

  // Find examples where they disagree
  const disagreements = reportA.failures
    .filter(f => !reportB.failures.find(fb => fb.id === f.id));
  console.log(`\nExamples where B succeeds but A fails: ${disagreements.length}`);
}
```

## Key Rules
- **Task-specific eval, not generic benchmarks** — MMLU scores tell you nothing about your classification task.
- **Held-out test set never used in training** — contaminated evals produce artificially high scores that don't reflect real performance.
- **Temperature 0 for eval runs** — deterministic output makes results reproducible; variance from temperature makes comparison unreliable.
- **Save full results with timestamp** — raw results + aggregate metrics; the failures list is where you learn what to fix.
- **Regression threshold in CI** — 2% accuracy drop triggers review; don't auto-accept model upgrades without verifying eval.
- **LLM-as-judge for quality, not just correctness** — exact match misses semantically correct answers; use a judge model for free-form output.
- **Difficulty tagging** — tag examples as easy/medium/hard; a model that fails only hard examples is different from one that fails easy examples.
