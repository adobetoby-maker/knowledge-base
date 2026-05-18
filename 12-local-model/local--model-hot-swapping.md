# Local Model: Model Hot-Swapping Without Downtime

## Overview
Replacing the model a service uses typically requires downtime: unload the old model from VRAM, load the new one, restart the server. For production systems, this means a maintenance window. Hot-swapping avoids downtime by loading the new model alongside the old one (double-buffering), verifying it, then atomically redirecting traffic. Ollama and llama.cpp support this at different levels.

## Implementation / Key Points

### Ollama Hot-Swap (Single Instance)
Ollama manages model loading/unloading in the background. Requesting a different model triggers a load that runs concurrently with serving the current model:

```bash
# Pull new model while old model continues serving
curl -s http://localhost:11434/api/pull -d '{"name": "llama3.2:8b-q4_K_M"}'

# Ollama doesn't support concurrent model serving by default
# (one model in VRAM at a time, switches between requests)
# For zero-downtime, run two Ollama instances:

# Instance 1 (current): localhost:11434 — model A
# Instance 2 (new): localhost:11435 — model B
```

### Double-Buffering Pattern (Load Balancer)
```typescript
// model-router.ts
let activePort = 11434;
let stagingPort = 11435;

async function swapModels(newModel: string) {
  // 1. Load new model on staging instance
  await pullModel(stagingPort, newModel);
  
  // 2. Health check: run test prompt
  const testResult = await runTestPrompt(stagingPort);
  if (!isAcceptable(testResult)) {
    console.error('New model failed health check, aborting swap');
    return false;
  }
  
  // 3. Atomic swap — redirect traffic to staging
  const temp = activePort;
  activePort = stagingPort;
  stagingPort = temp;
  
  // 4. Drain old instance (wait for in-flight requests)
  await drainInFlightRequests(stagingPort);
  
  console.log(`Swapped to ${newModel} on port ${activePort}`);
  return true;
}

function getActiveEndpoint() {
  return `http://localhost:${activePort}`;
}
```

### Health Check Before Routing Traffic
```typescript
const TEST_PROMPTS = [
  {
    prompt: "What is 2 + 2? Answer with just the number.",
    validate: (response: string) => response.trim() === "4",
  },
  {
    prompt: "Classify this as positive or negative: 'Great product!' Answer: positive or negative.",
    validate: (response: string) => response.toLowerCase().includes("positive"),
  },
];

async function healthCheckModel(port: number): Promise<boolean> {
  for (const test of TEST_PROMPTS) {
    const response = await runPrompt(port, test.prompt);
    if (!test.validate(response)) {
      console.error(`Health check failed: "${test.prompt}" → "${response}"`);
      return false;
    }
  }
  return true;
}
```

### Eval Score Gate Before Swap
```typescript
async function swapIfBetter(newModel: string, threshold = 0.05): Promise<boolean> {
  // Load new model on staging
  await loadModel(stagingPort, newModel);
  
  // Run eval on staging
  const newScore = await runEvalSuite(stagingPort);
  const currentScore = await runEvalSuite(activePort);
  
  if (newScore < currentScore - threshold) {
    console.log(`New model score ${newScore} worse than current ${currentScore} by >${threshold}`);
    return false;
  }
  
  // Safe to swap
  await atomicSwap();
  console.log(`Swapped: ${currentScore} → ${newScore}`);
  return true;
}
```

### Gradual Traffic Shifting
```typescript
let trafficRatio = 0;  // 0 = all to old, 1 = all to new

function getEndpoint(): string {
  return Math.random() < trafficRatio
    ? `http://localhost:${stagingPort}`   // new model
    : `http://localhost:${activePort}`;   // old model
}

// Canary deployment
async function gradualSwap(newModel: string) {
  await loadModel(stagingPort, newModel);
  
  for (const ratio of [0.1, 0.25, 0.5, 0.75, 1.0]) {
    trafficRatio = ratio;
    await sleep(5 * 60 * 1000);  // 5 minutes at each ratio
    
    const errorRate = await measureErrorRate(stagingPort);
    if (errorRate > 0.02) {
      trafficRatio = 0;  // rollback
      console.error(`Error rate ${errorRate} exceeded 2%, rolled back`);
      return;
    }
  }
  
  activePort = stagingPort;  // fully swapped
}
```

### Rollback
```typescript
let previousModel = 'llama3.1:8b-q4_K_M';
let currentModel = 'llama3.2:8b-q4_K_M';

async function rollback() {
  activePort = stagingPort;  // swap back
  console.log(`Rolled back to ${previousModel}`);
}
```

## Key Rules
- Always health check the new model before routing any production traffic to it
- Use a test prompt with a deterministic expected answer for health checks — not open-ended generation
- Rollback means swapping ports back — keep the previous model loaded during the canary period
- Gradual traffic shifting (canary) is safer than instant cutover for models serving high traffic
- Run your eval suite against the new model before considering a swap — quality can silently regress
- Document the model version currently in production in a config file, not just in memory
