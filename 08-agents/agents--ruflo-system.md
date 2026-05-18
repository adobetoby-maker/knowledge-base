# Ruflo Plugin System

**What it provides:** 34 specialized agents for memory, intelligence, trading, IoT, security, workflows, and more.
**When to reach for it:** Advanced orchestration, persistent memory, vector search, goal planning, security audits, workflow automation.

## The Core Ruflo Agents (Most Relevant)

### ruflo-rag-memory — Vector Memory
```
Skill("ruflo-rag-memory:ruflo-memory")   — store and search semantic memory
Skill("ruflo-rag-memory:recall")          — semantic search across all stored memory
Skill("ruflo-rag-memory:memory-search")  — targeted memory retrieval
Skill("ruflo-rag-memory:memory-bridge")  — sync memory between systems
```
Use when: you need semantic similarity search ("find anything about auth patterns") rather than exact key lookup.

### ruflo-core — Coder + Researcher
```
Agent({ subagent_type: "ruflo-core:coder" })      — write clean code following project patterns
Agent({ subagent_type: "ruflo-core:researcher" }) — research via memory graphs and codebase
Agent({ subagent_type: "ruflo-core:reviewer" })   — code quality and security review
```

### ruflo-swarm — Multi-Agent Orchestration
```
Skill("ruflo-swarm:swarm")      — orchestrate multiple agents as a swarm
Skill("ruflo-swarm:swarm-init") — initialize a swarm for a project
Skill("ruflo-swarm:monitor-stream") — monitor swarm progress in real time
```
Use when: a task is large enough to decompose into truly parallel subagents.

### ruflo-goals — Planning + Research
```
Skill("ruflo-goals:goal-plan")     — GOAP A* search for optimal action plan
Skill("ruflo-goals:horizon-track") — track long-horizon objectives across sessions
Skill("ruflo-goals:deep-research") — multi-source research with evidence grading
```

### ruflo-security-audit — Security
```
Skill("ruflo-security-audit:audit")           — full security audit
Skill("ruflo-security-audit:security-scan")   — scan for vulnerabilities
Skill("ruflo-security-audit:dependency-check") — check for vulnerable dependencies
```

### ruflo-migrations — Database
```
Skill("ruflo-migrations:migrate-create")   — generate migration with up/down
Skill("ruflo-migrations:migrate-validate") — validate migration safety
```

### ruflo-sparc — SPARC Methodology
```
Skill("ruflo-sparc:ruflo-sparc")      — full 5-phase SPARC flow
Skill("ruflo-sparc:sparc-spec")       — specification phase
Skill("ruflo-sparc:sparc-implement")  — implementation phase
Skill("ruflo-sparc:sparc-refine")     — refinement phase
```
SPARC = Specification → Pseudocode → Architecture → Refinement → Completion

### ruflo-cost-tracker — Token Cost Tracking
```
Skill("ruflo-cost-tracker:ruflo-cost")  — track token usage per agent
Skill("ruflo-cost-tracker:cost-report") — usage report
Skill("ruflo-cost-tracker:cost-optimize") — recommendations
```

### ruflo-observability — Monitoring
```
Skill("ruflo-observability:observe")        — set up observability
Skill("ruflo-observability:observe-trace")  — distributed tracing
Skill("ruflo-observability:observe-metrics") — metrics collection
```

## When Ruflo vs Standard Agents
- **Simple feature work** → `feature-dev:code-architect` + `feature-dev:code-reviewer`
- **Multi-agent complex project** → `ruflo-swarm:coordinator`
- **Semantic memory search** → `ruflo-rag-memory:recall` (vs `mem-search` for session history)
- **Security audit** → `ruflo-security-audit:audit`
- **DB migration** → `ruflo-migrations:migrate-create`
- **Long multi-session objective** → `ruflo-goals:horizon-track`
