// Rendu programmatique d'un storyboard -> MP4, exécuté sur Kamatera (zéro crédit IA).
//
// Étapes :
//   1. Bundle du projet Remotion (inclut public/narration/*.wav générés par narrate.py).
//   2. Rendu de la composition "SmartWhiteboard" avec le storyboard + manifest narration.
//   3. Finalisation ffmpeg -> profil H.264 device-safe (main/4.0, 720x1280, yuv420p,
//      +faststart) identique au correctif v9, pour une lecture Android garantie.
//
// Usage :
//   node render.mjs --storyboard ./job/storyboard.json \
//                   --narration ./job/narration.json \
//                   --out ./job/output.mp4
//
// narration.json (produit par narrate.py) : [{scene_index, audio_path, duration_sec}]
// audio_path est relatif au dossier public/ (ex. "narration/scene_0.wav") ou null.

import { bundle } from "@remotion/bundler";
import { selectComposition, renderMedia } from "@remotion/renderer";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import fs from "node:fs";
import os from "node:os";

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, cur, i, arr) => {
    if (cur.startsWith("--")) acc.push([cur.slice(2), arr[i + 1]]);
    return acc;
  }, [])
);

const here = path.dirname(fileURLToPath(import.meta.url));
const storyboardPath = path.resolve(args.storyboard);
const narrationPath = args.narration ? path.resolve(args.narration) : null;
const outPath = path.resolve(args.out ?? "./output.mp4");
const rawOut = outPath.replace(/\.mp4$/, ".raw.mp4");

const storyboard = JSON.parse(fs.readFileSync(storyboardPath, "utf-8"));
const narration = narrationPath
  ? JSON.parse(fs.readFileSync(narrationPath, "utf-8"))
  : storyboard.scenes.map((_, i) => ({ scene_index: i, audio_path: null, duration_sec: 0 }));

const fps = 30;

const run = (cmd, cmdArgs) =>
  new Promise((resolve, reject) => {
    const p = spawn(cmd, cmdArgs, { stdio: "inherit" });
    p.on("close", (code) =>
      code === 0 ? resolve() : reject(new Error(`${cmd} exited ${code}`))
    );
  });

const main = async () => {
  console.log("[remotion] bundling…");
  const serveUrl = await bundle({
    entryPoint: path.join(here, "src/index.ts"),
    // public/ est inclus automatiquement (contient narration/*.wav).
  });

  const inputProps = { storyboard, narration, fps };

  console.log("[remotion] selecting composition…");
  const composition = await selectComposition({
    serveUrl,
    id: "SmartWhiteboard",
    inputProps,
  });

  console.log(`[remotion] rendering ${composition.durationInFrames} frames…`);
  await renderMedia({
    composition,
    serveUrl,
    codec: "h264",
    outputLocation: rawOut,
    inputProps,
    // Qualité correcte ; le profil final est fixé par la passe ffmpeg ci-dessous.
    crf: 20,
    // Concurrence 1 : un seul worker Chromium à la fois (mémoire minimale).
    concurrency: 1,
  });

  console.log("[ffmpeg] finalisation device-safe (main/4.0, 720x1280)…");
  await run("ffmpeg", [
    "-y", "-i", rawOut,
    "-c:v", "libx264",
    "-profile:v", "main", "-level:v", "4.0",
    "-pix_fmt", "yuv420p",
    "-vf", "scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2:color=white,setsar=1",
    "-r", String(fps),
    "-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-ac", "2",
    "-movflags", "+faststart",
    outPath,
  ]);

  fs.rmSync(rawOut, { force: true });
  console.log(`[done] ${outPath}`);
};

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
