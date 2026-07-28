/**
 * PROTOTYPE — Capture déterministe (temps virtuel) d'une page HTML animée.
 * Smart Whiteboard — étape 2c-2 (26/07/2026). NE REMPLACE PAS record_scene.js.
 *
 * Usage: node proto_capture.js <html_file> <output_mp4> <duration_ms> [fps]
 *
 * ─── PRINCIPE ───────────────────────────────────────────────────────────────
 * L'enregistrement actuel filme le navigateur en TEMPS RÉEL : 137 s de vidéo
 * coûtent 137 s incompressibles, plus l'encodage. Ici, on ment au navigateur
 * sur l'heure qu'il est :
 *   1. toutes les animations CSS de la page sont mises en PAUSE ;
 *   2. pour chaque image, on les avance à t = n/fps (Web Animations API,
 *      `Animation.currentTime` — la technique employée par le moteur vidéo de
 *      Replit pour synchroniser les animations CSS, cf. « seekCSSAnimations ») ;
 *   3. on capture l'image (CDP Page.captureScreenshot) et on l'envoie à ffmpeg.
 * Le coût devient proportionnel à la puissance CPU, plus à la durée. Chaque
 * image est EXACTE : plus d'images perdues sous charge, plus de filé, sortie
 * identique d'un rendu à l'autre.
 */

const { chromium } = require('playwright');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const VIEWPORT_W = 1080;
const VIEWPORT_H = 1920;
const DEFAULT_FPS = 25;
// Qualité JPEG des images intermédiaires : 80 est indiscernable après x264 crf 21,
// et deux à trois fois plus rapide à produire que le PNG.
const JPEG_QUALITY = 80;

async function captureDeterministic(htmlPath, outputPath, durationMs, fps = DEFAULT_FPS) {
  const outDir = path.dirname(path.resolve(outputPath));
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-dev-shm-usage',
      '--font-render-hinting=none',
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
      // La capture ne doit pas être cadencée par le VSync : sans ce drapeau,
      // chaque screenshot attend le tick 60 Hz du compositeur (~16 ms perdus).
      '--disable-frame-rate-limit',
    ],
  });

  const started = Date.now();
  const totalFrames = Math.ceil((durationMs / 1000) * fps);

  // ffmpeg encode au fil de l'eau : pas de milliers de fichiers temporaires.
  const ffmpeg = spawn('ffmpeg', [
    '-y', '-v', 'error',
    '-f', 'image2pipe', '-framerate', String(fps), '-i', 'pipe:0',
    '-c:v', 'libx264', '-profile:v', 'main', '-level:v', '4.0',
    '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-crf', '21',
    '-r', String(fps), '-movflags', '+faststart', '-an',
    path.resolve(outputPath),
  ], { stdio: ['pipe', 'inherit', 'inherit'] });
  const ffmpegDone = new Promise((resolve, reject) => {
    ffmpeg.on('close', (code) => (code === 0 ? resolve() : reject(new Error(`ffmpeg code ${code}`))));
    ffmpeg.on('error', reject);
  });

  try {
    const context = await browser.newContext({
      viewport: { width: VIEWPORT_W, height: VIEWPORT_H },
      deviceScaleFactor: 1,
    });
    const page = await context.newPage();
    await page.goto('file://' + path.resolve(htmlPath), { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);

    // Démarrer les animations (le gabarit les tient en pause sans cette classe),
    // puis les GELER toutes : c'est nous qui tenons l'horloge désormais.
    await page.evaluate(() => {
      document.body.classList.add('recording');
      for (const a of document.getAnimations()) a.pause();
    });

    const cdp = await context.newCDPSession(page);

    let seekMs = 0;
    let shotMs = 0;
    for (let i = 0; i < totalFrames; i++) {
      const t = (i * 1000) / fps;
      let t0 = Date.now();
      await page.evaluate((ms) => {
        for (const a of document.getAnimations()) a.currentTime = ms;
      }, t);
      seekMs += Date.now() - t0;

      t0 = Date.now();
      const { data } = await cdp.send('Page.captureScreenshot', {
        format: 'jpeg',
        quality: JPEG_QUALITY,
        optimizeForSpeed: true,
      });
      shotMs += Date.now() - t0;

      if (!ffmpeg.stdin.write(Buffer.from(data, 'base64'))) {
        await new Promise((r) => ffmpeg.stdin.once('drain', r));
      }
    }

    ffmpeg.stdin.end();
    await ffmpegDone;
    await context.close();

    const elapsedMs = Date.now() - started;
    console.log(JSON.stringify({
      status: 'ok',
      path: path.resolve(outputPath),
      size: fs.statSync(path.resolve(outputPath)).size,
      frames: totalFrames,
      requested_ms: durationMs,
      elapsed_ms: elapsedMs,
      ms_per_frame: Math.round((elapsedMs / totalFrames) * 10) / 10,
      seek_ms_per_frame: Math.round((seekMs / totalFrames) * 10) / 10,
      shot_ms_per_frame: Math.round((shotMs / totalFrames) * 10) / 10,
      speed_vs_realtime: Math.round((durationMs / elapsedMs) * 100) / 100,
      fps,
    }));
  } finally {
    await browser.close();
  }
}

if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.length < 3) {
    console.error('Usage: node proto_capture.js <html_file> <output_mp4> <duration_ms> [fps]');
    process.exit(1);
  }
  const [htmlFile, outputPath, durationMsRaw, fpsRaw] = args;
  captureDeterministic(htmlFile, outputPath, parseInt(durationMsRaw, 10),
                       parseInt(fpsRaw || String(DEFAULT_FPS), 10))
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(JSON.stringify({ status: 'error', message: err.message }));
      process.exit(1);
    });
}

module.exports = { captureDeterministic };
