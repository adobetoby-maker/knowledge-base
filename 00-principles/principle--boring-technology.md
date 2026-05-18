# Principle: Choose Boring Technology

## Overview
Every technology you adopt comes with a "weirdness budget" — the cost of its unknown failure modes, sparse documentation, small community, and gaps in your team's knowledge. Proven technologies have already spent their weirdness budget; you inherit decades of Stack Overflow answers, blog posts, and battle-tested patterns. New technology forces you to discover failure modes yourself, in production, at the worst moments.

## Implementation / Key Points

### What Makes Technology "Boring"
- Used in production at multiple well-known companies
- 5+ years of adoption in the ecosystem
- Large, active community (active GitHub issues, Stack Overflow tags, conference talks)
- Known failure modes documented publicly
- Multiple competing implementations or alternatives
- Your team has direct experience with it

### The Innovation Budget
Each project should have a limited innovation budget — new or unproven technology choices that you deliberately take on because the benefit justifies the cost. A reasonable budget:

```
Per project: 1 genuinely new/experimental technology
Per team: 2-3 frontier explorations at any time

Novel choices require:
- A champion who owns the risk
- A documented fallback (what's the exit plan?)
- A time-bounded evaluation (are we still happy in 90 days?)
```

### Decision Framework
```
Question 1: Is this a commodity problem?
  Yes → use the boring, proven solution (PostgreSQL for relational data, not a new DB)
  
Question 2: Does our competitive advantage depend on this being different?
  No → boring technology
  
Question 3: Can we survive the failure modes we don't know yet?
  No → boring technology
  
Question 4: Is the team excited about this, or are they excited about learning it?
  Only learning → defer; pay for a side project, not production
```

### Failure Mode Comparison
```
Boring technology problem:     Your team knows what it is and how to fix it.
New technology problem:        Your team spends 3 days reading issues, finding someone
                               who hit it before, and discovering the workaround.
```
The ops cost at 3am is not "fix it" — it's "understand what it even is first."

### When New Technology is Justified
- Existing solutions genuinely cannot meet a hard requirement (e.g., edge runtime that Node.js cannot run in)
- Cost savings are dramatic and the technology is mature enough to have known failure modes
- The team is explicitly chartered to evaluate new approaches (R&D role)

### Common Traps
- "It's so much nicer to work with" — subjective preference is not a production requirement
- "Everyone is moving to it" — early adopters absorb the bugs, not you
- "We'll figure it out as we go" — this is the definition of paying the weirdness tax

## Key Rules
- Default to boring technology for infrastructure, data storage, and auth.
- Reserve innovation budget for areas of genuine competitive differentiation.
- New technology choices require a named champion and a documented exit plan.
- Evaluate new technology at 90 days: is it still the right choice?
- "I want to learn it" is a valid reason for a side project, not a production system.
- Unknown failure modes are a cost, not a neutral property — price them in.
