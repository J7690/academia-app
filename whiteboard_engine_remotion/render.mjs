// Rendu programmatique d'un storyboard -> MP4 (zéro crédit IA).
//
// Étapes :
//   1. Bundle du projet Remotion (inclut public/narration/*.wav générés par narrate.py).
//   2. Rendu de la composition "SmartWhiteboard" PAR TRANCHES D'IMAGES, chacune dans un
//      processus séparé (voir « Pourquoi par tranches » ci-dessous).
//   3. Concaténation des tranches, puis finalisation ffmpeg -> profil H.264 device-safe
//      (main/4.0, 720x1280, yuv420p, +faststart) pour une lecture Android garantie.
//
// ─── POURQUOI PAR TRANCHES (correctif du 25/07/2026) ────────────────────────────
// Le rendu d'un cours complet (8 scènes, ~155 s) échouait systématiquement sur
// « FATAL ERROR: Reached heap limit — JavaScript heap out of memory », à ~6 Go, après
// une douzaine de minutes. Une vidéo courte (29 s) passait sans difficulté, avec une
// empreinte mémoire modeste.
//
// Deux corrections ciblées ont été tentées sans succès (réduction du nombre d'éléments
// animés, vérification de la concurrence déjà à 1). La consommation croît donc avec le
// NOMBRE D'IMAGES rendues dans un même processus : quelque chose s'accumule au fil du
// rendu, dans la page ou dans le moteur, sans être libéré.
//
// Plutôt que de continuer à chercher CE qui fuit, on borne le problème : chaque tranche
// est rendue par un processus Node distinct, qui se termine et rend toute sa mémoire au
// système. L'empreinte maximale ne dépend alors plus de la durée totale de la vidéo,
// mais seulement de la taille d'une tranche — une valeur qu'on sait sûre.
//
// La composition reste identique et le découpage se fait sur des NUMÉROS D'IMAGES : la
// continuité du cahier qui défile, la voix off et les annotations sont préservées à
// l'identique, contrairement à un découpage scène par scène.
//
// Usage :
//   node render.mjs --storyboard ./job/storyboard.json \
//                   --narration ./job/narration.json \
//                   --out ./job/output.mp4
//
// Variables d'environnement :
//   REMOTION_CHUNK_FRAMES  taille d'une tranche en images (défaut 900, soit 30 s)

import { bundle } from "@remotion/bundler";
import { selectComposition, renderMedia } from "@remotion/renderer";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import fs from "node:fs";

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
const CHUNK_FRAMES = parseInt(process.env.REMOTION_CHUNK_FRAMES || "900", 10);

const run = (cmd, cmdArgs, extraEnv = {}) =>
  new Promise((resolve, reject) => {
    const p = spawn(cmd, cmdArgs, { stdio: "inherit", env: { ...process.env, ...extraEnv } });
    p.on("close", (code) =>
      code === 0 ? resolve() : reject(new Error(`${cmd} exited ${code}`))
    );
  });

// ── Mode « tranche » : ce processus ne rend qu'un intervalle d'images, puis meurt. ──
const renderChunk = async () => {
  const from = parseInt(args["chunk-from"], 10);
  const to = parseInt(args["chunk-to"], 10);
  const serveUrl = args["serve-url"];
  const out = path.resolve(args["chunk-out"]);
  const inputProps = { storyboard, narration, fps };

  const composition = await selectComposition({ serveUrl, id: "SmartWhiteboard", inputProps });
  console.log(`[remotion] tranche ${from}-${to} (${to - from + 1} images)…`);
  await renderMedia({
    composition,
    serveUrl,
    codec: "h264",
    outputLocation: out,
    inputProps,
    crf: 20,
    // Un seul onglet Chromium à la fois : empreinte mémoire minimale.
    concurrency: 1,
    frameRange: [from, to],
  });
  console.log(`[remotion] tranche ${from}-${to} OK`);
};

// ── Mode principal : bundle, découpe, assemble. ─────────────────────────────────
const main = async () => {
  console.log("[remotion] bundling…");
  const serveUrl = await bundle({ entryPoint: path.join(here, "src/index.ts") });

  const inputProps = { storyboard, narration, fps };
  console.log("[remotion] selecting composition…");
  const composition = await selectComposition({ serveUrl, id: "SmartWhiteboard", inputProps });

  const total = composition.durationInFrames;
  const nbChunks = Math.ceil(total / CHUNK_FRAMES);
  console.log(`[remotion] ${total} images -> ${nbChunks} tranche(s) de ${CHUNK_FRAMES} max`);

  const tmpDir = fs.mkdtempSync(path.join(path.dirname(outPath), "chunks-"));
  const chunkFiles = [];

  try {
    for (let i = 0; i < nbChunks; i++) {
      const from = i * CHUNK_FRAMES;
      const to = Math.min(total - 1, from + CHUNK_FRAMES - 1);
      const chunkOut = path.join(tmpDir, `chunk_${String(i).padStart(3, "0")}.mp4`);

      // Processus SÉPARÉ : à sa mort, toute sa mémoire est rendue au système.
      await run(process.execPath, [
        fileURLToPath(import.meta.url),
        "--storyboard", storyboardPath,
        ...(narrationPath ? ["--narration", narrationPath] : []),
        "--chunk-from", String(from),
        "--chunk-to", String(to),
        "--chunk-out", chunkOut,
        "--serve-url", serveUrl,
      ]);

      if (!fs.existsSync(chunkOut)) throw new Error(`tranche manquante : ${chunkOut}`);
      chunkFiles.push(chunkOut);
    }

    // Concaténation sans réencodage (les tranches partagent le même encodage).
    const listPath = path.join(tmpDir, "liste.txt");
    fs.writeFileSync(listPath, chunkFiles.map((f) => `file '${f}'`).join("\n"), "utf-8");
    console.log("[ffmpeg] concaténation des tranches…");
    await run("ffmpeg", ["-y", "-f", "concat", "-safe", "0", "-i", listPath, "-c", "copy", rawOut]);

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
  } finally {
    fs.rmSync(rawOut, { force: true });
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }

  console.log(`[done] ${outPath}`);
};

const isChunk = args["chunk-from"] !== undefined;
(isChunk ? renderChunk() : main()).catch((e) => {
  console.error(e);
  process.exit(1);
});
