# ADR: Canvas Game — Physics Space vs Screen Space (The Core Bug)

**Project:** willie-elam (SnowbikeGame.tsx)
**Decision:** Physics position (`s.y`) and draw position are not the same thing.
**Status:** Fixed. The lesson is permanent.

## The Bug That Made the Game Unplayable

The original game was unplayable because jumps were invisible. The player would hit a ramp, the physics engine would correctly launch them into the air (increasing `s.y` upward), the velocity, gravity, and arc were all computed correctly — but visually the sled stayed glued to the ground.

The cause was a single wrong line in the draw call:

```ts
// WRONG — always draws at terrain height regardless of physics
const groundY = tyAt(tp, wx);
drawSled(ctx, screenX, groundY - 16, s.angle, throttle, s.heat);
```

The fix was one additional variable:

```ts
// RIGHT — use physics y when airborne, snap to terrain when grounded
const groundY = tyAt(tp, wx);
const drawY = s.onGround ? groundY - 16 : s.y;
drawSled(ctx, screenX, drawY, s.angle, throttle, s.heat);
```

## Why This Happens

Canvas 2D games maintain two separate coordinate systems that developers frequently conflate:

**Physics space:** The simulation. `s.x`, `s.y` are the vehicle's position in an infinite world. `s.vy` adds GRAVITY each frame. When the vehicle is in the air, `s.y` moves up and then curves back down. This is correct and should never be bypassed.

**Screen space:** What gets drawn. The canvas is 960×480 pixels. To convert from physics to screen you subtract the camera: `screenX = s.x - s.camX`. But `s.y` IS the screen y — the terrain is drawn at pixel coordinates, gravity pushes `s.y` in pixel space, and the draw calls use raw pixel values.

The confusion arose because when the vehicle is on the ground, `s.y` is snapped to `tyAt(tp, wx) - 16` (16px above terrain surface). So for ground driving, using `tyAt` directly and using `s.y` produce the same result. The bug only manifests when airborne.

## The Ground Shadow as Confirmation

After fixing the draw position, a ground shadow was added to confirm the physics:

```ts
if (!s.onGround) {
  const airH = groundY - s.y - 16;         // how high above ground
  const shadowAlpha = Math.max(0, 0.45 - airH * 0.004);  // fades as you climb
  const shadowScale = Math.max(0.2, 1 - airH * 0.005);   // shrinks with height
  ctx.ellipse(screenX, groundY + 2, 32 * shadowScale, 7 * shadowScale, ...);
}
```

The shadow stays at terrain level while the vehicle rises. This both confirms the physics are working and gives the player visual information about where they'll land.

## Why useRef for Game State, Not useState

The entire game state (`gs.current`) lives in a `useRef`, not React state. This is critical for performance.

`requestAnimationFrame` fires 60 times per second. If game state was in React state (`useState`), each physics update would trigger a React reconciliation and DOM re-render — 60 per second, for a component with a canvas, dozens of style objects, and touch controls. The game would be unplayable at any speed.

The pattern: game state in ref (mutated directly), UI state in React state (updated every 5 frames):

```ts
const gs = useRef<GS>({ x: 200, y: 300, vx: 0, ... });  // mutated in loop

// In the loop, every 5 frames:
if (s.frame % 5 === 0) setUiData({ score: s.score, heat: s.heat, laps: s.laps, ... });
```

`uiData` drives the score/heat React UI outside the canvas. The canvas itself is drawn imperatively — React never touches it.

## The Touch Control Pattern

Touch controls use a separate ref dictionary `touchRef.current`, checked the same way as keyboard keys:

```ts
const throttle = (keys["ArrowUp"] || keys["KeyW"] || touch["up"]) && !s.overheated;
```

The ref is written by touch event handlers on the virtual D-pad buttons:

```ts
const onTouch = (key: string, down: boolean) => (e) => {
  e.preventDefault();
  touchRef.current[key] = down;
};
```

`e.preventDefault()` is required to stop the browser from converting touch events into simulated mouse events, which would fire twice. Without it, each touch triggers both the touch handler and a 300ms-delayed mouse event.

## The `roundRect` Polyfill

All rounded rectangles use a custom `rr()` helper instead of `ctx.roundRect()`. This is because `ctx.roundRect` is a newer Canvas API not available in older browsers. It silently crashes — the error is swallowed, the canvas stays blank, and the user sees nothing.

```ts
function rr(ctx, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r);
  // ... four corners with arcTo
  ctx.closePath();
}
```

Rule: never use `ctx.roundRect()`. Always use `rr()`.

## Track Tiling

The track is finite but the world is infinite. The player can lap indefinitely. This is handled with modulo:

```ts
const wx = ((s.x % trackLen) + trackLen) % trackLen;
```

The double-modulo `((x % n) + n) % n` handles negative values. Plain `x % n` returns negative numbers for negative `x` in JavaScript. The double pattern always returns `[0, n)`.

The terrain is drawn at multiple offsets (`rep = -1, 0, 1, 2`) to ensure the seam is never visible as the camera scrolls.
