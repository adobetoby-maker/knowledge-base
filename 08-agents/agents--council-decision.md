# Council Decision Pattern — Multi-Perspective Deliberation

## What It Solves

Single-agent decisions on architecture questions produce locally optimal choices that miss systemic consequences. A Council spawns multiple agents with explicitly different viewpoints, each analyzing the same decision independently, then synthesizes their outputs into a final recommendation.

This is most valuable for: architectural choices with multi-year consequences, security-sensitive decisions, and tradeoffs where optimizing for one dimension destroys another.

## The Four Councilors

Each agent receives the same decision prompt but a different role lens:

**Security Councilor**: What are the attack surfaces? What breaks under adversarial input? What data gets exposed if this fails?

**Performance Councilor**: What are the hot paths? Where does this degrade under load? What caching strategy does this require?

**Maintainability Councilor**: How hard is this to change in 6 months? How many files does this couple together? What breaks when requirements change?

**User Impact Councilor**: What does this look like when it breaks for the user? What fallback exists? How gracefully does it degrade?

## Prompt Template

For each councilor:

```
You are the [ROLE] Councilor in a technical decision review.

DECISION UNDER REVIEW:
[State the exact architectural choice or design decision]

CONTEXT:
[Stack, constraints, team context]

YOUR LENS: Analyze ONLY from the [ROLE] perspective. Do not evaluate other dimensions.

OUTPUT:
- CONCERNS: specific issues from your lens
- BLOCKERS: anything that must be resolved before proceeding
- ACCEPTABLE IF: conditions under which you approve this approach
- VERDICT: APPROVE / CONDITIONAL / BLOCK
```

## Running the Council

Run all four councilors in parallel (concurrent agent calls). Collect their verdicts:

- 4 APPROVE → proceed with no modifications
- 3 APPROVE, 1 CONDITIONAL → proceed with the conditional's requirements
- Any BLOCK → do not proceed; address the blocker before re-running
- 2+ CONDITIONAL → synthesize requirements, then check for conflicts

## Synthesis Step

After collecting all verdicts, run a fifth synthesis agent:

```
You are synthesizing a council decision. The four perspectives below analyzed:
[Decision statement]

SECURITY: [verdict + key concerns]
PERFORMANCE: [verdict + key concerns]
MAINTAINABILITY: [verdict + key concerns]
USER IMPACT: [verdict + key concerns]

Produce:
1. FINAL DECISION: PROCEED / MODIFY / BLOCK
2. REQUIRED MODIFICATIONS: specific changes that address all CONDITIONAL/BLOCK verdicts
3. RESIDUAL RISKS: concerns that were accepted but not fully mitigated
```

## When to Use Council

Use council for:
- Choosing between two architectural approaches with different tradeoff profiles
- Reviewing a significant security boundary change before implementing
- Evaluating a third-party service integration before committing
- Deciding whether to use a new library/dependency

Council is expensive (4+ agent calls). Do not use it for:
- Implementation details within an already-decided architecture
- Purely mechanical tasks
- Decisions with obvious dominant answers

## Lightweight Council (2 Councilors)

For faster decisions, use only Security + Maintainability — the two perspectives most often ignored under time pressure, and the two most likely to produce tech debt or vulnerabilities.
