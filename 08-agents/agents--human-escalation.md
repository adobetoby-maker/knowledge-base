# Human Escalation for Agents

## The Escalation Contract

An agent that never escalates is dangerous. One that escalates constantly is useless. The design challenge is defining a clear, narrow set of triggers and ensuring that when escalation fires, the human gets exactly what they need to decide quickly.

The contract: the agent handles everything it can handle well; it escalates everything it can't — and it does so in a way that minimizes the human's decision-making time.

## When to Escalate: Triggers

**Uncertainty above threshold** — if the agent's confidence in its plan is below a threshold, stop and ask rather than act on a guess. For irreversible actions, the threshold should be high (95%+ confidence required). For reversible actions, it can be lower.

```typescript
if (confidence < ESCALATION_THRESHOLD && action.isIrreversible) {
  return escalate({ reason: "low_confidence", confidence, action });
}
```

**Destructive or irreversible actions** — deleting records, sending external communications, processing financial transactions, modifying access control, deploying to production. These classes of action require explicit human confirmation regardless of confidence. The agent should never decide to do them autonomously.

**Explicit user request** — if the user says "let me decide this one," "ask me before proceeding," or "I'll handle the payment," honor it. Parse escalation requests from user messages and treat them as hard stops.

**Contradictory or ambiguous instructions** — when the task description contradicts itself, or when two pieces of context in the conversation point to different correct actions. Guessing is not acceptable here.

**Scope expansion** — if completing the task requires doing something significantly beyond what was asked. "Clean up these three files" should not silently become "refactor the entire module."

## Escalation Message Format

The escalation message is not a status update — it's a decision brief. Write it to minimize the time the human spends before making a choice.

Required elements:
1. **What the agent was doing** — one sentence of context
2. **What it encountered** — why it's escalating
3. **What it needs from the human** — explicit question or choice
4. **What happens if no response** — the default behavior after timeout
5. **Urgency** — is this blocking, or can it wait?

```
AGENT ESCALATION — Order Refund Task

Situation: Processing refund for order ord_882 (Alice Chen, $249.99)
Issue: Order is 16 days old — past the 14-day automatic refund window.
      However, delivery was confirmed 2 days late (courier fault on file).

Question: Approve this refund as an exception?
  → YES: Issue full refund, close ticket, notify customer
  → NO: Send customer explanation with store credit offer instead

Awaiting response until 2026-05-18 18:00. If no response: NO path will execute.
Urgency: Customer has messaged twice. Medium — not urgent but notable.
```

The human should be able to make the decision in under 30 seconds. If the message requires reading a paragraph of context before the question, rewrite it.

## Escalation Channels

Choose the channel based on urgency and the human's workflow:

- **In-app notification + task queue** — default for most escalations; human reviews at their own pace
- **Email** — for non-urgent escalations that can wait hours
- **Slack/Teams DM** — for medium-urgency items during business hours
- **SMS/push notification** — for urgent items only (potential fraud, production incidents, large financial decisions)

Don't escalate non-urgent items to SMS. Alert fatigue degrades the human's ability to respond to real emergencies.

## Timeout Behavior While Waiting

The agent is paused during escalation. Define what happens when the timeout expires without human input:

- Default to the **safest available option** — the one with the smallest blast radius
- Log that the timeout path was taken
- Notify the human that the default was used and give them a window to override
- For financial operations: default is "do not proceed"

Never let an escalation time out silently. If the timer fires and the default action runs, the human must be informed.

## Key Rules

- Escalate on: confidence below threshold for irreversible actions, destructive operations (always), explicit user request, contradictory instructions, scope expansion
- Write escalation messages as decision briefs, not status updates — question first, context second
- Include the default behavior and timeout in every escalation message
- Match escalation channel to urgency: in-app for routine, SMS for emergencies only
- Default to safest option on timeout; never proceed silently with a high-impact action
- Test escalation paths the same way you test happy paths — they handle the cases that matter most
