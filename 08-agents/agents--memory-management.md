# Agent: Memory Management

## Overview

Agents need memory to operate across long conversations and sessions. There are four types: in-context memory (current messages), episodic memory (past sessions), semantic memory (facts about the user/world), and procedural memory (learned behaviors). Most applications need all four, but implementing them incrementally is the practical approach.

## Memory Types

```ts
type MemoryType = 'episodic' | 'semantic' | 'procedural'

interface Memory {
  id: string
  type: MemoryType
  content: string           // The stored information
  embedding?: number[]      // For semantic search
  importance: number        // 0–1, for pruning
  accessCount: number       // How often retrieved
  lastAccessedAt: Date
  createdAt: Date
  expiresAt?: Date          // Ephemeral memories
}
```

## Semantic Memory (Facts)

Semantic memory stores user facts that should persist across sessions:

```ts
// Store a fact
async function storeFact(agentId: string, fact: string): Promise<void> {
  const embedding = await embed(fact)

  await db.insert(agentMemories).values({
    agentId,
    type: 'semantic',
    content: fact,
    embedding,
    importance: 0.8,
  }).onConflictDoUpdate({
    target: [agentMemories.agentId, agentMemories.content],
    set: { accessCount: sql`${agentMemories.accessCount} + 1`, lastAccessedAt: new Date() },
  })
}

// Retrieve relevant facts for a query
async function retrieveFacts(agentId: string, query: string, k = 5): Promise<string[]> {
  const queryEmbedding = await embed(query)

  // pgvector cosine similarity search
  const results = await db.execute(sql`
    SELECT content
    FROM agent_memories
    WHERE agent_id = ${agentId}
      AND type = 'semantic'
    ORDER BY embedding <=> ${JSON.stringify(queryEmbedding)}::vector
    LIMIT ${k}
  `)

  return results.rows.map(r => (r as { content: string }).content)
}
```

## Episodic Memory (Past Interactions)

```ts
// At end of each conversation, summarize and store
async function storeConversationSummary(agentId: string, messages: Message[]): Promise<void> {
  const summary = await summarizeConversation(messages)
  const embedding = await embed(summary)

  await db.insert(agentMemories).values({
    agentId,
    type: 'episodic',
    content: summary,
    embedding,
    importance: 0.6,
    expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),  // 90 days
  })
}

async function summarizeConversation(messages: Message[]): Promise<string> {
  const conversation = messages.map(m => `${m.role}: ${m.content}`).join('\n')
  const response = await llm.complete({
    prompt: `Summarize this conversation in 2-3 sentences, focusing on key facts, decisions, and context:

${conversation}

Summary:`,
    maxTokens: 200,
  })
  return response.text.trim()
}
```

## Injection into Prompt

```ts
async function buildPromptWithMemory(agentId: string, userMessage: string, basePrompt: string): Promise<string> {
  const [semanticFacts, recentEpisodes] = await Promise.all([
    retrieveFacts(agentId, userMessage, 5),
    getRecentEpisodes(agentId, 3),
  ])

  let prompt = basePrompt

  if (semanticFacts.length > 0) {
    prompt += `\n\n## What I know about the user:\n${semanticFacts.map(f => `- ${f}`).join('\n')}`
  }

  if (recentEpisodes.length > 0) {
    prompt += `\n\n## Recent conversation context:\n${recentEpisodes.map(e => `- ${e}`).join('\n')}`
  }

  return prompt
}
```

## Memory Extraction from Conversation

```ts
// Extract new facts from the conversation to store
async function extractAndStoreFacts(agentId: string, userMessage: string, agentResponse: string): Promise<void> {
  const extraction = await llm.complete({
    prompt: `From this exchange, extract any NEW facts about the user worth remembering.
Return as a JSON array of strings, or empty array if nothing new.

User: ${userMessage}
Agent: ${agentResponse}

Facts:`,
    maxTokens: 200,
  })

  try {
    const facts: string[] = JSON.parse(extractJson(extraction.text))
    await Promise.all(facts.map(fact => storeFact(agentId, fact)))
  } catch {
    // Extraction failed — non-critical, continue without storing
  }
}
```

## Memory Pruning

```ts
// Run periodically to remove low-value memories
async function pruneMemories(agentId: string): Promise<void> {
  // Delete expired memories
  await db.delete(agentMemories)
    .where(and(
      eq(agentMemories.agentId, agentId),
      lt(agentMemories.expiresAt, new Date()),
    ))

  // Delete low-importance, rarely accessed memories when over limit
  const count = await getMemoryCount(agentId)
  const MAX_MEMORIES = 1000

  if (count > MAX_MEMORIES) {
    await db.execute(sql`
      DELETE FROM agent_memories
      WHERE agent_id = ${agentId}
        AND id IN (
          SELECT id FROM agent_memories
          WHERE agent_id = ${agentId}
          ORDER BY (importance * log(access_count + 1)) ASC
          LIMIT ${count - MAX_MEMORIES}
        )
    `)
  }
}
```

## Key Rules

- Retrieve memory based on relevance to the current query (semantic search), not just recency — old memories are often more relevant than recent ones.
- Extract and store facts after every conversation, not just at the end of sessions — users drop important context mid-conversation.
- Limit injected memory to what fits within the model's effective context (typically 10-20 facts) — too much memory degrades performance.
- Prune memories using a combination of importance, recency, and access frequency — rarely-accessed low-importance memories aren't worth keeping.
- Make memory storage optional and user-controllable — give users a way to view and delete what the agent remembers about them.
