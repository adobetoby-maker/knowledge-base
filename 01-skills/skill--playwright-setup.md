# Skill: Playwright E2E Test Setup

## Overview
Playwright E2E tests catch integration failures that unit tests miss: auth flows, multi-step forms, real network calls. The most expensive mistakes are slow tests (one login per test instead of per run) and flaky tests (no retry strategy, hardcoded waits). Getting the setup right makes tests fast enough to run in CI without becoming a liability.

## Implementation

### 1. Configuration
```ts
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,   // fail CI if .only left in
  retries: process.env.CI ? 2 : 0, // retry flaky tests in CI only
  workers: process.env.CI ? 4 : undefined,

  reporter: [
    process.env.CI ? ['github'] : ['list'],  // github reporter annotates PRs
    ['html', { open: 'never' }],
  ],

  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
    trace: 'on-first-retry',       // capture trace on first failure only
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    // Setup project runs once before all tests
    { name: 'setup', testMatch: /global\.setup\.ts/ },
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
      dependencies: ['setup'],
    },
    {
      name: 'mobile',
      use: { ...devices['iPhone 13'] },
      dependencies: ['setup'],
    },
  ],

  // Start dev server automatically in local development
  webServer: process.env.CI ? undefined : {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: true,
  },
});
```

### 2. Global setup — one login for all tests
```ts
// e2e/global.setup.ts
import { test as setup, expect } from '@playwright/test';
import path from 'path';

// Share auth state across all tests — login once, not once per test
const authFile = path.join(__dirname, '.auth/user.json');
const adminAuthFile = path.join(__dirname, '.auth/admin.json');

setup('authenticate as user', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill(process.env.TEST_USER_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');  // wait for redirect, not arbitrary timeout
  await page.context().storageState({ path: authFile });
});

setup('authenticate as admin', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('admin@example.com');
  await page.getByLabel('Password').fill(process.env.TEST_ADMIN_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/admin');
  await page.context().storageState({ path: adminAuthFile });
});
```

### 3. Test fixtures for auth states
```ts
// e2e/fixtures.ts
import { test as base } from '@playwright/test';
import path from 'path';

type Fixtures = {
  userPage: Page;
  adminPage: Page;
};

export const test = base.extend<Fixtures>({
  userPage: async ({ browser }, use) => {
    const ctx = await browser.newContext({
      storageState: path.join(__dirname, '.auth/user.json'),
    });
    await use(await ctx.newPage());
    await ctx.close();
  },
  adminPage: async ({ browser }, use) => {
    const ctx = await browser.newContext({
      storageState: path.join(__dirname, '.auth/admin.json'),
    });
    await use(await ctx.newPage());
    await ctx.close();
  },
});

export { expect } from '@playwright/test';
```

### 4. Writing tests
```ts
// e2e/orders.test.ts
import { test, expect } from './fixtures';

test('user can create an order', async ({ userPage: page }) => {
  await page.goto('/orders/new');
  
  // Prefer role-based selectors over CSS — resilient to UI changes
  await page.getByRole('combobox', { name: 'Product' }).selectOption('Widget Pro');
  await page.getByLabel('Quantity').fill('2');
  await page.getByRole('button', { name: 'Place Order' }).click();
  
  // Wait for navigation, not arbitrary timeout
  await page.waitForURL(/\/orders\/[a-z0-9-]+/);
  await expect(page.getByRole('heading', { name: 'Order Confirmation' })).toBeVisible();
});

test('admin can cancel any order', async ({ adminPage: page }) => {
  await page.goto('/admin/orders');
  await page.getByRole('row', { name: /ORD-/ }).first().getByRole('button', { name: 'Cancel' }).click();
  await page.getByRole('button', { name: 'Confirm' }).click();
  await expect(page.getByText('Order cancelled')).toBeVisible();
});
```

### 5. CI with sharding
```yaml
# .github/workflows/e2e.yml
- name: Run E2E tests
  run: npx playwright test --shard=${{ matrix.shard }}/4
  env:
    CI: true
    BASE_URL: ${{ env.PREVIEW_URL }}

strategy:
  matrix:
    shard: [1, 2, 3, 4]
```

## Key Rules
- **One login per test run, not one per test** — per-test login multiplies test time by 10x. Use `storageState` shared via global setup.
- **Use `waitForURL` and `waitForSelector` not `page.waitForTimeout`** — arbitrary waits make tests slow and still flaky.
- **Prefer ARIA roles** (`getByRole`, `getByLabel`) over CSS selectors — more resilient to layout changes.
- Set `retries: 2` in CI only — local retries hide test bugs.
- Add `.auth/` to `.gitignore` — storage state contains auth tokens.
- `trace: 'on-first-retry'` captures the full browser trace on failure without storing traces for every passing test.
- Run with `--shard=1/4` in CI to parallelize across 4 workers — cut test time by 75%.
