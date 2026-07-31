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
    if (r.url().endsWith('.js')) scripts.push(r.url());
  });
  await page.goto('/');
  const inline = await page.locator('script').count();

  expect(scripts).toEqual([]);
  expect(inline).toBe(0);
});
