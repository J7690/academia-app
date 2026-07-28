/** Image fixe d'une page bâtie à un instant donné (seek CSS + screenshot). */
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const [htmlFile, outPng, seekMsRaw] = process.argv.slice(2);
  const seekMs = parseInt(seekMsRaw || '0', 10);
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  await page.goto('file://' + path.resolve(htmlFile), { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate((ms) => {
    document.body.classList.add('recording');
    for (const a of document.getAnimations()) { a.pause(); a.currentTime = ms; }
  }, seekMs);
  await page.screenshot({ path: outPng });
  await browser.close();
  console.log('ok', outPng);
})();
