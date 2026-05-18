# Skill: Visual Regression Testing

## Overview
Visual regression tests catch unintended UI changes — a CSS change that clips text, a z-index issue hiding a button, a font fallback that shifts layout. They complement functional tests which only verify behavior. The discipline that prevents snapshot tests from becoming a maintenance burden: never auto-update snapshots, always review diffs before committing, test at the component level not full-page when possible.

## Implementation

### 1. Playwright visual comparison setup
```ts
// playwright.config.ts
export default defineConfig({
  // Snapshot comparison settings
  expect: {
    toMatchSnapshot: {
      threshold: 0.1,      // allow 0.1% pixel difference (anti-aliasing)
      maxDiffPixels: 50,   // OR max 50 pixels different (whichever is more permissive)
    },
  },
  // Store snapshots alongside tests
  snapshotDir: './e2e/snapshots',
  snapshotPathTemplate: '{snapshotDir}/{testFilePath}/{arg}-{projectName}{ext}',
});
```

### 2. Component-level visual tests (preferred)
```ts
// e2e/visual/button.test.ts
import { test, expect } from '@playwright/test';

test.describe('Button component', () => {
  test('primary variant', async ({ page }) => {
    // Isolate component in a minimal page — not the full app
    await page.goto('/storybook/button--primary');
    const button = page.getByRole('button', { name: 'Submit' });
    
    // Wait for fonts + animations to settle
    await page.waitForLoadState('networkidle');
    
    await expect(button).toMatchSnapshot('button-primary.png');
  });

  test('disabled state', async ({ page }) => {
    await page.goto('/storybook/button--disabled');
    await expect(page.getByRole('button')).toMatchSnapshot('button-disabled.png');
  });

  test('loading state', async ({ page }) => {
    await page.goto('/storybook/button--loading');
    // Wait for spinner animation to reach a stable frame
    await page.waitForSelector('.spinner');
    // Mask animation so comparison is stable
    await expect(page.locator('.btn-wrapper')).toMatchSnapshot('button-loading.png', {
      mask: [page.locator('.spinner')],  // mask animated element
    });
  });
});
```

### 3. Full-page tests for critical pages
```ts
test('homepage at desktop', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  
  // Hide dynamic content that changes every test run
  await page.addStyleTag({
    content: `
      [data-testid="user-avatar"] { visibility: hidden; }
      [data-testid="timestamp"] { visibility: hidden; }
    `,
  });
  
  await expect(page).toMatchSnapshot('homepage-desktop.png', {
    fullPage: true,
  });
});
```

### 4. CI configuration — fail on any diff
```yaml
# .github/workflows/visual.yml
- name: Run visual regression tests
  run: npx playwright test e2e/visual/

- name: Upload diff artifacts on failure
  if: failure()
  uses: actions/upload-artifact@v3
  with:
    name: visual-diffs
    path: test-results/
    retention-days: 7
```

### 5. Updating snapshots (deliberate, not automatic)
```bash
# NEVER update snapshots in CI automatically
# ALWAYS update locally, review the diff, then commit

# Update specific snapshot
npx playwright test --update-snapshots e2e/visual/button.test.ts

# Review what changed before committing
git diff --stat e2e/snapshots/

# Then commit with explicit message explaining the change
git add e2e/snapshots/
git commit -m "visual: update button snapshots for new border-radius"
```

### 6. Storybook as test subjects
```ts
// Use Storybook stories as canonical component test pages
// This forces component isolation and documents component states
// stories/Button.stories.ts defines states; visual tests screenshot each story

// scripts/test-stories.ts — screenshot every story automatically
import { getAllStories } from './storybook-utils';

for (const story of await getAllStories()) {
  test(`${story.title} - ${story.name}`, async ({ page }) => {
    await page.goto(story.url);
    await expect(page.locator('#storybook-root')).toMatchSnapshot(
      `${story.id}.png`
    );
  });
}
```

## Key Rules
- **Never auto-update snapshots in CI** — automation defeats the purpose; a bot committed diff is a hidden regression.
- **Fail on diff > 0.1%** — small threshold catches real regressions without false positives from anti-aliasing.
- Mask dynamic content (timestamps, avatars, animated spinners) — tests that fail on content change are noise, not signal.
- Test at component level first — full-page snapshots are fragile; a header change breaks every full-page test.
- `waitForLoadState('networkidle')` before snapping — fonts and images still loading cause non-deterministic diffs.
- Store snapshots in git — they are the ground truth and must be reviewable like code in PRs.
- Full-page vs component tradeoff: full-page tests catch integration layout issues; component tests are faster and more stable for isolated UI.
