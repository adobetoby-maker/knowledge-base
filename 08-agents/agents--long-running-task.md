# Long-Running Agent Tasks

## The Problem

A task that takes minutes or hours breaks every assumption built into request/response APIs. The HTTP connection times out. The process may restart. The user closes the browser. You need a different execution model: the task is a durable record, not an in-memory coroutine.

## Checkpointing Progress

Every significant step the agent completes should be written to storage before moving on. Don't hold progress in memory.

```typescript
interface AgentCheckpoint {
  task_id: string;
  step: number;
  step_name: string;
  inputs: Record<string, unknown>;
  outputs: Record<string, unknown>;
  status: "running" | "paused" | "waiting_human" | "complete" | "failed";
  created_at: string;
  updated_at: string;
}
```

After each tool call: write a checkpoint. Before each tool call: read the checkpoint to verify you're still on the right task version.

Why: if the process dies between step 4 and step 5, resume from step 4 rather than from the beginning. For tasks with API cost, restarting from scratch is expensive and often wrong (side effects from earlier steps may have already occurred).

## Resumability After Failure

Design tasks to be restartable. Each step should be idempotent or gated behind a "already done?" check:

```typescript
async function processStep(taskId: string, stepName: string, fn: () => Promise<unknown>) {
  const existing = await db.checkpoint.findFirst({ where: { task_id: taskId, step_name: stepName, status: "complete" } });
  if (existing) return existing.outputs; // skip — already done
  const result = await fn();
  await db.checkpoint.create({ data: { task_id: taskId, step_name: stepName, outputs: result, status: "complete" } });
  return result;
}
```

On resume, fast-forward through completed steps by replaying their stored outputs. Never re-execute a completed step that may have side effects (sent an email, charged a card, updated a record).

## Progress Reporting to UI

Two viable patterns:

**SSE (Server-Sent Events)** — best for real-time streaming. Client opens one long-lived connection, server pushes events as steps complete:
```
data: {"step": "search_customer", "status": "complete", "progress": 0.2}
data: {"step": "fetch_orders", "status": "running", "progress": 0.4}
```
Works well for tasks under ~5 minutes. Falls apart if the server restarts.

**Polling** — best for long tasks or unreliable connections. Client polls `GET /tasks/:id/status` every N seconds. Server reads from the checkpoint table and returns current state. No persistent connection needed — survives server restarts, deploys, mobile backgrounding.

Use polling for tasks over 5 minutes or when resumability matters. Use SSE for tasks under 5 minutes where real-time feedback is important.

## Timeout Handling

Set timeouts at two levels:

**Per-step timeout** — each individual tool call has a max duration. If it exceeds it, mark the step failed, write the checkpoint, surface a meaningful error. Don't let one slow tool call block the entire task indefinitely.

**Task-level timeout** — the entire task has a max wall-clock duration. After which, mark the task as timed_out, release any locks, and notify the user. The timeout must be explicit, not implicit (don't rely on server restart to clean up).

```typescript
const STEP_TIMEOUT_MS = 30_000;
const TASK_TIMEOUT_MS = 60 * 60 * 1000; // 1 hour

// Set task deadline at start
await db.task.update({ where: { id }, data: { deadline: new Date(Date.now() + TASK_TIMEOUT_MS) } });

// Check deadline before each step
if (new Date() > task.deadline) throw new TaskTimeoutError(task.id);
```

## User Notification on Completion

Users don't sit watching a progress bar for 45 minutes. Send a notification:

- Email with a summary and link back to results
- In-app notification (badge or toast on next visit)
- Webhook if the user's system needs to act on completion

Notification should include: what completed, key result metrics, link to full output, and whether any steps required human follow-up.

Don't notify on every step. Notify on: task complete, task failed, task requires human action, task is taking significantly longer than expected (> 2x estimated time).

## Key Rules

- Write a checkpoint after every significant step — never hold progress only in memory
- Make each step idempotent; skip completed steps on resume rather than re-executing them
- Use polling for tasks over 5 minutes; SSE for shorter tasks needing real-time feedback
- Set both per-step and task-level timeouts explicitly — never rely on implicit cleanup
- Notify users on completion; don't expect them to be watching
- Checkpoint before any step with external side effects — so you know whether to retry or skip
