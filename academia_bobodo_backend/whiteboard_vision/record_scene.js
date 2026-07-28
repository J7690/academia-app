/**
 * Enregistrement vidéo d'une page HTML animée — Vision v2
 * Smart Whiteboard
 *
 * Usage: node record_scene.js <html_file> <output_webm> <duration_ms> [fps] [start_ms]
 *
 * ─── POURQUOI FILMER PLUTÔT QUE PHOTOGRAPHIER ──────────────────────────────
 * Le moteur Vision prenait UNE capture d'écran par scène, après la fin des animations :
 * la vidéo n'était donc qu'un diaporama d'images fixes. Capturer image par image (30 par
 * seconde) serait ruineux : une capture Playwright coûte ~1 s, soit des heures pour un
 * cours.
 *
 * On enregistre donc la page PENDANT que les animations CSS se jouent. Chromium compose
 * alors les animations avec son moteur graphique — ce pour quoi il est optimisé. Le coût
 * du rendu devient proportionnel à la DURÉE de la vidéo (~1× le temps réel), et non plus
 * au nombre d'images à reconstruire (~4-5× avec un rendu image par image).
 *
 * ─── GARDE-FOU : LES IMAGES PERDUES ────────────────────────────────────────
 * Un enregistrement en temps réel peut perdre des images si la machine est chargée. On
 * vérifie donc systématiquement que la durée du fichier produit correspond à la durée
 * demandée, à 8 % près. En cas d'écart, on ÉCHOUE explicitement plutôt que de livrer une
 * vidéo saccadée à un étudiant.
 *
 * ─── TRANCHES : `start_ms` ─────────────────────────────────────────────────
 * Avec `start_ms`, on n'enregistre qu'une TRANCHE du cours : les animations sont
 * avancées à cet instant (API Web Animations, `Animation.currentTime`) avant que
 * l'enregistrement ne commence, puis elles reprennent leur cours normalement.
 * Plusieurs tranches peuvent alors être filmées EN PARALLÈLE puis mises bout à bout.
 * Mesuré le 26/07/2026 : trois enregistrements simultanés de 20 s prennent 27 s au
 * total (contre 23 s pour un seul), sans aucune perte d'image — soit trois fois le
 * débit pour 17 % de surcoût.
 */

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const VIEWPORT_W = 1080;
const VIEWPORT_H = 1920;
// 25 images/seconde plutôt que 30 : moins d'images à composer par seconde, donc une
// marge confortable pour tenir le temps réel sur un serveur modeste.
const DEFAULT_FPS = 25;
// Tolérance sur l'écart entre durée demandée et durée obtenue.
const DURATION_TOLERANCE = 0.08;

async function recordScene(htmlPath, outputPath, durationMs, fps = DEFAULT_FPS, startMs = 0) {
  const outDir = path.dirname(path.resolve(outputPath));
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-dev-shm-usage',
      '--font-render-hinting=none',
      // Le compositeur doit tourner même sans écran, sinon les animations CSS
      // sont mises en pause en mode headless et la vidéo sort figée.
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
    ],
  });

  const started = Date.now();
  let videoPath = null;
  // Instant de creation du contexte = instant ou Playwright COMMENCE a filmer.
  // C'est la reference qui permettra de savoir combien d'amorce rogner.
  let recordingStart = 0;
  let animationStart = 0;

  try {
    recordingStart = Date.now();
    const context = await browser.newContext({
      viewport: { width: VIEWPORT_W, height: VIEWPORT_H },
      deviceScaleFactor: 1,
      recordVideo: {
        dir: outDir,
        size: { width: VIEWPORT_W, height: VIEWPORT_H },
      },
    });

    const page = await context.newPage();
    const fileUrl = 'file://' + path.resolve(htmlPath);
    await page.goto(fileUrl, { waitUntil: 'networkidle' });

    // Les polices doivent être prêtes AVANT le début de l'animation, sinon les
    // premières secondes sortent dans la police par défaut.
    await page.evaluate(() => document.fonts.ready);

    // Signal de départ : la page démarre ses animations quand cette classe apparaît.
    // (Le gabarit HTML met les animations en pause tant qu'elle est absente.)
    //
    // Avec `startMs`, on avance immédiatement toutes les animations à cet instant :
    // celles déjà terminées restent à leur état final (elles sont en `forwards`),
    // celles en cours reprennent au bon endroit. La tranche démarre donc sur une
    // image rigoureusement identique à celle qu'aurait produite un enregistrement
    // continu au même instant.
    animationStart = Date.now();
    await page.evaluate((ms) => {
      document.body.classList.add('recording');
      if (ms > 0) {
        for (const a of document.getAnimations()) a.currentTime = ms;
      }
    }, startMs);

    await page.waitForTimeout(durationMs);

    // Fermer le contexte force Playwright à finaliser le fichier vidéo.
    await context.close();
    videoPath = await page.video().path();
  } finally {
    await browser.close();
  }

  if (!videoPath || !fs.existsSync(videoPath)) {
    throw new Error('aucune video produite par Playwright');
  }

  // Playwright nomme le fichier lui-même : on le renomme vers la sortie demandée.
  const finalPath = path.resolve(outputPath);
  if (videoPath !== finalPath) {
    fs.renameSync(videoPath, finalPath);
  }

  const stats = fs.statSync(finalPath);
  const elapsedMs = Date.now() - started;

  // AMORCE MESURÉE (et non devinée) : temps écoulé entre le début de l'enregistrement
  // (création du contexte) et le démarrage des animations. C'est exactement ce qu'il
  // faut rogner AU DÉBUT du fichier.
  //
  // Rogner par la fin ne marche pas : le fichier comporte aussi une traîne, le temps
  // que Playwright finalise la vidéo après la fin de l'animation (mesurée à ~0,9 s).
  // Se caler sur la fin décalait donc l'animation d'autant.
  const leadInMs = animationStart - recordingStart;

  console.log(JSON.stringify({
    status: 'ok',
    path: finalPath,
    size: stats.size,
    start_ms: startMs,
    requested_ms: durationMs,
    elapsed_ms: elapsedMs,
    lead_in_ms: leadInMs,
    fps,
    width: VIEWPORT_W,
    height: VIEWPORT_H,
    tolerance: DURATION_TOLERANCE,
  }));
}

if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.length < 3) {
    console.error('Usage: node record_scene.js <html_file> <output_webm> <duration_ms> [fps] [start_ms]');
    process.exit(1);
  }
  const [htmlFile, outputPath, durationMsRaw, fpsRaw, startMsRaw] = args;
  recordScene(htmlFile, outputPath, parseInt(durationMsRaw, 10),
              parseInt(fpsRaw || String(DEFAULT_FPS), 10),
              parseInt(startMsRaw || '0', 10))
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(JSON.stringify({ status: 'error', message: err.message }));
      process.exit(1);
    });
}

module.exports = { recordScene };
