# Build-Measure-Learn

## The Problem with Shipping Without Measurement

Features built without a prior hypothesis about what success looks like accumulate silently. The team can't tell if users are better or worse off. The codebase fills with dead features that no one removes because no one can prove they're safe to remove. "Ship it and see" without instrumentation is just "ship it and guess forever."

The Build-Measure-Learn cycle (from Lean Startup, Eric Ries) creates a feedback loop: every feature is an experiment with a falsifiable hypothesis, and the metric either validates or invalidates the decision to keep it.

## Hypothesis Format: If X Then Y Because Z

Write the hypothesis before writing any code:

> "If we add inline checkout to the product page, then conversion rate will increase by at least 8%, because users currently abandon when redirected to a separate checkout page."

The "because Z" is the most important part. It forces you to state the mechanism — why you believe X causes Y. If you can't articulate the mechanism, you don't understand the problem well enough to build the solution yet.

A hypothesis without a mechanism is a guess dressed up as a plan.

## Minimum Instrumentation

Define the minimum set of events to track before the feature ships, not after. Retroactive instrumentation is almost always incomplete — it misses the baseline, the control group, or the correct event definition.

For every feature, answer before shipping:
1. What is the primary metric this feature should move?
2. What is the baseline (current value)?
3. What is the success threshold (minimum acceptable improvement)?
4. What are the guardrail metrics (what must NOT get worse)?

The instrumentation must exist on day 1. If it doesn't, the feature is not shippable.

## Success Metrics Before Shipping

Success criteria defined after the fact are subject to rationalization ("well, downloads went up even though engagement went down, so it's fine"). Lock in the definition of success before anyone sees the data.

This also prevents metric cherry-picking: if you pre-commit to "day-7 retention" as the primary metric, you can't retroactively switch to "day-1 activation" when day-7 retention disappoints.

## Killing Features That Don't Move Metrics

A feature that doesn't move its target metric within the measurement window is a failed experiment. The default action is removal, not refinement. Refinement is appropriate only when you have a new hypothesis about why the first version failed.

"Keep it because users might like it" is not a reason. "Keep it because we discovered the mechanism was X, not Y, and we now have a new version that addresses X" is a reason.

Killed features must actually be removed from the codebase — not hidden behind a flag, not left dormant. Dead code is maintenance debt.

## The Measurement Window

Define the measurement window in the hypothesis. For features affecting retention, 7–30 days. For features affecting conversion, 24–72 hours with sufficient traffic. For features affecting long-term engagement, 30–90 days.

Don't end the experiment early when early data looks good — early data is biased toward novelty effects. Don't extend the experiment because the results are disappointing — that's p-hacking.

## Key Rules

- Write the hypothesis (If X then Y because Z) before writing code
- Define primary metric, baseline, success threshold, and guardrail metrics before shipping
- Instrument on day 1; retroactive instrumentation invalidates the experiment
- Pre-commit to success criteria — never redefine them after seeing data
- Default action for a failed experiment is removal, not iteration
- Remove killed features from the codebase; don't hide them behind flags
