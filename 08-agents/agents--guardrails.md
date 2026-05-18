# Agent: Guardrails

## Overview

Guardrails are checks that run before, during, or after an agent action to prevent harmful, incorrect, or unauthorized outputs. They're the difference between an autonomous agent that's useful and one that's dangerous. Guardrails don't replace good prompting — they're a defense-in-depth layer for when prompts fail.

## Input Guardrails

Validate and sanitize agent inputs before passing to the model:

```ts
interface GuardrailResult {
  allowed: boolean
  reason?: string
  sanitized?: string
}

async function checkInputGuardrails(input: string, context: AgentContext): Promise<GuardrailResult> {
  // 1. Length limit
  if (input.length > 10000) {
    return { allowed: false, reason: 'Input exceeds maximum length' }
  }

  // 2. Injection attempt detection
  const injectionPatterns = [
    /ignore previous instructions/i,
    /you are now/i,
    /pretend you are/i,
    /system prompt/i,
    /jailbreak/i,
  ]
  if (injectionPatterns.some(p => p.test(input))) {
    return { allowed: false, reason: 'Potential prompt injection detected' }
  }

  // 3. Scope check — agent should only handle its domain
  if (context.scope === 'customer-support' && !isCustomerSupportQuery(input)) {
    return { allowed: false, reason: 'Query outside agent scope' }
  }

  return { allowed: true }
}
```

## Output Guardrails

Check model output before returning to the user:

```ts
async function checkOutputGuardrails(output: string, action: AgentAction): Promise<GuardrailResult> {
  // 1. PII leakage detection
  const piiPatterns = {
    ssn: /\b\d{3}-\d{2}-\d{4}\b/,
    creditCard: /\b\d{4}[\s-]\d{4}[\s-]\d{4}[\s-]\d{4}\b/,
    email: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g,
  }

  for (const [type, pattern] of Object.entries(piiPatterns)) {
    if (pattern.test(output)) {
      return {
        allowed: false,
        reason: `Output may contain ${type}`,
        sanitized: output.replace(pattern, '[REDACTED]'),
      }
    }
  }

  // 2. Action scope validation — agent shouldn't execute outside permitted tools
  if (action.type === 'execute_code' && !context.codeExecutionAllowed) {
    return { allowed: false, reason: 'Code execution not permitted in this context' }
  }

  // 3. Confidence threshold
  if (action.confidence !== undefined && action.confidence < 0.7) {
    return { allowed: false, reason: `Action confidence too low: ${action.confidence}` }
  }

  return { allowed: true }
}
```

## Tool Call Guardrails

Check tool calls before executing them:

```ts
async function checkToolCallGuardrail(
  toolName: string,
  args: Record<string, unknown>,
  permissions: string[]
): Promise<GuardrailResult> {
  // Check tool is permitted
  if (!permissions.includes(toolName)) {
    return { allowed: false, reason: `Tool "${toolName}" not in permitted tools` }
  }

  // Check args for dangerous patterns
  if (toolName === 'bash') {
    const command = args.command as string
    const dangerousCommands = ['rm -rf', 'DROP TABLE', 'DELETE FROM', 'FORMAT', '; rm']
    if (dangerousCommands.some(d => command.includes(d))) {
      return { allowed: false, reason: 'Potentially destructive command blocked' }
    }
  }

  if (toolName === 'write_file') {
    const path = args.path as string
    // Prevent writing outside allowed directories
    if (!path.startsWith('/allowed/') && !path.startsWith('./output/')) {
      return { allowed: false, reason: `Write outside permitted directory: ${path}` }
    }
  }

  return { allowed: true }
}
```

## Human-in-the-Loop Guardrails

For high-stakes actions, require human approval:

```ts
const HIGH_STAKES_TOOLS = ['send_email', 'create_payment', 'delete_records', 'publish_content']

async function requireApproval(
  action: AgentAction,
  approvalCallback: (action: AgentAction) => Promise<boolean>
): Promise<boolean> {
  if (HIGH_STAKES_TOOLS.includes(action.tool)) {
    console.log(`High-stakes action requires approval: ${action.tool}`, action.args)
    return approvalCallback(action)
  }
  return true  // Low-stakes actions auto-approved
}
```

## Guardrail Middleware

```ts
async function runWithGuardrails<T>(
  agentFn: () => Promise<T>,
  guardrails: {
    pre?: () => Promise<GuardrailResult>
    post?: (result: T) => Promise<GuardrailResult>
  }
): Promise<T | GuardrailError> {
  if (guardrails.pre) {
    const preCheck = await guardrails.pre()
    if (!preCheck.allowed) {
      return { error: `Pre-guardrail blocked: ${preCheck.reason}` }
    }
  }

  const result = await agentFn()

  if (guardrails.post) {
    const postCheck = await guardrails.post(result)
    if (!postCheck.allowed) {
      return { error: `Post-guardrail blocked: ${postCheck.reason}` }
    }
  }

  return result
}
```

## Logging Guardrail Violations

```ts
function logGuardrailViolation(
  type: 'input' | 'output' | 'tool',
  reason: string,
  context: { userId?: string; sessionId: string; agentId: string }
) {
  logger.warn({
    event: 'guardrail.violation',
    type,
    reason,
    ...context,
  })
  // Track violation rate — spike indicates attack or misconfiguration
  metrics.increment('guardrail.violations', { type })
}
```

## Key Rules

- Guardrails should fail closed — when a guardrail check fails or errors, deny the action rather than allow it.
- Input guardrails prevent prompt injection; output guardrails prevent data leakage; tool guardrails prevent unauthorized actions. All three are needed.
- Overly aggressive guardrails break useful functionality — calibrate based on the agent's actual risk profile.
- Log all violations with context — violation patterns reveal attack attempts and model misbehavior.
- Human-in-the-loop is the appropriate guardrail for irreversible high-stakes actions (send email, charge payment, delete data) — automated guardrails alone are insufficient.
