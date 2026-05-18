# Plugin: ruflo-swarm

**What it provides:** Multi-agent swarm orchestration — managing multiple agents as a coordinated team with task assignment, lifecycle management, and anti-drift enforcement.
**Agents:** `ruflo-swarm:coordinator`, `ruflo-swarm:architect`

## When to Use
- Task is genuinely too complex for a single agent
- Multiple independent subtasks that benefit from specialization
- Need drift prevention across a long multi-step operation
- Want structured phase-gate workflow enforcement

## Coordinator vs Architect

### ruflo-swarm:coordinator
Manages the RUNNING of the swarm — assigns tasks, tracks progress, handles failures, ensures agents stay on task.
```typescript
Agent({
  subagent_type: "ruflo-swarm:coordinator",
  prompt: "Coordinate a 3-agent team to build the invoice management feature in jrs-auto-repair.
           Agents needed:
           1. Researcher: map existing invoice code in lib/invoices/ and app/admin/invoices/
           2. Architect: design the new tax calculation feature (add tax_rate to invoices table)
           3. Coder: implement the design from architect
           
           Use ruflo-core:researcher, ruflo-core:coder agents.
           Phase gates: don't start architect until researcher delivers. Don't start coder until architect delivers.
           Surface blockers if any agent fails."
})
```

### ruflo-swarm:architect
Designs the multi-agent SYSTEM — decides what agents are needed, what they own, how they communicate.
```typescript
Agent({
  subagent_type: "ruflo-swarm:architect",
  prompt: "Design a multi-agent system to migrate jrs-auto-repair from Pages Router to App Router.
           Constraints: 15 routes, must maintain all functionality, can't break production.
           Design the agent team structure, ownership boundaries, and handoff contracts."
})
```

## vs Other Agent Patterns
```
Simple parallel work      → Agent() calls in single message (no coordinator needed)
Linear pipeline           → sequential Agent calls with explicit handoff
Complex multi-phase       → ruflo-swarm:coordinator
System design             → ruflo-swarm:architect
```

## Anti-Drift Enforcement
Coordinator watches for agents that deviate from their assigned scope:
- Agent doing more than asked → redirected to scope
- Agent blocked → logs to NEEDS_HUMAN equivalent, coordinator continues with other agents
- Agent delivering wrong format → coordinator rejects and re-prompts

## Cost Consideration
Swarm adds overhead — the coordinator is itself an agent that consumes tokens. Only justified for genuinely complex multi-phase work. For 3 parallel tasks with no dependencies, just use 3 Agent() calls directly.
