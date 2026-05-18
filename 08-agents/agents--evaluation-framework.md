# Agent Evaluation Framework

Evaluation is the discipline that separates "it felt right" from "it works." Most agent failures are invisible without a structured eval — the agent produces confident-sounding output that is subtly wrong. The eval framework makes these failures visible and reproducible.

## Why BLEU/ROUGE Fail for Agents

BLEU and ROUGE measure n-gram overlap between output and a reference. They were designed for machine translation where surface-form similarity is meaningful. For agents:
- A correct answer phrased differently than the reference scores poorly.
- A wrong answer that happens to share words with the reference scores well.
- Tool call quality, reasoning chain correctness, and task completion are invisible to these metrics.

Use task-completion metrics instead: did the agent do the thing? This is binary or rubric-scored, not similarity-scored.

## LLM-as-Judge Scoring

Use a separate judge model to score agent outputs against a rubric. Structure the judge prompt to:
1. Present the task, the agent output, and any ground truth.
2. Score each rubric dimension (accuracy, completeness, format, tone) on a 1–5 scale.
3. Require the judge to cite specific evidence for each score.

Key constraint: the judge model should be the same capability tier or better than the agent being evaluated. A weaker judge will miss errors a stronger agent makes subtly. GPT-4-class or Claude Opus as judge; Haiku as agent being evaluated is valid. The reverse is not.

Calibrate the judge against human scores on 50 examples before using it at scale. If judge-human agreement is below 0.7 correlation on your rubric, revise the rubric, not the judge.

## Human Eval Baseline

Run human evaluation on a held-out set before trusting automated eval. Humans catch:
- Factual errors that sound plausible
- Subtle misinterpretation of the task
- Format compliance that technically passes but is confusing in practice

Human eval is expensive; use it to calibrate automated eval, not as the ongoing pipeline. After calibration, automated eval handles volume; human review handles regressions and edge cases.

## Regression Test Suite

Every discovered failure becomes a test case. Structure regression tests as:
- Input (task prompt + any context)
- Expected output criteria (not exact text — rubric or assertion)
- Failure history note (what went wrong before)

Run the regression suite on every model version change, prompt change, or tool change. A suite of 50–200 targeted cases catches the most common failure modes. If an eval run takes more than 10 minutes, it will be skipped — keep it fast.

## Success Metrics per Task Type

Align metrics to what actually matters:

| Task Type | Primary Metric |
|---|---|
| Information retrieval | Recall@K (were the right facts present?) |
| Code generation | Tests pass rate |
| Summarization | Human rubric: accuracy + compression |
| Classification | Precision/recall on held-out labels |
| Planning | Plan executability rate (can a worker execute the plan without clarification?) |
| Tool use | Tool call correctness rate (right tool, right params) |

Avoid single-number overall scores for multi-step agents — they hide which step is failing.

## Key Rules

- Never use BLEU/ROUGE for open-ended agent output. Use task-completion metrics.
- Calibrate LLM-as-judge against human scores before running at scale.
- Every production failure gets added to the regression suite immediately.
- Keep the regression suite runnable in under 10 minutes or it gets skipped.
- Human eval is for calibration and regression triage, not high-volume scoring.
- Match judge model capability tier to or above the agent being evaluated.
