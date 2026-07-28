/**
 * PROTOTYPE 2 — Capture déterministe par `HeadlessExperimental.beginFrame`.
 * Smart Whiteboard — étape 2c-2 (26/07/2026). NE REMPLACE PAS record_scene.js.
 *
 * Usage: node proto_capture_bf.js <html_file> <output_mp4> <duration_ms> [fps] [start_ms]
 *
 * ─── POURQUOI CE SECOND PROTOTYPE ───────────────────────────────────────────
 * Le premier (proto_capture.js) capture par `Page.captureScreenshot` : mesuré
 * 91,5 ms par image en 1080×1920, soit 0,36× le temps réel — plus LENT que
 * l'enregistrement actuel. Le coût est proportionnel au nombre de pixels
 * (31,3 ms seulement en 540×960).
 *
 * `HeadlessExperimental.beginFrame` compose l'image ET la renvoie en un seul
 * appel CDP, sans passer par la boucle d'affichage : la documentation Chromium
 * et les mesures publiées annoncent 2 à 3× plus rapide. Exclusif à
 * `chrome-headless-shell` (présent sur le serveur) avec
 * `--enable-begin-frame-control`.
 *
 * `start_ms` permet de ne rendre qu'une TRANCHE de la vidéo : les images étant
 * indépendantes, plusieurs tranches peuvent être rendues en parallèle puis
 * concaténées.
 */

const { chromium } = require('playwright');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const VIEWPORT_W = 1080;
const VIEWPORT_H = 1920;
const DEFAULT_FPS = 25;
const JPEG_QUALITY = 80;

const SHELL_PATH = '/root/.cache/ms-playwright/chromium_headless_shell-1234/'
  + 'chrome-headless-shell-linux64/chrome-headless-shell';

async function captureBeginFrame(htmlPath, outputPath, durationMs, fps = DEFAULT_FPS, startMs = 0) {
  const outDir = path.dirname(path.resolve(outputPath));
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.launch({
    headless: true,
    executablePath: SHELL_PATH,
    args: [
      '--no-sandbox',
      '--disable-dev-shm-usage',
      '--font-render-hinting=none',
      // Indispensables à beginFrame : le compositeur ne rend plus de lui-même,
      // il attend nos demandes.
      '--enable-begin-frame-control',
      '--disable-frame-rate-limit',
      '--run-all-compositor-stages-before-draw',
      '--disable-new-content-rendering-timeout',
      '--disable-threaded-animation',
      '--disable-threaded-scrolling',
      '--disable-checker-imaging',
    ],
  });

  const started = Date.now();
  const totalFrames = Math.ceil((durationMs / 1000) * fps);

  const ffmpeg = spawn('ffmpeg', [
    '-y', '-v', 'error',
    '-f', 'image2pipe', '-framerate', String(fps), '-i', 'pipe:0',
    '-c:v', 'libx264', '-profile:v', 'main', '-level:v', '4.0',
    '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-crf', '21',
    '-r', String(fps), '-movflags', '+faststart', '-an',
    path.resolve(outputPath),
  ], { stdio: ['pipe', 'inherit', 'inherit'] });
  const ffmpegDone = new Promise((resolve, reject) => {
    ffmpeg.on('close', (c) => (c === 0 ? resolve() : reject(new Error(`ffmpeg code ${c}`))));
    ffmpeg.on('error', reject);
  });

  let seekMs = 0;
  let shotMs = 0;
  let emptyFrames = 0;

  try {
    const context = await browser.newContext({
      viewport: { width: VIEWPORT_W, height: VIEWPORT_H },
      deviceScaleFactor: 1,
    });
    const page = await context.newPage();
    await page.goto('file://' + path.resolve(htmlPath), { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);

    await page.evaluate(() => {
      document.body.classList.add('recording');
      for (const a of document.getAnimations()) a.pause();
    });

    const cdp = await context.newCDPSession(page);
    await cdp.send('HeadlessExperimental.enable').catch(() => {});

    // Chauffe : le compositeur de Chromium se met dans un état bancal si aucune
    // image ne lui est demandée pendant un moment (piège documenté par l'équipe
    // vidéo de Replit). Quelques images jetables le remettent d'aplomb.
    for (let w = 0; w < 5; w++) {
      await cdp.send('HeadlessExperimental.beginFrame', { interval: 1000 / fps });
    }

    for (let i = 0; i < totalFrames; i++) {
      const t = startMs + (i * 1000) / fps;

      let t0 = Date.now();
      await page.evaluate((ms) => {
        for (const a of document.getAnimations()) a.currentTime = ms;
      }, t);
      seekMs += Date.now() - t0;

      t0 = Date.now();
      const res = await cdp.send('HeadlessExperimental.beginFrame', {
        frameTimeTicks: undefined,
        interval: 1000 / fps,
        noDisplayUpdates: false,
        screenshot: { format: 'jpeg', quality: JPEG_QUALITY },
      });
      shotMs += Date.now() - t0;

      if (!res || !res.screenshotData) {
        // beginFrame peut ne rien renvoyer si rien n'a changé : on redemande une
        // fois, sinon on signale (une image manquante fausserait le montage).
        emptyFrames++;
        const retry = await cdp.send('HeadlessExperimental.beginFrame', {
          interval: 1000 / fps,
          screenshot: { format: 'jpeg', quality: JPEG_QUALITY },
        });
        if (!retry || !retry.screenshotData) {
          throw new Error(`beginFrame sans image a l'image ${i} (t=${t} ms)`);
        }
        res.screenshotData = retry.screenshotData;
      }

      if (!ffmpeg.stdin.write(Buffer.from(res.screenshotData, 'base64'))) {
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
      start_ms: startMs,
      requested_ms: durationMs,
      elapsed_ms: elapsedMs,
      ms_per_frame: Math.round((elapsedMs / totalFrames) * 10) / 10,
      seek_ms_per_frame: Math.round((seekMs / totalFrames) * 10) / 10,
      shot_ms_per_frame: Math.round((shotMs / totalFrames) * 10) / 10,
      empty_frames_retried: emptyFrames,
      speed_vs_realtime: Math.round((durationMs / elapsedMs) * 100) / 100,
      fps,
    }));
  } finally {
    try { ffmpeg.stdin.destroy(); } catch (_) { /* deja ferme */ }
    await browser.close();
  }
}

if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.length < 3) {
    console.error('Usage: node proto_capture_bf.js <html> <out.mp4> <duration_ms> [fps] [start_ms]');
    process.exit(1);
  }
  const [htmlFile, outputPath, durationMsRaw, fpsRaw, startRaw] = args;
  captureBeginFrame(htmlFile, outputPath, parseInt(durationMsRaw, 10),
                    parseInt(fpsRaw || String(DEFAULT_FPS), 10),
                    parseInt(startRaw || '0', 10))
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(JSON.stringify({ status: 'error', message: err.message }));
      process.exit(1);
    });
}

module.exports = { captureBeginFrame };
