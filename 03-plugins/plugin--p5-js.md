# plugin--p5-js — Creative Coding / Canvas

## What It Is
p5.js is a JavaScript library for creative coding built around a `setup()` / `draw()` lifecycle. It wraps the Canvas 2D API with a higher-level API for drawing, animation, and interaction. In React, it requires a wrapper component because p5 manages its own DOM node.

## React Integration — Instance Mode

Never use global mode (`new p5()` with global function names) in React. Global mode pollutes the window object and breaks with multiple sketches. Always use instance mode:

```tsx
import { useEffect, useRef } from 'react';
import p5 from 'p5';

interface SketchProps {
  sketch: (p: p5) => void;
}

export function Sketch({ sketch }: SketchProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!containerRef.current) return;
    const instance = new p5(sketch, containerRef.current);
    return () => instance.remove();  // critical cleanup
  }, [sketch]);

  return <div ref={containerRef} />;
}
```

**`p.remove()` is non-negotiable.** Without it, the canvas stays in the DOM and the draw loop keeps running after the component unmounts. This causes memory leaks and accumulates event listeners.

## setup() + draw() Lifecycle

```ts
const sketch = (p: p5) => {
  p.setup = () => {
    p.createCanvas(600, 400);
    p.background(0);
    p.frameRate(60);
  };

  p.draw = () => {
    // Called every frame — keep it fast
    p.background(0, 20);  // semi-transparent for trail effect
    p.fill(255);
    p.ellipse(p.mouseX, p.mouseY, 20, 20);
  };
};
```

`setup()` runs once. `draw()` runs in a loop. Expensive operations (loading images, building data structures) belong in `setup()` or `preload()`, not `draw()`.

## Communicating React State to p5

p5 sketches are closures — they capture values at creation. To pass live React state into a running sketch, use a ref:

```tsx
function AnimatedSketch({ color }: { color: string }) {
  const colorRef = useRef(color);

  // Keep ref in sync with prop without recreating the sketch
  useEffect(() => {
    colorRef.current = color;
  }, [color]);

  const sketch = useCallback((p: p5) => {
    p.setup = () => p.createCanvas(400, 400);
    p.draw = () => {
      p.background(220);
      p.fill(colorRef.current);  // reads current value each frame
      p.rect(100, 100, 200, 200);
    };
  }, []);  // stable reference — sketch never recreates

  return <Sketch sketch={sketch} />;
}
```

**Don't put React state directly in the sketch closure.** State changes cause re-renders, which would recreate the sketch on every change, resetting the canvas. The ref pattern decouples React's render cycle from p5's draw loop.

## preload() for Assets

```ts
const sketch = (p: p5) => {
  let img: p5.Image;

  p.preload = () => {
    img = p.loadImage('/assets/texture.png');
  };

  p.setup = () => p.createCanvas(600, 600);

  p.draw = () => {
    p.image(img, 0, 0);
  };
};
```

`preload()` blocks `setup()` until all loads complete. Use it instead of fetching in `setup()` and checking a loaded flag each frame.

## prefers-reduced-motion Handling

Users who have enabled reduced motion should not see animations. Respect this:

```ts
const sketch = (p: p5) => {
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  p.setup = () => {
    p.createCanvas(400, 400);
    if (reducedMotion) p.noLoop();  // draw once, stop
  };

  p.draw = () => {
    // animation logic
  };
};
```

`p.noLoop()` stops the draw loop after one frame. The canvas renders its initial state but doesn't animate. This is the minimum viable accessibility accommodation.

## Performance Tips

- Call `p.noLoop()` and use `p.redraw()` for sketches that only need to update on events, not continuously.
- Avoid creating new objects inside `draw()` — allocate vectors and arrays in `setup()` and reuse them.
- Use `p5.Graphics` (offscreen buffers) for complex static elements rendered once.

## Key Rules
- Always use instance mode in React — never global mode.
- Always call `p.remove()` in the `useEffect` cleanup to prevent memory leaks and stale loops.
- Pass live React state into p5 via refs, not closure variables — avoids sketch recreation on every state change.
- Use `preload()` for assets, not manual fetch in `setup()`.
- Check `prefers-reduced-motion` and call `p.noLoop()` when it's set.
- Keep `draw()` lean — no expensive allocations, no network calls.
