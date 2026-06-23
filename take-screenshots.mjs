import { chromium } from '@playwright/test';
import { mkdirSync } from 'fs';

const OUT = 'docs/screenshots';
mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({ viewport: { width: 430, height: 932 } });
const page = await ctx.newPage();

await page.goto('http://localhost:4173/', { waitUntil: 'networkidle', timeout: 30000 });
// Flutter web needs time to initialise
await page.waitForTimeout(5000);

const W = 430, H = 932;

async function shot(label) {
  await page.waitForTimeout(1200);
  await page.screenshot({ path: `${OUT}/${label}.png`, fullPage: false });
}

async function clickPanel(x, y, label) {
  await page.mouse.click(x, y);
  await shot(label);
}

// 1. Discover (default active)
await shot('01-discover');

// 2. Podcasts — second panel in the spiral (right strip)
await clickPanel(W * 0.85, H * 0.25, '02-podcasts');

// 3. Library — third panel
await clickPanel(W * 0.85, H * 0.55, '03-library');

// 4. Settings — fourth panel (smaller)
await clickPanel(W * 0.85, H * 0.75, '04-settings');

// 5. Local — fifth panel (tiny)
await clickPanel(W * 0.90, H * 0.85, '05-local');

// 6. Account — sixth panel (tiny)
await clickPanel(W * 0.92, H * 0.90, '06-account');

// Go back to discover
await page.mouse.click(W * 0.30, H * 0.50);
await shot('07-discover-bento');

await browser.close();
console.log('Screenshots saved to', OUT);
