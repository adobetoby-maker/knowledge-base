# Project: Dev Tools

## Overview

`/Users/drive/devtools/` — a local browser-based split-screen development tool.

Provides a terminal (left pane) + live preview (right pane) accessible from any device on the Tailscale network.

## Architecture

```
/Users/drive/devtools/
  server.mjs        → Node.js server (HTTP + WebSocket)
  public/
    index.html      → Split pane UI
    app.js          → WebSocket client
    styles.css      → Layout CSS
```

**WebSocket → PTY:** Uses `node-pty` to spawn a real `zsh` process. Terminal input/output is proxied via WebSocket, giving a real shell in the browser.

**Right pane:** An `<iframe>` with a URL bar at the top. Point it at any `localhost:PORT` running on the Mac.

## Starting the Server

```bash
node /Users/drive/devtools/server.mjs
# Binds to 0.0.0.0:3333 (all interfaces, including Tailscale)
```

```
Local:     http://localhost:3333
Tailscale: http://100.117.143.57:3333
```

## Starting a Project Dev Server for Preview

All project servers must bind to `0.0.0.0` for Tailscale access:

```bash
# Next.js projects:
cd /Users/drive/jrs-auto-repair && npx next dev -H 0.0.0.0 -p 3001
cd /Users/drive/manage-worker-bee && npx next dev -H 0.0.0.0 -p 3002

# TanStack Start:
cd /Users/drive/language-lens-elite && npm run dev  # already binds to 0.0.0.0
```

## Screenshot Tool

```bash
node /Users/drive/screenshot.js [port] [scroll1,scroll2,...]

# Examples:
node ~/screenshot.js 3001              # screenshot at scroll 0
node ~/screenshot.js 3001 0,540,1080   # 3 screenshots at different scroll positions

# Output: /tmp/preview/*.png
```

Uses Playwright headless Chrome internally. Takes screenshots of the preview iframe target.

## Video Review Tool

```bash
node /Users/drive/record.js [port] [options]

node ~/record.js 3001              # 30s default
node ~/record.js 3001 --mobile     # iPhone viewport (390×844)
node ~/record.js 3001 --fast       # 12s quick check
node ~/record.js 3001 --slow       # 60s detailed

# Output: /tmp/preview/review.mp4
open /tmp/preview/review.mp4
```

Required for: scroll animations, hover states, parallax, sticky elements, Framer Motion. Static screenshots freeze mid-animation.

## When node-pty Fails on macOS

```bash
cd /Users/drive/devtools
npm rebuild node-pty
xattr -cr node_modules/node-pty/prebuilds/darwin-arm64/
chmod +x node_modules/node-pty/prebuilds/darwin-arm64/spawn-helper
```

Happens after OS updates or when prebuilds don't match the current Node version.

## Tailscale IP

`100.117.143.57` — static within the Tailscale mesh. Used for:
- Accessing devtools from iPhone or iPad while sitting at the desk
- Sharing a dev server link with collaborators on the same Tailscale network

## Port Convention

| Port | Project |
|---|---|
| 3333 | Devtools server |
| 3000 | Default Next.js |
| 3001 | jrs-auto-repair |
| 3002 | manage-worker-bee |
| 3003 | silver-creek-logistics |
| 3004 | orthobiologic-pathways |
| 3005 | dex-project / nexus |
| 3007 | salvorias-lp |
| 5173 | language-lens-elite (Vite default) |
