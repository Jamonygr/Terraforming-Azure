const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;
const fs = require('node:fs');
const path = require('node:path');
const quizzes = JSON.parse(fs.readFileSync(path.join(__dirname, '../../site/web/quizzes.json')));
const first = quizzes['TFA-001'][0];
const question = page => page.locator(`[data-question="${first.id}"]`);
const lesson = page => page.getByLabel('I understand the lesson', { exact: true });
const row = page => page.locator('.progress-row[data-lab="TFA-001"]');
const BASE = 'http://127.0.0.1:8766/Terraforming-Azure/';
test.beforeEach(async ({ context, page }) => {
  // Tests stay on the local website. External badge/API requests are unnecessary.
  await context.route('**/*', route => new URL(route.request().url()).hostname === '127.0.0.1' ? route.continue() : route.abort());
  page.on('pageerror', error => { throw error; });
});
async function checkAnswer(page, id = first.answer) {
  await question(page).locator(`input[value="${id}"]`).check();
  await question(page).getByRole('button', { name: 'Check answer', exact: true }).click();
}
test('direct project-prefix lesson restores the latest checked answer and flags', async ({ page }) => {
  await page.goto('labs/TFA-001/'); await expect(page.locator('.quiz-question')).toHaveCount(5);
  await checkAnswer(page); await expect(question(page).locator('.quiz-feedback')).toContainText('Correct.');
  await lesson(page).check(); await page.reload();
  await expect(lesson(page)).toBeChecked(); await expect(question(page).locator(`input[value="${first.answer}"]`)).toBeChecked();
  await expect(question(page).locator('.quiz-feedback')).toContainText('Correct.');
  const wrong = first.options.find(o => o.id !== first.answer).id;
  await checkAnswer(page, wrong); await expect(question(page).locator('.quiz-feedback')).toContainText('Try again.');
  await page.goto('progress/'); await expect(row(page)).toContainText('Quiz: 0/5');
});
test('checking without a selection focuses an answer and announces guidance', async ({ page }) => {
  await page.goto('labs/TFA-001/'); await question(page).getByRole('button', { name: 'Check answer' }).click();
  await expect(question(page).locator('.quiz-feedback')).toContainText('Choose an answer first.');
  await expect(question(page).getByRole('radio').first()).toBeFocused();
});
test('quiz controls work by keyboard and reset clears checked and draft choices', async ({ page }) => {
  await page.goto('labs/TFA-001/');
  const radios = question(page).getByRole('radio'); await radios.first().focus(); await page.keyboard.press('ArrowDown');
  await expect(radios.nth(1)).toBeChecked(); await page.keyboard.press('Tab');
  await expect(question(page).getByRole('button', { name: 'Check answer' })).toBeFocused(); await page.keyboard.press('Enter');
  await expect(question(page).locator('.quiz-feedback')).toBeVisible();
  await page.locator('.quiz-question').nth(1).getByRole('radio').first().check();
  await page.getByRole('button', { name: 'Reset this quiz' }).focus(); await page.keyboard.press('Enter');
  await expect(page.locator('.quiz-question input:checked')).toHaveCount(0);
  await expect(page.locator('.quiz-feedback:visible')).toHaveCount(0);
});
test('two tabs merge fields, synchronize and respect reset without resurrection', async ({ context, page }) => {
  const second = await context.newPage();
  await page.goto('labs/TFA-001/'); await second.goto(BASE + 'labs/TFA-002/');
  await lesson(page).check(); await lesson(second).check();
  await page.goto('progress/'); await expect(page.getByText('2 of 40 lessons marked understood.', { exact: true })).toBeVisible();
  page.once('dialog', dialog => dialog.accept()); await page.getByRole('button', { name: 'Reset this browser’s progress' }).click();
  await expect(lesson(second)).not.toBeChecked(); await second.getByLabel('I completed the exercise', { exact: true }).check();
  await expect(page.getByText('0 of 40 lessons marked understood.', { exact: true })).toBeVisible();
  await expect(page.locator('.progress-row[data-lab="TFA-002"]')).toContainText('Exercise: done');
});
test('malformed nested legacy progress is recoverable through real answer clicks', async ({ page }) => {
  await page.addInitScript(() => { if (!sessionStorage.getItem('seeded')) { localStorage.setItem('terraforming-azure-progress-v1', JSON.stringify({ 'TFA-001': { lesson: true, answers: 'bad' } })); sessionStorage.setItem('seeded', '1'); } });
  await page.goto('labs/TFA-001/'); await expect(lesson(page)).toBeChecked();
  await checkAnswer(page); await expect(question(page).locator('.quiz-feedback')).toContainText('Correct.');
  await page.reload(); await expect(question(page).locator(`input[value="${first.answer}"]`)).toBeChecked();
});
test('unavailable storage announces session-only mode and exports from the lesson', async ({ page }) => {
  await page.addInitScript(() => Object.defineProperty(window, 'localStorage', { get() { throw new DOMException('Denied', 'SecurityError'); } }));
  await page.goto('labs/TFA-001/'); await expect(page.getByText(/Session only: this browser cannot save progress/)).toBeVisible();
  await lesson(page).check(); await checkAnswer(page);
  const pending = page.waitForEvent('download'); await page.getByRole('button', { name: 'Export session progress' }).click();
  const downloaded = await pending; const data = JSON.parse(fs.readFileSync(await downloaded.path(), 'utf8'));
  expect(data.labs['TFA-001'].lesson).toBe(true); expect(data.labs['TFA-001'].answers[first.id].choice).toBe(first.answer);
});
test('progress export, preview, merge/replace import and invalid file rejection', async ({ page, browser }) => {
  await page.goto('labs/TFA-001/'); await lesson(page).check(); await checkAnswer(page);
  await page.goto('progress/'); const pending = page.waitForEvent('download'); await page.getByRole('button', { name: 'Export progress', exact: true }).click();
  const downloaded = await pending; const file = await downloaded.path();
  const fresh = await browser.newContext(); const restored = await fresh.newPage();
  try {
    await fresh.route('**/*', route => new URL(route.request().url()).hostname === '127.0.0.1' ? route.continue() : route.abort());
    await restored.goto(BASE + 'progress/'); await expect(restored.locator('#progress-file')).toBeEnabled();
    await restored.locator('#progress-file').setInputFiles(file);
    await expect(restored.getByText(/Preview: 1 lessons understood/)).toBeVisible(); await expect(row(restored)).toContainText('Lesson: pending');
    await restored.getByRole('button', { name: 'Import previewed progress' }).click();
    await expect(row(restored)).toContainText('Lesson: done'); await expect(row(restored)).toContainText('Quiz: 1/5');
    await restored.locator('#progress-file').setInputFiles({ name: 'bad.json', mimeType: 'application/json', buffer: Buffer.from('{broken') });
    await expect(restored.getByText('This file is not valid JSON. Your progress has not changed.')).toBeVisible(); await expect(row(restored)).toContainText('Lesson: done');
    await restored.locator('#progress-file').setInputFiles({ name: 'empty.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify({ schemaVersion: 2, course: 'terraforming-azure', labs: {} })) });
    await restored.getByLabel('Import method').selectOption('replace'); await restored.getByRole('button', { name: 'Import previewed progress' }).click();
    await expect(row(restored)).toContainText('Lesson: pending');
  } finally { await fresh.close(); }
});
test('quiz fetch failure does not hide progress; retry recovers questions', async ({ page }) => {
  await page.route('**/web/quizzes.json', route => route.abort()); await page.goto('progress/');
  await expect(page.locator('.progress-row')).toHaveCount(40); await expect(page.getByText('Could not load questions. Your saved progress is safe.')).toBeVisible();
  await expect(page.locator('#progress-file')).toBeDisabled();
  await page.unroute('**/web/quizzes.json'); await page.getByRole('button', { name: 'Retry loading' }).click();
  await expect(page.locator('#progress-file')).toBeEnabled(); await expect(row(page)).toContainText('Quiz: 0/5');
});
test('lesson quizzes and completion do not depend on the catalog fetch', async ({ page }) => {
  await page.route('**/web/catalog.json', route => route.abort()); await page.goto('labs/TFA-001/');
  await checkAnswer(page); await expect(question(page).locator('.quiz-feedback')).toContainText('Correct.'); await lesson(page).check();
});
test('practice selection, theme memory and search use the project path', async ({ page }) => {
  await page.goto('practice/'); await page.getByLabel('Lab', { exact: true }).selectOption('TFA-040');
  await expect(page.locator('#practice-quiz')).toHaveAttribute('data-lab', 'TFA-040'); await expect(page.locator('.quiz-question')).toHaveCount(5);
  await page.locator('label[title="Use light theme"]').click(); await expect(page.locator('body')).toHaveAttribute('data-md-color-scheme', 'default');
  await page.reload(); await expect(page.locator('body')).toHaveAttribute('data-md-color-scheme', 'default');
  await page.locator('input[data-md-component="search-query"]').fill('private endpoint');
  await expect(page.locator('.md-search-result__link').first()).toBeVisible();
  expect(await page.locator('.md-search-result__link').first().getAttribute('href')).toContain('/Terraforming-Azure/');
});
test('homepage reserves optimized image space and supplies social metadata', async ({ page }) => {
  await page.goto('./'); const cover = page.locator('article img[src$="terraforming-azure-cover.webp"]');
  await expect(cover).toBeVisible(); expect(Number(await cover.getAttribute('width'))).toBeGreaterThan(0); expect(Number(await cover.getAttribute('height'))).toBeGreaterThan(0);
  expect((await page.getByRole('img', { name: 'Course quality', exact: true }).boundingBox()).width).toBeLessThan(300);
  expect(await page.locator('meta[property="og:image"]').getAttribute('content')).toContain('/Terraforming-Azure/assets/');
});
test('mobile reading and full-size diagrams remain reachable with keyboard', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 }); await page.goto('guides/architecture/');
  const link = page.getByRole('link', { name: /Open full-size diagram:/ }).first(); await expect(link).toBeVisible(); await link.focus(); await expect(link).toBeFocused();
  const popupEvent = page.waitForEvent('popup'); await page.keyboard.press('Enter'); const popup = await popupEvent;
  await popup.waitForLoadState(); expect(popup.url()).toContain('capstone-topology.svg'); await popup.close();
  await page.goto('labs/TFA-001/'); await expect(page.locator('.quiz-question')).toHaveCount(5);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});
for (const route of ['./', 'labs/TFA-001/', 'practice/', 'progress/', 'guides/architecture/', 'phases/phase-1/']) {
  for (const theme of ['slate', 'default']) test(`accessibility ${route} ${theme}`, async ({ page }) => {
    await page.goto(route);
    if (route.includes('labs/') || route === 'practice/') await expect(page.locator('.quiz-question')).toHaveCount(5);
    if (route === 'progress/') await expect(page.locator('.progress-row')).toHaveCount(40);
    if (theme === 'default') await page.locator('label[title="Use light theme"]').click();
    const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa']).analyze();
    expect(results.violations.map(v => ({ id: v.id, targets: v.nodes.map(n => n.target) }))).toEqual([]);
  });
}
