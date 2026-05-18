# Agent Reflection Pattern

Reflection is the practice of having an agent critique its own output and revise before returning a final answer. The core insight: a single forward pass optimizes for fluency and completion, not correctness. Adding a critique pass catches reasoning errors, omissions, and hallucinations that the generation pass glosses over.

## The Critique-Then-Revise Loop

Split the work across two distinct prompts, even in the same model call:

1. **Generation pass** — produce the initial output with no self-editing instruction. Let it be complete and committed.
2. **Critique pass** — present the output to a "critic" prompt. The critic asks: What is wrong? What is missing? What assumptions were made that may be false? What should be shorter or clearer?
3. **Revision pass** — present both the original and the critique to a "reviser" prompt. The reviser incorporates valid critiques and discards nitpicks.

Keep the critic and creator personas separated by prompt boundary. A single prompt that says "write X, then critique it" conflates roles and produces gentle self-criticism. A hard boundary between generation and critique forces the critic to treat the work as foreign.

## Separate Critic from Creator

The critic prompt should be adversarial in framing:
- "You are reviewing this response for errors. Your job is to find problems, not validate it."
- Give the critic a checklist: factual accuracy, logical consistency, completeness, format compliance.
- The critic should not rewrite — only identify issues with specific callouts.

The creator (reviser) then receives: original output + critique bullets + instruction to produce a final version. This way the reviser can weigh each critique rather than blindly incorporating all feedback.

## Stopping Criteria

Iteration is not free — each reflection round doubles latency and cost. Stop when:
- The critique produces no "high severity" issues (define severity tiers upfront).
- The delta between revision N and revision N-1 falls below a threshold (compare outputs with a diff heuristic or a short "are these substantially different?" judge call).
- A fixed max iteration count is hit (2–3 rounds is almost always enough; beyond 3, gains are marginal and the risk of over-correction rises).

Never let the loop run open-ended. Pre-commit to a max before starting.

## When Reflection Hurts

- **Stable factual tasks**: If the task is deterministic lookup (math, code execution result), reflection adds latency with no benefit. Run the code; don't reflect on whether it's correct.
- **Over-correction risk**: A critic with loose instructions will find style issues and push the output toward verbose, hedge-everything prose. Constrain the critic scope to the task's actual success criteria.
- **Creative tasks**: Reflection can sand down voice and originality. Use it for factual/structural critique only, not aesthetic critique, in creative work.
- **Short responses**: For single-sentence answers, reflection overhead exceeds any benefit.

## Key Rules

- Always hard-separate the critic prompt from the generator prompt — same model, different role framing.
- Critique must be specific (quote the offending text) not vague ("could be improved").
- Set a max iteration count before the loop starts; never open-ended.
- Skip reflection for deterministic or purely creative tasks.
- Diminishing returns begin after round 2; almost never run more than 3 rounds.
- A critique that produces no actionable issues is the correct exit signal — don't fabricate issues to justify another pass.
