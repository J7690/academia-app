#!/usr/bin/env node
/**
 * Sonde de readiness — une machine n'est PRETE que si elle a rendu une image.
 *
 * POURQUOI « RUNNING » NE SUFFIT PAS.
 * RunPod peut declarer un Pod `RUNNING` alors qu'il n'a AUCUN GPU attribue
 * (documente : « You may be allocated zero GPUs if capacity has changed »), ou
 * que Chromium est retombe sur SwiftShader. Mesure du 11/08 sur RTX 4090 :
 *
 *     aucun drapeau         -> SwiftShader
 *     --use-gl=egl          -> SwiftShader
 *     --use-angle=gl-egl    -> RTX 4090, OpenGL ES 3.2
 *
 * La bascule est SILENCIEUSE. Un Pod ainsi degrade accepte des taches et rend
 * cent fois trop lentement, sans jamais lever d'erreur. Il faut donc une porte
 * qui MESURE, pas qui suppose.
 *
 * Les six conditions, dans l'ordre du moins cher au plus cher :
 *   1. au moins un GPU visible
 *   2. la declaration EGL du pilote est presente
 *   3. la version du moteur est celle attendue
 *   4. Blender repond, et le moteur est la ou le rendu ira le chercher
 *   5. le renderer WebGL annonce bien NVIDIA
 *   6. une image de test sort NON VIDE
 *
 * LA CONDITION 4 A ETE AJOUTEE LE 13/08, ET ELLE MANQUAIT AU PIRE ENDROIT.
 * Le 12/08 a 20h32, une machine a passe les cinq autres, s'est declaree PRETE,
 * a reclame la capsule « Poussee d'Archimede » -- et le rendu est mort sur
 *     [Errno 2] No such file or directory: '/workspace/blender/blender'
 * La sonde verifiait Chromium et WebGL, jamais Blender, alors que Blender fait
 * la TOTALITE des images. Une readiness qui ne teste pas ce que la machine va
 * faire ne mesure que sa propre confiance.
 *
 * Sortie 0 = prete. Toute autre = ne pas confier de tache.
 * Le rapport JSON part sur stdout pour etre remonte tel quel a Supabase.
 */
// `execFileSync` et non `execSync` : aucun shell n'est invoque, donc aucun
// caractere special ne peut etre interprete. La commande est pourtant
// constante ici -- c'est une habitude, pas un correctif.
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ATTENDUE = process.env.VERSION_MOTEUR_ATTENDUE || process.env.VERSION_MOTEUR || 'dev';
const SORTIE = process.env.SONDE_SORTIE || '/tmp/sonde';

const rapport = {
  pret: false, gpu_count: 0, egl_declare: false,
  version_moteur: process.env.VERSION_MOTEUR || 'inconnue',
  version_attendue: ATTENDUE, renderer: null,
  blender: null, blender_version: null, generateur: null,
  image_octets: 0, echecs: [],
};

// Les MEMES candidats, dans le MEME ordre, que `executer_capsule._trouver`.
// Si les deux listes divergent, la sonde benira un chemin que le rendu
// n'utilisera pas -- ce qui est precisement le defaut qu'elle doit attraper.
const BLENDERS = [process.env.BLENDER, '/opt/blender/blender',
                  '/usr/local/bin/blender', '/workspace/blender/blender'].filter(Boolean);
const MOTEURS = [process.env.GENERATEUR, '/opt/moteur/generateur_scenes.py',
                 '/workspace/generateur_scenes.py'].filter(Boolean);

function echec(m) { rapport.echecs.push(m); }

(async () => {
  // ── 1. Une carte, vraiment ──────────────────────────────────────────────
  try {
    const l = execFileSync('nvidia-smi',
        ['--query-gpu=name', '--format=csv,noheader'], { timeout: 20000 })
      .toString().trim().split('\n').filter(Boolean);
    rapport.gpu_count = l.length;
    rapport.gpus = l;
  } catch (e) { echec('nvidia-smi indisponible'); }
  if (rapport.gpu_count < 1) echec('zero GPU attribue');

  // ── 2. La declaration EGL ───────────────────────────────────────────────
  rapport.egl_declare = fs.existsSync('/usr/share/glvnd/egl_vendor.d/10_nvidia.json');
  if (!rapport.egl_declare) echec('declaration EGL NVIDIA absente');

  // ── 3. La version du moteur ─────────────────────────────────────────────
  if (rapport.version_moteur !== ATTENDUE) {
    echec(`version moteur ${rapport.version_moteur} != attendue ${ATTENDUE}`);
  }

  // ── 4. Blender, et le moteur qu'il doit executer ────────────────────────
  // On ne teste pas l'existence du fichier : on LANCE le binaire. Un Blender
  // present mais prive d'une libx repond « error while loading shared
  // libraries » -- present, executable, et incapable de rendre.
  rapport.blender = BLENDERS.find((p) => fs.existsSync(p)) || null;
  rapport.generateur = MOTEURS.find((p) => fs.existsSync(p)) || null;

  if (!rapport.blender) {
    echec(`blender introuvable — cherche dans ${BLENDERS.join(', ')}`);
  } else {
    try {
      rapport.blender_version = execFileSync(rapport.blender, ['--version'],
          { timeout: 60000 }).toString().split('\n')[0].trim();
    } catch (e) {
      echec(`blender ne demarre pas : ${String(e.message).slice(0, 140)}`);
    }
  }
  if (!rapport.generateur) {
    echec(`generateur_scenes.py introuvable — cherche dans ${MOTEURS.join(', ')}`);
  }

  // ── 5 et 6. Le renderer, et une image qui sort ──────────────────────────
  // On ne se contente pas de lire le nom du renderer : on DESSINE. Un contexte
  // peut s'annoncer NVIDIA et ne rien produire -- c'est exactement ce qu'ont
  // montre les captures de 10 Ko du 11/08.
  let navigateur;
  try {
    const { chromium } = require('playwright');
    navigateur = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-dev-shm-usage', '--ignore-gpu-blocklist',
             '--enable-webgl', '--use-angle=gl-egl', '--enable-gpu'],
    });
    const page = await navigateur.newPage({ viewport: { width: 256, height: 256 } });
    await page.setContent('<canvas id="c" width="256" height="256"></canvas>');

    const r = await page.evaluate(() => {
      const c = document.getElementById('c');
      const gl = c.getContext('webgl2') || c.getContext('webgl');
      if (!gl) return { renderer: null, pixels_allumes: 0 };
      const d = gl.getExtension('WEBGL_debug_renderer_info');
      const nom = d ? gl.getParameter(d.UNMASKED_RENDERER_WEBGL) : 'inconnu';
      // Un dessin trivial, puis on RELIT les pixels : c'est la seule preuve
      // qu'une image est reellement sortie du pipeline.
      gl.clearColor(0.2, 0.55, 0.95, 1.0);
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.finish();
      const p = new Uint8Array(256 * 256 * 4);
      gl.readPixels(0, 0, 256, 256, gl.RGBA, gl.UNSIGNED_BYTE, p);
      let allumes = 0;
      for (let i = 0; i < p.length; i += 4) if (p[i + 2] > 40) allumes++;
      return { renderer: nom, pixels_allumes: allumes };
    });

    rapport.renderer = r.renderer;
    rapport.pixels_allumes = r.pixels_allumes;
    if (!r.renderer) echec('aucun contexte WebGL');
    else if (!/NVIDIA|GeForce|RTX/i.test(r.renderer)) echec(`rendu logiciel : ${r.renderer}`);
    if (!r.pixels_allumes) echec('le pipeline ne produit aucun pixel');

    fs.mkdirSync(SORTIE, { recursive: true });
    const png = path.join(SORTIE, 'temoin.png');
    await page.screenshot({ path: png, timeout: 60000 });
    rapport.image_octets = fs.statSync(png).size;
    // Un PNG de 256x256 uni pese quelques centaines d'octets ; en dessous, il
    // n'y a rien. Le seuil separe « une image » de « un fichier ».
    if (rapport.image_octets < 400) echec(`image temoin vide (${rapport.image_octets} octets)`);
  } catch (e) {
    echec('sonde WebGL: ' + String(e).split('\n')[0].slice(0, 140));
  } finally {
    if (navigateur) { try { await navigateur.close(); } catch (_) { /* rien */ } }
  }

  rapport.pret = rapport.echecs.length === 0;
  console.log(JSON.stringify(rapport, null, 1));
  process.exit(rapport.pret ? 0 : 1);
})();
