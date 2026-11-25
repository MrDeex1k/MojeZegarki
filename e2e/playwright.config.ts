import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/web',
  retries: 0,
  reporter: 'list',
  use: {
    browserName: 'chromium',
    isolation: 'strict',
    waitForAnimations: true,
    failFastWhenIdle: false,
    trace: 'retain-on-failure',
  },
});
