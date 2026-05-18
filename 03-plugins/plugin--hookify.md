# Plugin: hookify@claude-plugins-official

**What it provides:** Claude Code hook management — automate behaviors before/after tool calls, on session start/stop.
**When to reach for it:** Setting up automated behaviors like "always take a screenshot after editing UI files", "run lint before committing", "log every file edit".

## What Hooks Are
Hooks are shell commands that run automatically in response to Claude Code events:
- **PreToolUse** — before a tool executes (can block the tool)
- **PostToolUse** — after a tool executes
- **Notification** — when Claude sends a notification
- **Stop** — when Claude stops generating

They live in `~/.claude/settings.json` under `"hooks"`.

## Key Skills
- `hookify:hookify` — analyze the conversation and suggest hooks to prevent recurring mistakes
- `hookify:list` — show current hooks
- `hookify:configure` — configure a new hook
- `hookify:help` — hook system guidance
- `hookify:writing-rules` — how to write good hook rules
- `update-config` — directly edit settings.json to add/modify hooks

## Common Hook Patterns

### Auto-screenshot after UI edits
```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "if echo '$CLAUDE_TOOL_INPUT' | grep -q '\\.(tsx|css)'; then node ~/screenshot.js 3000 0,540; fi"
      }]
    }]
  }
}
```

### Lint after file edits
```json
{
  "PostToolUse": [{
    "matcher": "Edit|Write",
    "hooks": [{
      "type": "command",
      "command": "cd /Users/drive/$(basename $(pwd)) && npm run lint --silent 2>/dev/null || true"
    }]
  }]
}
```

### Block risky git commands
```json
{
  "PreToolUse": [{
    "matcher": "Bash",
    "hooks": [{
      "type": "command",
      "command": "echo '$CLAUDE_TOOL_INPUT' | grep -qE 'git (reset --hard|clean -f|push.*main.*force)' && echo 'BLOCKED: risky git operation' && exit 1 || exit 0"
    }]
  }]
}
```

## Invoke to Set Up
```
Skill("hookify:hookify")  — analyzes your session, suggests hooks
Skill("hookify:configure", "run lint after every file edit")
Skill("update-config")    — for direct settings.json modification
```

## Settings File Locations
- Project-level: `.claude/settings.json` (affects only this project)
- Global: `~/.claude/settings.json` (affects all sessions)

## Viewing Current Hooks
```bash
cat ~/.claude/settings.json | python3 -m json.tool | grep -A5 '"hooks"'
```
