/**
 * Mesure des positions réelles des blocs dans la page — Vision v2.
 *
 * POURQUOI : les positions étaient jusqu'ici ESTIMÉES en Python (« environ 30
 * caractères par ligne, environ 52 px de haut par ligne »). Sur du contenu réel —
 * un diagramme, une définition longue — l'estimation se trompe et les blocs
 * SE CHEVAUCHENT à l'écran, et la caméra vise à côté.
 *
 * On laisse donc le navigateur placer les blocs naturellement (flux normal, aucun
 * positionnement absolu), puis on LUI DEMANDE où ils sont réellement. Les
 * mouvements de caméra sont ensuite calculés à partir de ces mesures.
 *
 * Usage: node measure_page.js <html_file>
 * Sortie: JSON [{id, top, height}, ...]
 */

const { chromium } = require('playwright');
const path = require('path');

const VIEWPORT_W = 1080;
const VIEWPORT_H = 1920;

async function measure(htmlPath) {
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--font-render-hinting=none'],
  });
  try {
    const page = await browser.newPage({
      viewport: { width: VIEWPORT_W, height: VIEWPORT_H },
      deviceScaleFactor: 1,
    });
    await page.goto('file://' + path.resolve(htmlPath), { waitUntil: 'networkidle' });
    // Les polices changent la hauteur du texte : on attend qu'elles soient prêtes.
    await page.evaluate(() => document.fonts.ready);

    const boxes = await page.evaluate(() => {
      const out = [];
      document.querySelectorAll('.blk').forEach((el) => {
        out.push({
          id: el.id,
          top: Math.round(el.offsetTop),
          height: Math.round(el.offsetHeight),
        });
      });
      const paper = document.getElementById('paper');
      return { boxes: out, docHeight: paper ? Math.round(paper.scrollHeight) : 0 };
    });

    console.log(JSON.stringify(boxes));
  } finally {
    await browser.close();
  }
}

if (require.main === module) {
  const file = process.argv[2];
  if (!file) {
    console.error('Usage: node measure_page.js <html_file>');
    process.exit(1);
  }
  measure(file).then(() => process.exit(0)).catch((e) => {
    console.error(JSON.stringify({ status: 'error', message: e.message }));
    process.exit(1);
  });
}

module.exports = { measure };
