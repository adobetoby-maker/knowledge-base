# Agent Handoff Protocols

## What a Handoff Is

A handoff is the transfer of task context from one agent invocation to the next. Because agents don't share memory across invocations by default, the handoff is the only thing that makes multi-step work coherent.

A bad handoff = lost context = the next agent re-derives what was already known, wastes tokens, or makes wrong assumptions.

## The Handoff Document

Produce a structured handoff at the end of each major phase:

```typescript
interface AgentHandoff {
  task: string                    // what was being done
  completedSteps: string[]        // what is done (factual)
  currentState: Record<string, unknown>  // relevant values the next agent needs
  pendingSteps: string[]          // what remains (in order)
  blockers: string[]              // things that need human input
  artifacts: {
    path: string
    description: string
  }[]
  notes: string                   // anything that would surprise the next agent
}
```

```typescript
// At the end of phase 1 (research):
const handoff: AgentHandoff = {
  task: 'Build article cluster about brakes for JRS blog',
  completedSteps: [
    'Researched 12 competitor brake articles',
    'Identified 5 content gaps',
    'Outlined 8 article titles with target keywords',
  ],
  currentState: {
    articleCount: 8,
    targetKeywords: ['brake repair Twin Falls', 'brake pad replacement Idaho'],
    outlineFile: '~/.claude/projects/jrs/brake-cluster-outline.json',
  },
  pendingSteps: [
    'Write 8 articles using outline',
    'Add to lib/articles.ts',
    'Update sitemap',
  ],
  blockers: [],
  artifacts: [
    { path: '~/.claude/projects/jrs/brake-cluster-outline.json', description: 'Article outlines with keywords' }
  ],
  notes: 'Articles must be 800-1200 words. Use Twin Falls + Magic Valley together in every article.',
}

await fs.writeFile(HANDOFF_PATH, JSON.stringify(handoff, null, 2))
```

## Handoff File Location

Store handoffs in a predictable location the next agent can find:

```typescript
const HANDOFF_DIR = path.join(os.homedir(), '.claude', 'handoffs')
const HANDOFF_PATH = path.join(HANDOFF_DIR, `${projectSlug}-${phase}.json`)
// e.g., ~/.claude/handoffs/jrs-brake-cluster-phase1.json
```

## Reading a Handoff

The receiving agent should read the handoff file first, before any other work:

```typescript
// Start of phase 2 agent prompt:
`Read the handoff file at ${HANDOFF_PATH} and continue from where phase 1 left off.

Completed steps are done — do not redo them.
Start with the first item in pendingSteps.
If blockers is non-empty, report them to the user and stop.`
```

## Incremental Progress Updates

For long tasks within a single invocation, write progress to a file so a resumed agent can skip done work:

```typescript
interface ProgressState {
  totalItems: number
  processedItems: string[]   // IDs or slugs
  failedItems: Array<{ id: string; error: string }>
  lastUpdated: string
}

async function updateProgress(state: ProgressState): Promise<void> {
  state.lastUpdated = new Date().toISOString()
  await fs.writeFile(PROGRESS_PATH, JSON.stringify(state, null, 2))
}

// At start of task, load existing progress:
async function loadProgress(): Promise<ProgressState | null> {
  try {
    const raw = await fs.readFile(PROGRESS_PATH, 'utf8')
    return JSON.parse(raw)
  } catch {
    return null
  }
}

// Process loop with resume support:
const progress = await loadProgress() ?? { totalItems: items.length, processedItems: [], failedItems: [], lastUpdated: '' }
const remaining = items.filter(item => !progress.processedItems.includes(item.id))

for (const item of remaining) {
  await processItem(item)
  progress.processedItems.push(item.id)
  await updateProgress(progress)  // checkpoint every item
}
```

## Handoff Anti-Patterns

**Passing context in the prompt only:** The next agent starts fresh — its context window may not include the prompt that contained your handoff. Always write to a file.

**Handoff with vague pendingSteps:** "Continue the work" tells the next agent nothing. Be specific: "Write articles 4-8 from the outline file, add each to lib/articles.ts immediately after writing."

**Forgetting to note assumptions:** If the first agent made a decision that constrains the second (e.g., "I chose to store as HTML not markdown"), that MUST be in the handoff notes.

**Not marking completedSteps accurately:** If step 3 was partially done, note it as "Step 3: partially complete — wrote 3/8 articles, saved to lib/articles.ts lines 234-280."
