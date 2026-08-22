import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

async function openPalette(page) {
  await page.goto('/');
  await expect(page.locator('#section-title')).toHaveText('Recents');
}

test('search is unselected until keyboard navigation and Return copies', async ({ context, page }) => {
  await context.grantPermissions(['clipboard-read', 'clipboard-write']);
  await openPalette(page);
  const search = page.getByLabel('Search everything');
  await expect(page.locator('.row[data-active="true"]')).toHaveCount(0);
  await search.fill('happy');
  await expect(page.locator('#section-title')).toHaveText('Search results');
  await expect(page.locator('.row').first()).toContainText('Happy');
  await expect(page.locator('.row[data-active="true"]')).toHaveCount(0);
  await search.press('ArrowDown');
  await expect(page.locator('.row[data-active="true"]')).toContainText('Happy');
  await expect(page.locator('#selection-status')).toHaveText('Ready to copy Happy');
  await search.press('Enter');
  await expect(page.locator('#toast')).toContainText('Copied Happy');
});

test('Escape clears search and section shortcuts cycle predictably', async ({ page }) => {
  await openPalette(page);
  const search = page.getByLabel('Search everything');
  await search.fill('sparkles');
  await search.press('Escape');
  await expect(search).toHaveValue('');
  await search.press('Control+Tab');
  await expect(page.locator('#section-title')).toHaveText('Favorites');
  await page.keyboard.press('Meta+4');
  await expect(page.locator('#section-title')).toHaveText('Kaomoji');
  await page.keyboard.press('Meta+6');
  await expect(page.locator('#section-title')).toHaveText('Snippets');
  await expect(page.getByRole('button', { name: 'New snippet' })).toBeVisible();
});

test('favorite controls update the Favorites shelf', async ({ page }) => {
  await openPalette(page);
  const search = page.getByLabel('Search everything');
  await search.fill('wave');
  const row = page.locator('.row').filter({ hasText: 'Wave' }).first();
  await row.getByRole('button', { name: 'Add to favorites' }).click();
  await page.getByRole('button', { name: /Favorites, Command 2/ }).click();
  await expect(page.locator('.row').filter({ hasText: 'Wave' })).toHaveCount(1);
  await page.locator('.row').filter({ hasText: 'Wave' }).getByRole('button', { name: 'Remove from favorites' }).click();
  await expect(page.locator('.row').filter({ hasText: 'Wave' })).toHaveCount(0);
});

test('broad search is capped and the mobile page does not overflow', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openPalette(page);
  await page.getByLabel('Search everything').fill('a');
  await expect(page.locator('#result-count')).toHaveText('250+');
  const hasOverflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
  expect(hasOverflow).toBe(false);
});

test('clipboard denial keeps the preview usable and explains the failure', async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText: () => Promise.reject(new DOMException('Denied', 'NotAllowedError')) }
    });
  });
  await openPalette(page);
  const search = page.getByLabel('Search everything');
  await search.fill('happy');
  await search.press('ArrowDown');
  await search.press('Enter');
  await expect(page.locator('#toast')).toHaveText('Clipboard access is unavailable in this browser');
  await expect(search).toHaveValue('happy');
});

test('catalog load failure has a user-facing recovery state', async ({ page }) => {
  await page.route('**/catalog.json', route => route.fulfill({ status: 503, body: '' }));
  await page.goto('/');
  await expect(page.locator('.empty')).toContainText('Catalog failed to load');
  await expect(page.locator('.empty')).toContainText('Reload the page');
});

test('focus order and accessibility semantics are valid', async ({ page }) => {
  await openPalette(page);
  const search = page.getByLabel('Search everything');
  await expect(search).toBeFocused();
  await search.press('Tab');
  await expect(page.getByRole('button', { name: /Recents, Command 1/ })).toBeFocused();
  await expect(page.locator('button button')).toHaveCount(0);
  await expect(page.locator('[aria-selected]:not([role="option"]):not([role="tab"])')).toHaveCount(0);
  const accessibility = await new AxeBuilder({ page }).analyze();
  expect(accessibility.violations).toEqual([]);
});

test('light and dark system themes both resolve through design tokens', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light' });
  await openPalette(page);
  const light = await page.evaluate(() => ({
    scheme: getComputedStyle(document.documentElement).colorScheme,
    background: getComputedStyle(document.body).backgroundColor
  }));
  await page.emulateMedia({ colorScheme: 'dark' });
  const dark = await page.evaluate(() => ({
    scheme: getComputedStyle(document.documentElement).colorScheme,
    background: getComputedStyle(document.body).backgroundColor
  }));
  expect(light.scheme).toBe('light');
  expect(dark.scheme).toBe('dark');
  expect(dark.background).not.toBe(light.background);
});
