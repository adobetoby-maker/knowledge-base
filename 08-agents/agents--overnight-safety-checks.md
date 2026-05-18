# Agents: Overnight Safety Checks

## The Problem

Agents running overnight have no human in the loop to catch mistakes. An agent that misunderstands a task and runs for 8 hours can cause significant damage: deleting wrong files, spamming emails to real users, running up a $500 API bill, or corrupting a database. Safety checks prevent runaway overnight runs.

## Pre-Flight Safety Check

Before starting any long overnight run, verify these conditions:

```ts
async function preFlightCheck(config: BatchConfig): Promise<void> {
  const checks: Array<{ name: string; pass: boolean; message: string }> = []

  // 1. Estimate cost
  const estimate = estimateBatchCost(config)
  checks.push({
    name: 'Cost estimate',
    pass: estimate.costUsd < config.maxCostUsd,
    message: `Estimated: $${estimate.costUsd.toFixed(2)} / Max: $${config.maxCostUsd}`,
  })

  // 2. Verify target environment
  checks.push({
    name: 'Environment check',
    pass: process.env.NODE_ENV !== 'production' || config.allowProduction === true,
    message: config.allowProduction
      ? 'Production operations authorized'
      : 'Would run against production — add allowProduction: true to authorize',
  })

  // 3. Check external service availability
  const emailOk = await pingService('https://api.resend.com/health')
  checks.push({
    name: 'Email service',
    pass: emailOk,
    message: emailOk ? 'Reachable' : 'Resend API not responding — skip email steps or abort',
  })

  // 4. Verify no recent run (prevent duplicate runs)
  const { data: recentRun } = await supabaseAdmin
    .from('batch_runs')
    .select('started_at')
    .eq('job_name', config.jobName)
    .gt('started_at', new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString())
    .single()

  checks.push({
    name: 'Duplicate run check',
    pass: !recentRun,
    message: recentRun ? `Already ran at ${recentRun.started_at}` : 'No recent run',
  })

  const failed = checks.filter(c => !c.pass)
  if (failed.length > 0) {
    console.error('Pre-flight checks failed:')
    failed.forEach(c => console.error(`  ✗ ${c.name}: ${c.message}`))
    process.exit(1)
  }

  console.log('Pre-flight checks passed:')
  checks.forEach(c => console.log(`  ✓ ${c.name}: ${c.message}`))
}
```

## Hard Limits

```ts
interface BatchLimits {
  maxItems: number           // Never process more than this many items
  maxCostUsd: number         // Hard spending cap
  maxDurationMs: number      // Kill after this duration
  maxErrorRate: number       // Abort if error rate exceeds this fraction (0–1)
  maxApiCallsPerMinute: number
}

const OVERNIGHT_LIMITS: BatchLimits = {
  maxItems: 10_000,
  maxCostUsd: 20.00,
  maxDurationMs: 8 * 60 * 60 * 1000,  // 8 hours
  maxErrorRate: 0.10,  // 10% error rate → abort
  maxApiCallsPerMinute: 60,
}

// Check during run
function checkShouldAbort(stats: RunStats, limits: BatchLimits): string | null {
  if (stats.totalCostUsd >= limits.maxCostUsd) {
    return `Cost limit reached: $${stats.totalCostUsd.toFixed(2)} >= $${limits.maxCostUsd}`
  }
  if (stats.errorRate > limits.maxErrorRate) {
    return `Error rate too high: ${(stats.errorRate * 100).toFixed(1)}% >= ${limits.maxErrorRate * 100}%`
  }
  if (stats.elapsedMs >= limits.maxDurationMs) {
    return `Duration limit reached: ${stats.elapsedMs}ms >= ${limits.maxDurationMs}ms`
  }
  return null
}
```

## Dry Run Mode

Always support a `--dry-run` flag that exercises all the logic without writing:

```ts
const DRY_RUN = process.argv.includes('--dry-run')

async function processItem(item: Item): Promise<void> {
  // ... compute what would happen
  const result = computeChanges(item)

  if (DRY_RUN) {
    console.log(`[DRY RUN] Would process ${item.id}: ${JSON.stringify(result)}`)
    return
  }

  // Only reaches here in real run
  await applyChanges(item.id, result)
}
```

Always run in dry-run mode first and spot-check the output.

## Safe vs Unsafe Operations

```ts
// lib/overnight/safe-ops.ts

// SAFE — can run overnight without confirmation
export const SAFE_OPS = [
  'generate_article_content',   // Writing to lib/articles.ts
  'translate_existing_content', // Reading + writing translated versions
  'send_transactional_email',   // Invoices, confirmations
  'update_search_index',        // Read-only to source, write to search index
  'generate_images',            // ComfyUI image generation
  'run_seo_checks',             // Read-only analysis
] as const

// UNSAFE — require explicit authorization in config
export const UNSAFE_OPS = [
  'delete_database_records',    // Any deletion
  'send_marketing_email',       // Bulk email to user list
  'update_payment_records',     // Financial data mutation
  'push_to_production',         // Deploy
  'remove_files',               // File deletion
] as const
```

## Alerting on Failure

```ts
// Send alert when overnight job fails or exceeds thresholds
async function notifyFailure(jobName: string, error: string) {
  // iMessage via MCP (on Mac)
  // Alternatively: email, Slack, or just write to a log file for morning review

  const message = `Overnight job ${jobName} failed at ${new Date().toISOString()}: ${error}`
  await fs.promises.appendFile('/tmp/overnight-failures.log', message + '\n')

  // Check this file each morning: cat /tmp/overnight-failures.log
}
```

## Checkpoint-Based Recovery

```ts
// Never process 10,000 items in one shot — checkpoint every batch
async function runWithCheckpoints(items: Item[], batchSize = 50): Promise<void> {
  const checkpoint = loadCheckpoint()
  const startIdx = checkpoint?.completedCount ?? 0

  if (startIdx > 0) {
    console.log(`Resuming from item ${startIdx} of ${items.length}`)
  }

  for (let i = startIdx; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize)
    await processBatch(batch)
    saveCheckpoint({ completedCount: i + batch.length, lastItemId: batch.at(-1)!.id })
  }
}
```

If the script crashes at item 7000, it resumes from item 7000, not item 0.
