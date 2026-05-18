# Agents: Instruction Following Evaluation

## Overview
Agents are only as reliable as their adherence to instructions. Evaluating instruction following is different from evaluating answer quality — it measures whether the model did what it was asked to do (format, constraints, required sections, forbidden content) regardless of whether the content itself is good. Production agent systems need both evaluations, but instruction following is easier to automate and catches the most common failure mode: the model producing correct-but-wrong-format output.

## Types of Instructions to Evaluate

**Format compliance**
- JSON schema validation (required keys present, types correct, no extra keys)
- Word count within specified range
- Output in specified language
- Required sections present (e.g., must include "Summary", "Next Steps")

**Constraint adherence**
- Forbidden words or topics not present
- Tone requirements (formal vs casual — measured by readability scores or LLM judge)
- Length limits (max N sentences, max N words)

**Completeness**
- All required items addressed (if asked for 5 examples, are there 5?)
- No required questions left unanswered
- Action items from a list all handled

**Accuracy of self-reference**
- If told "you are a financial advisor," does the response maintain that persona?
- If told "today's date is X," does the response use the right date in reasoning?

## Rubric-Based Scoring

For structured evaluation, define a rubric before evaluating:

```
Requirement 1: Output is valid JSON → Pass/Fail
Requirement 2: JSON has "title", "summary", "steps" keys → Pass/Fail
Requirement 3: Summary is 50-100 words → Pass/Fail (count words)
Requirement 4: Steps array has 3-7 items → Pass/Fail
Requirement 5: No profanity → Pass/Fail (string scan or LLM judge)
Overall score: (passed requirements) / (total requirements)
```

Binary scoring (pass/fail per requirement) is more reliable than soft scoring for format compliance. Reserve soft scoring for subjective requirements (tone, quality).

## LLM-as-Judge for Qualitative Requirements

Some requirements cannot be evaluated with string matching:
- "Response is professional in tone"
- "Explanation is suitable for a non-technical audience"
- "Answer addresses the user's underlying question, not just the literal text"

Use a separate LLM call with a structured rubric:
```
System: You are an evaluator. Score the following response on the criteria below.
Output a JSON object with score (0 or 1) and reason for each criterion.

Criteria:
- professional_tone: The response maintains a professional, helpful tone (0/1)
- appropriate_depth: The explanation matches the audience's expertise level (0/1)
```

LLM-as-judge is slower and more expensive — use it for qualitative criteria only.

## Automated Evaluation Pipeline

1. Run agent on test cases (golden inputs)
2. For each output, run the evaluation rubric
3. Aggregate pass rates per requirement across all test cases
4. Alert when any requirement falls below threshold (e.g., < 95% pass rate)

This catches regressions when the prompt or model changes.

## Failure Analysis

When a requirement fails, diagnose the cause:
- **Ambiguous instruction**: the model followed a reasonable interpretation but not the intended one — rewrite the instruction to be unambiguous
- **Conflicting instructions**: two requirements conflict and the model satisfied one at the expense of the other — prioritize explicitly
- **Capability limit**: the model cannot reliably follow this instruction regardless of phrasing — accept the limitation or change the architecture

## Key Rules

- Define the evaluation rubric before writing the agent prompt — if you can't articulate a pass/fail criterion, the requirement is too vague
- Automated evaluation (string matching, schema validation) for all structural requirements — save LLM-as-judge for qualitative ones
- Test with diverse inputs — agents often follow instructions on "normal" inputs but fail on edge cases
- Track pass rates over time — instruction following tends to regress when prompts are edited
- Failed evaluation ≠ failed task — a response can be helpful but format-noncompliant; track both
