# Agent Pattern: Debate for Better Decisions

## Why Debate Instead of a Single Agent

A single agent asked "is this a good idea?" will almost always find a way to say yes — it builds on its own initial framing and rarely challenges its first assumptions. Two agents with explicitly opposing mandates surface objections the proposing agent would rationalize away. The value is not in finding the truth; it is in exposing the weakest links in the reasoning before a decision is committed.

## Role Structure

**Proponent agent** — given the proposal and tasked with the strongest possible case for it. Must produce concrete supporting arguments, not hedged endorsements. Should cite specific evidence, expected outcomes, and why alternatives are worse.

**Opponent agent** — given the same proposal and tasked with finding every flaw. Should surface unstated assumptions, failure modes, opportunity costs, and counterexamples. Explicitly forbidden from conceding anything until the rebuttal round.

**Judge agent** — reads the full transcript and synthesizes a decision. Not a referee during debate — only speaks at the end. Identifies which objections were actually addressed vs. deflected, which claims were supported vs. asserted, and what the remaining uncertainty is.

## Structured Rounds

```
Round 1 — Opening positions
  Proponent: core claim + top 3 supporting arguments
  Opponent: top 3 objections (independent of proponent's framing)

Round 2 — Direct engagement
  Proponent: responds to each objection specifically
  Opponent: responds to proponent's supporting arguments

Round 3 — Rebuttal (optional, for high-stakes decisions)
  Each side: one paragraph identifying what the other side failed to adequately address

Judge: synthesis — decision, confidence level, key residual risks
```

Keep rounds short (200-400 words each). Long rounds dilute signal; agents start padding rather than sharpening.

## When Debate Helps

- Architecture decisions with multiple viable paths
- Risk assessment (deploy now vs. wait)
- Acceptance of a vendor, library, or third-party dependency
- Policy decisions where stakes are high and reversibility is low

## When Debate Hurts

- Factual lookups — debate produces false controversy around things that are just true or false
- Low-stakes decisions — overhead exceeds value
- Time-critical situations — a 6-message debate adds latency
- Decisions that need domain expertise neither agent has

## Running the Pattern in Code

```typescript
const proponentPrompt = `You are arguing FOR the following proposal. Make the strongest
possible case. Be specific and cite expected outcomes.\n\nProposal: ${proposal}`

const opponentPrompt = `You are arguing AGAINST the following proposal. Find every flaw,
unstated assumption, and failure mode. Do not concede anything yet.\n\nProposal: ${proposal}`

const [proResponse, oppResponse] = await Promise.all([
  llm(proponentPrompt),
  llm(opponentPrompt)
])

const round2Pro = await llm(buildRound2Prompt('proponent', proResponse, oppResponse))
const round2Opp = await llm(buildRound2Prompt('opponent', proResponse, oppResponse))

const verdict = await llm(buildJudgePrompt(proResponse, oppResponse, round2Pro, round2Opp))
```

Run proponent and opponent in parallel for round 1 and round 2 — they do not need to wait for each other within a round.

## Failure Modes

**Sycophantic opponent** — opponent too quickly agrees after round 1 responses. Fix: instruct opponent to maintain skepticism unless given a direct, specific counter to each objection.

**Debate theater** — both agents arguing past each other without engaging. Fix: require each agent to quote the specific claim they are responding to.

**Judge cop-out** — judge issues a "both sides have merit" verdict. Fix: force judge to output a binary decision plus the single strongest remaining risk.

## Key Rules

- Run proponent and opponent in parallel — sequential ordering biases the framing
- Judge reads the full transcript, not summaries — summaries hide the rhetorical moves
- Keep rounds short; length correlates with padding, not depth
- Never use debate for factual questions — it manufactures false uncertainty
- Force judge to make a decision; "more research needed" is not a verdict
- Three rounds is usually enough; four is almost always diminishing returns
