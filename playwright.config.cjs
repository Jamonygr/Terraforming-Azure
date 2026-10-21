const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({
  testDir: './tests/browser',
  fullyParallel: true,
  workers: 2,
  retries: process.env.CI ? 1 : 0,
  timeout: 30000,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: { browserName: 'chromium', baseURL: 'http://127.0.0.1:8766/Terraforming-Azure/', viewport: { width: 1280, height: 900 }, trace: 'retain-on-failure' },
  webServer: { command: 'node tools/serve_site.cjs', url: 'http://127.0.0.1:8766/Terraforming-Azure/', reuseExistingServer: false, timeout: 15000 }
});
