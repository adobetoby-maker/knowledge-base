#!/usr/bin/env bash
# LaptopBridge — one-time setup script
# Run on your laptop: bash laptop-setup.sh

set -e

MEMORY_REPO="https://github.com/adobetoby-maker/toby-claude-memory"
KB_REPO="https://github.com/adobetoby-maker/knowledge-base"
MEMORY_DIR="$HOME/.claude/projects/-Users-drive/memory"
KB_DIR="$HOME/knowledge-base"
BOOTSTRAP="$HOME/.claude/bootstrap"

echo "── Creating directories ────────────────────────────"
mkdir -p "$HOME/.claude/projects/-Users-drive"
mkdir -p "$BOOTSTRAP"
mkdir -p "$HOME/.remember/logs"

echo "── Cloning memory repo ─────────────────────────────"
if [ -d "$MEMORY_DIR/.git" ]; then
  echo "Already cloned — pulling latest..."
  cd "$MEMORY_DIR" && git pull origin main --quiet
else
  git clone "$MEMORY_REPO" "$MEMORY_DIR"
fi

echo "── Cloning knowledge base ──────────────────────────"
if [ -d "$KB_DIR/.git" ]; then
  echo "Already cloned — pulling latest..."
  cd "$KB_DIR" && git pull origin main --quiet
else
  git clone "$KB_REPO" "$KB_DIR"
fi

echo "── Writing hooks.json ──────────────────────────────"
cat > "$HOME/.claude/hooks.json" << 'EOF'
{
  "description": "Global auto-bootstrap hooks for Toby's Claude Code workspace",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/bootstrap/session-start.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/bootstrap/memory-writeback.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
EOF

echo "── Writing session-start.sh ────────────────────────"
cat > "$BOOTSTRAP/session-start.sh" << 'SCRIPT'
#!/usr/bin/env bash
# SessionStart hook — pull latest memory then output context

# Pull latest from M1 Ultra before loading
MEMORY_DIR="$HOME/.claude/projects/-Users-drive/memory"
cd "$MEMORY_DIR" && git pull origin main --quiet 2>/dev/null || true

MEMORY_INDEX=""
if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
  MEMORY_INDEX=$(cat "$MEMORY_DIR/MEMORY.md")
fi

LAST_SYNC="unknown"
if [ -f "$HOME/.claude/bootstrap/.last-memory-sync" ]; then
  LAST_SYNC=$(cat "$HOME/.claude/bootstrap/.last-memory-sync")
fi

LOG_TAIL=""
if [ -f "$HOME/.claude/bootstrap/.memory-sync.log" ]; then
  LOG_TAIL=$(tail -1 "$HOME/.claude/bootstrap/.memory-sync.log")
fi

FILE_COUNT=$(ls "$MEMORY_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')

OUTPUT=$(cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "# Auto-Bootstrap Context (Laptop)\n\n## Memory Index\n${MEMORY_INDEX}\n\n## Memory Sync Status\nLast sync: ${LAST_SYNC} | Files: ${FILE_COUNT} | ${LOG_TAIL}\n\n## Key Reminders\n- This is the LAPTOP. M1 Ultra is the primary machine.\n- Memory repo: github.com/adobetoby-maker/toby-claude-memory\n- Projects on M1: /Users/drive/jrs-auto-repair, /Users/drive/lingua-lens\n"
  }
}
EOF
)

echo "$OUTPUT"
SCRIPT
chmod +x "$BOOTSTRAP/session-start.sh"

echo "── Writing memory-writeback.sh ─────────────────────"
cat > "$BOOTSTRAP/memory-writeback.sh" << 'SCRIPT'
#!/usr/bin/env bash
# Stop hook — dump claude-mem SQLite + push to GitHub

# Dump claude-mem SQLite if it exists
CLAUDE_MEM_DB=$(find "$HOME/.claude-mem" -name "*.db" -o -name "*.sqlite" 2>/dev/null | head -1)
MEMORY_DIR="$HOME/.claude/projects/-Users-drive/memory"
if [ -n "$CLAUDE_MEM_DB" ]; then
  sqlite3 "$CLAUDE_MEM_DB" .dump > "$MEMORY_DIR/claude-mem-backup.sql" 2>/dev/null || true
fi

# Push to GitHub if anything changed
if [ -d "$MEMORY_DIR/.git" ]; then
  cd "$MEMORY_DIR"
  if git status --porcelain 2>/dev/null | grep -q .; then
    git add -A
    git commit -m "sync: $(date -u +%Y-%m-%dT%H:%M:%SZ) [$(hostname -s)]" --quiet 2>/dev/null || true
    git push origin main --quiet 2>/dev/null || true
  fi
fi

exit 0
SCRIPT
chmod +x "$BOOTSTRAP/memory-writeback.sh"

echo ""
echo "── Installing kb-ingest.sh + indexing knowledge base ──"
# Copy ingest script from memory repo to bootstrap
cp "$MEMORY_DIR/kb-ingest.sh" "$BOOTSTRAP/kb-ingest.sh"
chmod +x "$BOOTSTRAP/kb-ingest.sh"

if command -v claude-flow >/dev/null 2>&1; then
  bash "$BOOTSTRAP/kb-ingest.sh" --quiet
else
  echo "  ⚠️  claude-flow not installed — run 'npm install -g @claude-flow/cli' then bash ~/.claude/bootstrap/kb-ingest.sh"
fi

echo ""
echo "── Done ────────────────────────────────────────────"
echo "Memory repo:  $MEMORY_DIR"
echo "Knowledge base: $KB_DIR  (github.com/adobetoby-maker/knowledge-base)"
echo "Hooks:        $HOME/.claude/hooks.json"
echo "Bootstrap:    $BOOTSTRAP/"
echo ""
echo "Restart Claude Code and you're good to go."
