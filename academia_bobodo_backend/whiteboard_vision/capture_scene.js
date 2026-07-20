/**
 * Scene Capture via Playwright (Node.js)
 * Smart Whiteboard Vision Engine
 * 
 * Usage: node capture_scene.js <html_file> <output_png> [wait_ms]
 * 
 * Opens the HTML file in headless Chromium, waits for animations,
 * then captures a 1080x1920 screenshot.
 */

const { chromium } = require('playwright');
const path = require('path');

const VIEWPORT_W = 1080;
const VIEWPORT_H = 1920;

async function captureScene(htmlPath, outputPng, waitMs = 3000) {
  const browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-gpu',
      '--disable-dev-shm-usage',
      '--font-render-hinting=none',
    ],
  });

  try {
    const page = await browser.newPage({
      viewport: { width: VIEWPORT_W, height: VIEWPORT_H },
      deviceScaleFactor: 1,
    });

    // Charger le fichier HTML local
    const fileUrl = 'file://' + path.resolve(htmlPath);
    await page.goto(fileUrl, { waitUntil: 'networkidle' });

    // Attendre la fin des animations CSS
    await page.waitForTimeout(waitMs);

    // Capture
    await page.screenshot({
      path: outputPng,
      fullPage: false,
      type: 'png',
    });

    const fs = require('fs');
    const stats = fs.statSync(outputPng);
    console.log(JSON.stringify({
      status: 'ok',
      path: outputPng,
      size: stats.size,
      width: VIEWPORT_W,
      height: VIEWPORT_H,
    }));
  } finally {
    await browser.close();
  }
}

// CLI
if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node capture_scene.js <html_file> <output_png> [wait_ms]');
    process.exit(1);
  }

  const htmlFile = args[0];
  const outputPng = args[1];
  const waitMs = parseInt(args[2] || '3000', 10);

  captureScene(htmlFile, outputPng, waitMs)
    .then(() => process.exit(0))
    .catch(err => {
      console.error(JSON.stringify({ status: 'error', message: err.message }));
      process.exit(1);
    });
}

module.exports = { captureScene };
