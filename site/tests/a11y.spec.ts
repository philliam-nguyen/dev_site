import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

for (const colorScheme of ['light', 'dark'] as const) {
  test(`no axe violations in ${colorScheme} mode`, async ({ page }) => {
    await page.emulateMedia({ colorScheme });
    await page.goto('/');
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });
}

test('the built page ships no JavaScript', async ({ page }) => {
  const scripts: string[] = [];
  page.on('response', r => {
    // .mjs counts, and a query string must not hide a .js
    if (/\.m?js(\?|$)/.test(r.url())) scripts.push(r.url());
  });
  await page.goto('/');

  const inline = await page.locator('script').count();
  // An on* attribute runs JavaScript without a <script> tag existing.
  const handlers = await page.evaluate(() =>
    [...document.querySelectorAll('*')]
      .flatMap(el => [...el.attributes])
      .filter(a => a.name.startsWith('on'))
      .map(a => a.name)
  );

  expect(scripts).toEqual([]);
  expect(inline).toBe(0);
  expect(handlers).toEqual([]);
});
