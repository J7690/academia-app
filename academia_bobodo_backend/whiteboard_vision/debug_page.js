/** Débogage : état des animations d'une page bâtie après seek. */
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const [htmlFile, seekMsRaw] = process.argv.slice(2);
  const seekMs = parseInt(seekMsRaw || '5000', 10);
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  page.on('console', (m) => console.log('[console]', m.text()));
  page.on('pageerror', (e) => console.log('[pageerror]', e.message));
  await page.goto('file://' + path.resolve(htmlFile), { waitUntil: 'networkidle' });
  const report = await page.evaluate((ms) => {
    document.body.classList.add('recording');
    const anims = document.getAnimations();
    for (const a of anims) { a.pause(); a.currentTime = ms; }
    const probe = (sel) => {
      const el = document.querySelector(sel);
      if (!el) return 'ABSENT';
      const cs = getComputedStyle(el);
      return `opacity=${cs.opacity} visibility=${cs.visibility} anim=${cs.animationName} delay=${cs.animationDelay}`;
    };
    return {
      animCount: anims.length,
      intro: probe('#intro'),
      ltr: probe('.ltr'),
      firstWord: probe('.w'),
      kw: probe('.w.kw'),
      chap: probe('.chap'),
      prog: probe('#prog i'),
      sheetRules: (() => {
        try { return document.styleSheets[document.styleSheets.length - 1].cssRules.length; }
        catch (e) { return 'ERR ' + e.message; }
      })(),
    };
  }, seekMs);
  console.log(JSON.stringify(report, null, 1));
  await browser.close();
})();
