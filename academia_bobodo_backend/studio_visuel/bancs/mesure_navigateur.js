/**
 * MESURE : un navigateur sans carte graphique peut-il rendre nos capsules ?
 *
 * C'est la mesure qui decide d'abandonner ou non RunPod et Blender. Elle doit
 * donc etre INATTAQUABLE. Les trois bancs WebGL du 11/08 etaient faux :
 *   - une boucle sur requestAnimationFrame plafonnait a ~5 images ;
 *   - une boucle synchrone annoncait 9434 images/s sur des captures de 10 Ko,
 *     c'est-a-dire du vide compte tres vite.
 *
 * D'ou trois garde-fous ici :
 *   1. on RELIT les pixels a chaque image (`readPixels`), ce qui force le GPU a
 *      terminer son travail -- sans quoi on mesure la file d'attente, pas le rendu ;
 *   2. on COMPTE les pixels allumes : une image noire invalide la mesure ;
 *   3. on ecrit une vraie capture PNG a la fin, dont on verifie la taille.
 *
 * La scene est celle que le compositeur produit reellement : filaire bleu
 * emissif sur fond noir, un solide de revolution et une sphere facettee, en
 * 1080x1920. Pas une scene de demonstration.
 */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const http = require('http');

const LARGEUR = 1080, HAUTEUR = 1920;
const IMAGES = Number(process.env.IMAGES || 60);
const SORTIE = process.env.SORTIE || '/tmp/mesure';

// On CHARGE three par son chemin au lieu de l'inliner : depuis la 0.15x il est
// eclate en plusieurs fichiers (`three.core.js`), et recopier le seul module
// principal casse ses imports internes.
const THREE_DIR = '/opt/rendu/node_modules/three/build';
const THREE_URL = './three.module.js';

const PAGE = `<!doctype html><html><head><meta charset="utf-8">
<style>html,body{margin:0;background:#000;overflow:hidden}canvas{display:block}</style>
</head><body>
<script type="module">
import { WebGLRenderer, Scene, Color, PerspectiveCamera, MeshBasicMaterial,
         LatheGeometry, IcosahedronGeometry, Mesh, Vector2 } from '${THREE_URL}';

const L = ${LARGEUR}, H = ${HAUTEUR};
const renderer = new WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setSize(L, H, false);
document.body.appendChild(renderer.domElement);

const scene = new Scene();
scene.background = new Color(0x000000);
const cam = new PerspectiveCamera(38, L / H, 0.1, 500);

// Le style du depot : filaire bleu emissif, aucune lumiere -- la matiere brille.
const bleu = new MeshBasicMaterial({ color: 0x2f86ff, wireframe: true });

// « revolutionner » : un becher, profil [rayon, hauteur] tourne autour de Z.
const profil = [[3,0],[3,4],[2.8,4],[2.8,0.5],[3,0.5]]
  .map(([r,h]) => new Vector2(r, h));
const becher = new Mesh(new LatheGeometry(profil, 32), bleu);
becher.rotation.x = Math.PI / 2;
scene.add(becher);

// « sculpter » : une sphere facettee, posee dedans.
const sphere = new Mesh(new IcosahedronGeometry(1.5, 2), bleu);
sphere.position.set(0, 1.5, 0);
scene.add(sphere);

// Le cadrage mesure du compositeur : ~24 unites de recul.
const RECUL = 24;
window.__poser = (t) => {
  const a = (-13 + 26 * t) * Math.PI / 180;
  cam.position.set(RECUL * Math.sin(a) * 0.18, 2 + t * 1.2, RECUL * Math.cos(a));
  cam.lookAt(0, 2, 0);
};
window.__rendre = () => renderer.render(scene, cam);

// LA RELECTURE DES PIXELS. Elle force la fin du rendu ET prouve qu'il y a une
// image : sans elle, on chronometre une file d'attente.
const gl = renderer.getContext();
const tampon = new Uint8Array(L * H * 4);
window.__lire = () => {
  gl.readPixels(0, 0, L, H, gl.RGBA, gl.UNSIGNED_BYTE, tampon);
  let allumes = 0;
  for (let i = 0; i < tampon.length; i += 4 * 97) {
    if (tampon[i] > 8 || tampon[i+1] > 8 || tampon[i+2] > 8) allumes++;
  }
  return allumes;
};
window.__pret = true;
window.__renderer = renderer.getContext().getParameter(
  renderer.getContext().getExtension('WEBGL_debug_renderer_info')?.UNMASKED_RENDERER_WEBGL
  ?? renderer.getContext().RENDERER);
</script></body></html>`;

(async () => {
  fs.mkdirSync(SORTIE, { recursive: true });
  // Chromium refuse un import de module `file://` venant d'un AUTRE dossier que
  // la page : chaque fichier local est une origine opaque. On copie donc les
  // deux fichiers de three a cote de la page et on importe en relatif.
  for (const f of ['three.module.js', 'three.core.js']) {
    fs.copyFileSync(path.join(THREE_DIR, f), path.join(SORTIE, f));
  }
  const page_html = path.join(SORTIE, 'scene.html');
  fs.writeFileSync(page_html, PAGE);

  // UN SERVEUR HTTP LOCAL, ET C'EST OBLIGATOIRE.
  // Chromium refuse tout import de module ES en `file://` : la page a une
  // origine « null » et la politique CORS bloque. Servir en HTTP est la seule
  // facon d'utiliser three.js dans une page locale.
  const types = { '.html': 'text/html', '.js': 'text/javascript' };
  const serveur = http.createServer((req, res) => {
    const nom = decodeURIComponent(req.url.split('?')[0]).replace(/^\//, '') || 'scene.html';
    const cible = path.join(SORTIE, path.basename(nom));
    fs.readFile(cible, (err, data) => {
      if (err) { res.writeHead(404); return res.end('absent'); }
      res.writeHead(200, { 'Content-Type': types[path.extname(cible)] || 'application/octet-stream' });
      res.end(data);
    });
  });
  await new Promise((r) => serveur.listen(0, '127.0.0.1', r));
  const port = serveur.address().port;

  const navigateur = await chromium.launch({
    // `--use-angle=gl-egl` engage la carte NVIDIA -- mesure du 11/08 -- mais
    // LWS n'en a pas : la creation du contexte echoue. Ici on mesure justement
    // ce que vaut le rendu LOGICIEL, donc on demande SwiftShader explicitement.
    args: (process.env.FLAGS || '--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader')
            .split(' ').filter(Boolean)
            .concat(['--disable-dev-shm-usage', '--no-sandbox']),
  });
  const page = await navigateur.newPage({ viewport: { width: LARGEUR, height: HAUTEUR } });
  const erreurs = [];
  page.on('pageerror', (e) => erreurs.push(String(e).slice(0, 200)));

  page.on('console', (m) => { if (m.type() === 'error') erreurs.push(m.text().slice(0, 200)); });
  await page.goto(`http://127.0.0.1:${port}/scene.html`);
  try {
    await page.waitForFunction('window.__pret === true', { timeout: 60000 });
  } catch (e) {
    console.error('LA PAGE N A PAS DEMARRE. Erreurs collectees :');
    for (const err of erreurs) console.error('  - ' + err);
    throw e;
  }

  const moteur = await page.evaluate('window.__renderer');
  console.log('moteur graphique : ' + moteur);

  // Une image d'echauffement : la premiere compile les shaders et fausserait
  // la moyenne.
  await page.evaluate('(() => { window.__poser(0); window.__rendre(); return window.__lire(); })()');

  const depart = Date.now();
  let allumesMin = Infinity;
  for (let i = 0; i < IMAGES; i++) {
    const allumes = await page.evaluate(
      `(() => { window.__poser(${i / (IMAGES - 1)}); window.__rendre(); return window.__lire(); })()`);
    if (allumes < allumesMin) allumesMin = allumes;
  }
  const ecoule = (Date.now() - depart) / 1000;

  await page.screenshot({ path: path.join(SORTIE, 'temoin.png') });
  const octets = fs.statSync(path.join(SORTIE, 'temoin.png')).size;
  await navigateur.close();
  serveur.close();

  const parImage = ecoule / IMAGES;
  console.log(JSON.stringify({
    moteur_graphique: moteur,
    images: IMAGES,
    secondes_totales: Number(ecoule.toFixed(2)),
    secondes_par_image: Number(parImage.toFixed(3)),
    images_par_seconde: Number((1 / parImage).toFixed(2)),
    pixels_allumes_minimum: allumesMin,
    temoin_octets: octets,
    valide: allumesMin > 50 && octets > 20000,
    erreurs_page: erreurs,
  }, null, 1));
})().catch((e) => { console.error('ECHEC ' + e); process.exit(1); });
