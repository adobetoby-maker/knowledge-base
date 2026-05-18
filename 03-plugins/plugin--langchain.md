# Plugin: LangChain.js

## Overview

LangChain is a framework for building LLM applications: chains, agents with tools, RAG pipelines, memory. For most product use cases, use the Vercel AI SDK instead (simpler, Vercel-native). Use LangChain when you need: complex multi-step chains with conditional routing, LangGraph for stateful agent loops, or when integrating multiple LLM providers with a unified interface.

## Install

```bash
npm install langchain @langchain/core @langchain/openai @langchain/anthropic
```

## Basic LLM Call

```ts
import { ChatAnthropic } from '@langchain/anthropic'
import { HumanMessage, SystemMessage } from '@langchain/core/messages'

const model = new ChatAnthropic({
  model: 'claude-haiku-4-5',
  temperature: 0,
})

const response = await model.invoke([
  new SystemMessage('You are a helpful assistant.'),
  new HumanMessage('What is 2+2?'),
])

console.log(response.content)  // '4'
```

## Prompt Template + Chain

```ts
import { ChatPromptTemplate } from '@langchain/core/prompts'
import { StringOutputParser } from '@langchain/core/output_parsers'

const prompt = ChatPromptTemplate.fromMessages([
  ['system', 'You are a {tone} customer support agent.'],
  ['human', '{question}'],
])

const chain = prompt.pipe(model).pipe(new StringOutputParser())

const answer = await chain.invoke({
  tone: 'friendly',
  question: 'How do I reset my password?',
})
```

## Structured Output

```ts
import { z } from 'zod'

const classifySchema = z.object({
  category: z.enum(['billing', 'technical', 'general', 'urgent']),
  priority: z.number().min(1).max(5),
  summary: z.string(),
})

const structuredModel = model.withStructuredOutput(classifySchema)

const result = await structuredModel.invoke(
  'My account is showing a charge I never authorized and I can\'t log in'
)
// result.category === 'urgent', result.priority === 5
```

## RAG with Vector Store

```ts
import { MemoryVectorStore } from 'langchain/vectorstores/memory'
import { OpenAIEmbeddings } from '@langchain/openai'
import { createRetrievalChain } from 'langchain/chains/retrieval'
import { createStuffDocumentsChain } from 'langchain/chains/combine_documents'

// Build vector store from documents
const vectorStore = await MemoryVectorStore.fromDocuments(
  documents,
  new OpenAIEmbeddings()
)

const retriever = vectorStore.asRetriever({ k: 4 })

// Retrieval QA chain
const qaChain = await createRetrievalChain({
  retriever,
  combineDocsChain: await createStuffDocumentsChain({
    llm: model,
    prompt: ChatPromptTemplate.fromMessages([
      ['system', 'Answer based only on this context:\n{context}'],
      ['human', '{input}'],
    ]),
  }),
})

const result = await qaChain.invoke({ input: 'What is the return policy?' })
// result.answer, result.context (source documents)
```

## Tool Calling Agent

```ts
import { tool } from '@langchain/core/tools'
import { createReactAgent } from '@langchain/langgraph/prebuilt'

const getWeatherTool = tool(
  async ({ city }) => {
    const data = await fetchWeather(city)
    return JSON.stringify(data)
  },
  {
    name: 'get_weather',
    description: 'Get current weather for a city',
    schema: z.object({ city: z.string() }),
  }
)

const agent = createReactAgent({
  llm: model,
  tools: [getWeatherTool],
})

const result = await agent.invoke({
  messages: [new HumanMessage('What\'s the weather in Tokyo?')],
})
```

## Streaming

```ts
const stream = await chain.stream({ question: 'Explain quantum computing' })

for await (const chunk of stream) {
  process.stdout.write(chunk)
}

// In a Next.js route handler:
const stream = await chain.stream({ question })
return new Response(
  new ReadableStream({
    async start(controller) {
      for await (const chunk of stream) {
        controller.enqueue(new TextEncoder().encode(chunk))
      }
      controller.close()
    },
  }),
  { headers: { 'Content-Type': 'text/plain; charset=utf-8' } }
)
```

## Key Rules

- LangChain adds significant bundle size — for simple LLM calls with one provider, use the provider's SDK directly (Anthropic SDK, OpenAI SDK) or the Vercel AI SDK.
- `withStructuredOutput` uses function calling / tool use under the hood — it's more reliable than asking the LLM to return JSON in its text response.
- Always use `ChatPromptTemplate` rather than string templates — it handles escaping and supports multiple message types.
- `MemoryVectorStore` is for prototyping only — use a real vector DB (pgvector, Pinecone, Qdrant) for production RAG.
- LangGraph is the correct tool for complex multi-step agents with conditional branching — plain LangChain chains are for linear pipelines.
