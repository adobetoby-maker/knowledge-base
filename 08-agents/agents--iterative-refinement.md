# Agent: Iterative Refinement

Iterative refinement uses multiple passes over content — draft, critique, revise — to produce output that exceeds what a single generation can reliably achieve. The pattern works because the skills required for generating content and evaluating content are separable. A model generating a first draft is optimizing for fluency and coverage; a model critiquing that draft is optimizing for gaps, inconsistencies, and quality signals.

## Pass 1: Rough Draft

The first pass prioritizes completeness over polish. The goal is to get all the necessary content into existence, not to make it good yet. Incomplete thoughts, awkward phrasing, and structural issues are acceptable here — they will be addressed in later passes.

Prompt the draft pass with the full context and requirements. Do not constrain style or format heavily — let the model produce what comes naturally. Over-constraining the first pass reduces the creative surface for later improvement.

For long-form content: draft in sections rather than one shot. Each section becomes its own draft/critique/revise cycle if needed.

## Pass 2: Critique

The critique pass reads the draft as an adversarial reviewer, not as the author. It is explicitly looking for what's wrong, not what's right. A critique that only affirms is useless — it provides no signal for revision.

Critique dimensions to evaluate:
- **Accuracy**: Are all claims correct? Any unsupported assertions?
- **Completeness**: What's missing that the requirements asked for?
- **Clarity**: Which passages are ambiguous or hard to follow?
- **Coherence**: Does the structure flow logically? Any contradictions?
- **Tone**: Is the register appropriate for the intended audience?

The critique should be specific and actionable. "This section is unclear" is not useful. "The third paragraph introduces a technical term ('idempotency') without defining it, which will lose non-technical readers" is useful.

Separate the critique into discrete, numbered issues so the revision pass can address each one systematically.

## Pass 3: Revision

The revision pass takes the draft and the numbered critique issues and produces an improved version. It should address every critique point explicitly — not just the easy ones.

Structure the revision pass prompt to include: (1) the original draft, (2) the critique with issue numbers, (3) explicit instruction to address each numbered point. This prevents the revision from cherry-picking easy fixes while ignoring hard structural problems.

The revision may introduce new issues (fixing one thing breaks another). A single revision pass is usually sufficient — if the critique was thorough, the revised version will be substantially better than the draft.

## Why More Than 3 Passes Rarely Helps

Beyond 3 passes, the improvements become marginal for several reasons:

1. **Diminishing returns**: Each critique catches the most obvious remaining issues. By pass 3, the major structural and accuracy problems are resolved. Remaining issues are minor and stylistic.
2. **Overfitting to critique**: More iterations cause the model to optimize for satisfying previous critiques rather than serving the actual reader. The output gets "correct" but loses voice and directness.
3. **Hallucination accumulation**: Each generation pass is an opportunity to introduce new errors. More passes = more surface area for subtle hallucinations.
4. **Cost vs. value**: Passes 4+ rarely produce changes a human reviewer would notice. The cost (tokens, latency) is not justified by the improvement.

Exception: technical documents with hard accuracy requirements (code, legal, medical) may benefit from a fourth pass focused narrowly on factual verification by a specialized checker.

## Stopping Criteria

Stop when:
- The critique identifies no high-severity issues.
- The revision made only stylistic changes, not substantive ones.
- The maximum pass count is reached (default: 3).

Never continue refinement indefinitely hoping the output will eventually be perfect. Set a maximum upfront.

## Key Rules

- Separate the draft and critique into distinct prompts — they optimize for different objectives and should not be conflated.
- Critiques must be specific and numbered to be actionable in the revision pass.
- The revision pass must explicitly address each critique point — a revision that only improves easy parts is incomplete.
- Stop at 3 passes by default; the marginal quality gain beyond that rarely justifies the cost.
- For accuracy-critical content, add a dedicated fact-checking pass after pass 3, not another round of generic critique/revise.
- Track what changed between passes — if the diff between draft and revision is minimal, the critique was too weak.
