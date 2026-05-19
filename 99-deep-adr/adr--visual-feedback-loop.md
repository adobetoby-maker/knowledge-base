# ADR: Visual Feedback Loop — Seeing the Product Changes Decision Quality

**Applies to:** All frontend projects
**Decision:** Never declare UI work done without viewing the output. The feedback loop is the work.
**Status:** Permanent principle.

## The Core Observation

When building UI without seeing it, the decisions made are fundamentally different — and worse — than when building with continuous visual feedback. This is not a discipline failure. It's an information failure.

Example from willie-elam.com session:
- Without seeing the image, the working choice was "use whatever image exists for this slot"
- With seeing the image (via multimodal read), the decision became "this photo is wrong for this context — find the best one"
- The difference: passive gap-filling vs. active visual judgment

**The ability to see what you're building is a capability multiplier, not a convenience.**

## The Tools

**For static content (forms, grids, typography, responsive layouts):**
```bash
node ~/screenshot.js <port> 0,540,810,1200
```
Takes snapshots at scroll positions → `/tmp/preview/`. Use this to verify layout, check typography, confirm images loaded correctly.

**For animated/scroll-driven UI (Framer Motion, scroll effects, parallax, hover states):**
```bash
node ~/record.js <port>              # 30s scroll-through
node ~/record.js <port> --mobile     # iPhone viewport
node ~/record.js <port> --fast       # 12s quick check
```
Screenshot cannot capture animated state — it freezes mid-animation. `record.js` generates a real video.

**For any iteration involving:**
- Scroll animations
- Transitions and hover states
- Parallax
- Sticky elements
- Framer Motion sequences

Use `record.js` BEFORE and AFTER the change. Static screenshots will give false results.

## The Split Pane Workflow

The devtools server at `http://localhost:3333` provides a terminal + live preview side-by-side.

1. Start project dev server: `npx next dev -H 0.0.0.0 -p <port>`
2. Load `http://100.117.143.57:<port>` in the right iframe (accessible from phone via Tailscale)
3. Edit code in the terminal pane
4. Hot reload fires in the preview iframe

This workflow eliminates the mode-switch between coding and viewing. When they happen simultaneously, quality improves.

## The Image Selection Principle

When choosing between images for a UI slot, never accept the first available option if it isn't the best one. The question is not "does an image exist?" but "is this the right image for this context?"

For an athlete website:
- Show action at that specific location → use the location-appropriate action photo
- Hero needs power and height → use the most dramatic air shot
- Sponsor section needs recognition → use the photo where the sponsor's branding is clearest

The ability to actually read and view image files (multimodal) means these judgments can be made during development, not after. Use it.

## Why Automated Tests Don't Substitute

Lighthouse scores, type checks, and test suites verify code correctness. They cannot tell you:
- Whether the hero image conveys what it should
- Whether the color contrast feels right at that font size
- Whether the spacing looks intentional or accidental
- Whether an animation overshoots or feels smooth

These require human visual judgment. The feedback loop makes that judgment available during development.
