# Principle: Incident Cost Awareness

## Overview
Incidents have costs that are usually invisible: direct revenue loss (transactions blocked during outage), indirect costs (engineer time, customer trust, churn), and opportunity costs (features not shipped while engineers fight fires). Making these costs visible changes engineering decisions — it shifts priority toward reliability, motivates investment in monitoring and runbooks, and creates pressure to actually improve MTTR. "The outage lasted 2 hours" is abstract; "$24,000 in lost transactions plus 6 engineer-hours" is concrete.

## Implementation

### Calculating Incident Cost
```ts
interface IncidentCost {
  incidentId: string;
  durationMinutes: number;

  // Direct costs
  revenueAtRiskPerMinute: number;     // avg transaction rate × avg order value
  estimatedRevenueLost: number;

  // Engineer costs
  engineersInvolved: number;
  totalEngineerHours: number;
  estimatedEngineerCost: number;      // hours × loaded engineer cost

  // Customer impact
  affectedUsers: number;
  errorsGenerated: number;
  supportTicketsCreated: number;
}

function calculateIncidentCost(params: {
  durationMinutes: number;
  avgRevenuePerMinute: number;
  engineersInvolved: number;
  loadedEngineerHourlyCost: number;
  affectedUsers: number;
}): IncidentCost {
  const revenueAtRisk = params.avgRevenuePerMinute;
  const durationHours = params.durationMinutes / 60;

  return {
    incidentId: crypto.randomUUID(),
    durationMinutes: params.durationMinutes,
    revenueAtRiskPerMinute: revenueAtRisk,
    estimatedRevenueLost: revenueAtRisk * params.durationMinutes,
    engineersInvolved: params.engineersInvolved,
    totalEngineerHours: params.engineersInvolved * durationHours,
    estimatedEngineerCost: params.engineersInvolved * durationHours * params.loadedEngineerHourlyCost,
    affectedUsers: params.affectedUsers,
    errorsGenerated: 0,       // fill from error tracking
    supportTicketsCreated: 0, // fill from support system
  };
}
```

### MTTD and MTTR Tracking
Mean Time to Detect (MTTD) and Mean Time to Resolve (MTTR) are the two metrics that matter most for incident response:

```ts
interface IncidentTimeline {
  incidentId: string;

  // When the actual problem started (from monitoring data)
  problemStartedAt: Date;

  // When we first knew about it
  detectedAt: Date;

  // When an engineer started working
  responseStartedAt: Date;

  // When the service was restored
  resolvedAt: Date;

  // When root cause was confirmed and fix deployed
  postmortemCompletedAt?: Date;
}

function calculateMetrics(timeline: IncidentTimeline) {
  const mttd = (timeline.detectedAt.getTime() - timeline.problemStartedAt.getTime()) / 60_000;
  const mttr = (timeline.resolvedAt.getTime() - timeline.detectedAt.getTime()) / 60_000;
  const totalDuration = (timeline.resolvedAt.getTime() - timeline.problemStartedAt.getTime()) / 60_000;

  return {
    mttdMinutes: mttd,
    mttrMinutes: mttr,
    totalDurationMinutes: totalDuration,
  };
}
```

### Cost Reduction Math: MTTR vs Frequency
Often, reducing MTTR by half is more impactful than halving incident frequency:

```
Scenario A: 4 incidents/month, 60 min MTTR each
  Monthly impact: 4 × 60 = 240 incident-minutes

Scenario B: 2 incidents/month, 60 min MTTR (halved frequency)
  Monthly impact: 2 × 60 = 120 incident-minutes

Scenario C: 4 incidents/month, 30 min MTTR (halved duration)
  Monthly impact: 4 × 30 = 120 incident-minutes

Result: Same improvement from halving MTTR as from halving frequency.
Halving MTTR is often easier: better runbooks, more automation, better tooling.
```

### Incident Severity Levels with Cost Implications
```ts
const SEVERITY_DEFINITIONS = {
  P1: {
    description: 'Complete outage — no customers can use the service',
    revenueImpactMultiplier: 1.0,    // 100% revenue at risk
    responseTimeMinutes: 5,
    stakeholderNotification: 'immediate',
  },
  P2: {
    description: 'Significant degradation — key feature broken for all users',
    revenueImpactMultiplier: 0.5,
    responseTimeMinutes: 15,
    stakeholderNotification: 'within 30 minutes',
  },
  P3: {
    description: 'Partial degradation — feature broken for subset of users',
    revenueImpactMultiplier: 0.1,
    responseTimeMinutes: 60,
    stakeholderNotification: 'end of business day',
  },
};
```

### Postmortem Cost Section
Every postmortem should include a cost summary:
```markdown
## Impact

**Duration:** 47 minutes (14:23 – 15:10 UTC)
**Detection:** 12 minutes after problem started (monitoring gap)
**Revenue impact:** ~$8,400 (based on $178/min average checkout volume)
**Users affected:** 2,341 unique users received errors
**Support tickets:** 23 tickets created (still open)
**Engineer time:** 3 engineers × 1.5 hours = $675 (@ $150/hr loaded cost)

**Total estimated cost:** ~$9,100

## Key Metric
MTTD: 12 minutes (goal: < 5 minutes)
MTTR: 47 minutes (goal: < 30 minutes)
```

## Key Rules
- Attach a dollar cost to every incident postmortem — abstract "2 hour outage" doesn't drive change; "$18,000 in lost revenue" does.
- Track MTTD separately from MTTR — both can be improved independently, and MTTD improvement has a multiplier effect on total impact.
- "Users reported the outage" adds to MTTD — monitor proactively to close this gap.
- Reducing MTTR through runbooks and automation often has better ROI than reducing incident frequency.
- Cost visibility justifies reliability investment — engineers get budget for observability tools when leadership sees the cost of incidents.
- Support ticket count is a lagging cost indicator — each ticket represents engineering and support time beyond the incident window.
- Compare cost of prevention vs cost of incidents — if a reliability project costs $5k and prevents $50k/year in incidents, it pays for itself in 5 weeks.
