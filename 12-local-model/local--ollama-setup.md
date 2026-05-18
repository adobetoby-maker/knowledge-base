# Local Model Setup with Ollama

**When:** Setting up or running local model sessions for overnight batch work.
**Rule:** Ollama is the simplest local model runtime. Run models locally, call via API, pipe knowledge files as context.

## Installation
```bash
# macOS
brew install ollama

# Start service
ollama serve

# Pull models
ollama pull llama3.3:70b          # best all-around for code
ollama pull deepseek-coder-v2:33b # best specifically for code
ollama pull qwen2.5:72b           # strong instruction following
ollama pull llama3.2:3b           # fast, cheap, for mechanical tasks
```

## Basic Usage
```bash
# Interactive chat
ollama run llama3.3:70b

# Single prompt (pipe input)
echo "List all TypeScript files in the src/ directory" | ollama run llama3.2:3b

# With a system prompt
ollama run llama3.3:70b --system "You are a code editor. Only output complete file contents."
```

## API Usage (for scripts)
```bash
# Ollama serves on http://localhost:11434

curl http://localhost:11434/api/generate -d '{
  "model": "llama3.3:70b",
  "prompt": "Fix this TypeScript file: ...",
  "stream": false,
  "options": { "temperature": 0 }
}'
```

## Loading Knowledge Files as Context
```bash
# Load a knowledge bundle as system prompt
BUNDLE=$(cat ~/knowledge-base/13-stack-bundles/bundle--nextjs-supabase-feature.md)

curl http://localhost:11434/api/generate -d "{
  \"model\": \"llama3.3:70b\",
  \"system\": \"$BUNDLE\",
  \"prompt\": \"Add a customer feedback form to the contact page\",
  \"stream\": false,
  \"options\": { \"temperature\": 0 }
}"
```

## Overnight Batch Script Pattern
```bash
#!/bin/bash
# overnight-task.sh

MODEL="llama3.3:70b"
BUNDLE=$(cat ~/knowledge-base/13-stack-bundles/bundle--nextjs-supabase-feature.md)
PROJECT="/Users/drive/jrs-auto-repair"
LOG="$PROJECT/OVERNIGHT_LOG.md"

echo "# Overnight Session $(date)" >> $LOG

# Task
TASK="Add a promotional banner component that shows above the navbar with a dismiss button"

RESULT=$(curl -s http://localhost:11434/api/generate -d "{
  \"model\": \"$MODEL\",
  \"system\": \"$BUNDLE\n\nProject path: $PROJECT\nOnly create files. Never delete files. Write complete file contents.\",
  \"prompt\": \"$TASK\",
  \"stream\": false,
  \"options\": { \"temperature\": 0 }
}" | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])")

echo "## Task: $TASK" >> $LOG
echo "$RESULT" >> $LOG

# Verify
cd $PROJECT && npm run build >> $LOG 2>&1

echo "Session complete: $(date)" >> $LOG
```

## Model File Sizes (for disk planning)
```
llama3.2:3b       — 2GB
llama3.3:70b      — 43GB (fp16) / 22GB (q4)
deepseek-coder:33b — 20GB
qwen2.5:72b       — 45GB (fp16) / 23GB (q4)
```

## Quantization Tradeoff
`llama3.3:70b` → 43GB, best quality
`llama3.3:70b:q4` → 22GB, ~5% quality drop, 2x faster
`llama3.3:70b:q8` → 43GB, ~1% quality drop, same speed as fp16
For overnight batch work: q4 is usually the right tradeoff.
