/**
 * Rend une capsule composee, image par image, dans un navigateur sans carte.
 *
 * REMPLACE `blender -b --python generateur_scenes.py`. Meme contrat : on lui
 * donne un manifeste de capsule et un dossier, il y depose `sN_0001.png`,
 * `sN_0002.png`… exactement comme Blender. `executer_capsule.py` n'a donc qu'un
 * seul appel a changer, et tout le reste de la chaine -- sous-titres, voix,
 * montage, porte d'acceptation, depot -- ne bouge pas.
 *
 *   node rendre_capsule_web.js <capsule.json> <dossier> [--images N]
 *
 * POURQUOI IMAGE PAR IMAGE, ET NON EN TEMPS REEL.
 * La chaine du tableau enregistre avec `recordVideo` de Playwright : elle filme
 * une page dont les animations CSS se jouent a l'horloge du mur. C'est parfait
 * pour elle. Ici, une image coute 0,284 s : filmer en temps reel donnerait un
 * diaporama. On rend donc chaque image a la demande, comme Blender -- ce qui a
 * deux avantages qu'on garde : le rendu est DETERMINISTE (l'image i ne depend
 * que de i) et donc decoupable en plages paralleles sans la moindre derive.
 */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const http = require('http');

const [, , CHEMIN_CAPSULE, DOSSIER] = process.argv;
const IMAGES_FORCEES = (() => {
  const i = process.argv.indexOf('--images');
  return i > 0 ? Number(process.argv[i + 1]) : null;
})();

if (!CHEMIN_CAPSULE || !DOSSIER) {
  console.error('usage: node rendre_capsule_web.js <capsule.json> <dossier> [--images N]');
  process.exit(2);
}

const ICI = __dirname;
const TROIS = '/opt/rendu/node_modules/three/build';

const PAGE = `<!doctype html><html><head><meta charset="utf-8">
<style>html,body{margin:0;background:#000;overflow:hidden}canvas{display:block}</style>
</head><body><script type="module">
import { composer, creerRendu } from './academia3d_web.js';
let rendu = null, courante = null;
window.__batir = (description, L, H) => {
  if (!rendu) rendu = creerRendu(L, H);
  courante = composer(description, L, H);
  return courante.journal;
};
window.__image = (t) => { courante.poser(t); rendu.render(courante.scene, courante.cam); };
window.__pret = true;
</script></body></html>`;

(async () => {
  const capsule = JSON.parse(fs.readFileSync(CHEMIN_CAPSULE, 'utf8'));
  const L = capsule.format?.largeur || 1080;
  const H = capsule.format?.hauteur || 1920;
  const FPS = capsule.format?.fps || 25;

  fs.mkdirSync(DOSSIER, { recursive: true });
  const atelier = fs.mkdtempSync(path.join(require('os').tmpdir(), 'capsuleweb-'));
  // Chromium refuse TOUT import de module ES en `file://` -- origine nulle,
  // bloquee par CORS. Un serveur HTTP local n'est pas un confort : c'est la
  // seule facon de charger three.js dans une page locale.
  for (const f of ['three.module.js', 'three.core.js']) {
    fs.copyFileSync(path.join(TROIS, f), path.join(atelier, f));
  }
  fs.copyFileSync(path.join(ICI, 'academia3d_web.js'), path.join(atelier, 'academia3d_web.js'));
  fs.writeFileSync(path.join(atelier, 'scene.html'), PAGE);

  const types = { '.html': 'text/html', '.js': 'text/javascript' };
  const serveur = http.createServer((req, res) => {
    const nom = path.basename(decodeURIComponent(req.url.split('?')[0])) || 'scene.html';
    fs.readFile(path.join(atelier, nom), (err, data) => {
      if (err) { res.writeHead(404); return res.end('absent'); }
      res.writeHead(200, { 'Content-Type': types[path.extname(nom)] || 'application/octet-stream' });
      res.end(data);
    });
  });
  await new Promise((r) => serveur.listen(0, '127.0.0.1', r));
  const port = serveur.address().port;

  const navigateur = await chromium.launch({
    // `--use-angle=gl-egl` engage une carte NVIDIA quand il y en a une ; sur une
    // machine sans carte la creation du contexte ECHOUE. On laisse donc le choix
    // a l'environnement, avec le rendu logiciel par defaut.
    args: (process.env.FLAGS_CHROMIUM
           || '--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader')
          .split(' ').filter(Boolean)
          .concat(['--disable-dev-shm-usage', '--no-sandbox']),
  });
  const page = await navigateur.newPage({ viewport: { width: L, height: H } });
  const erreurs = [];
  page.on('pageerror', (e) => erreurs.push(String(e).slice(0, 200)));
  page.on('console', (m) => { if (m.type() === 'error') erreurs.push(m.text().slice(0, 200)); });

  await page.goto(`http://127.0.0.1:${port}/scene.html`);
  try {
    await page.waitForFunction('window.__pret === true', { timeout: 60000 });
  } catch (e) {
    console.error('GENERATEUR_ECHEC la page n a pas demarre');
    for (const err of erreurs) console.error('  - ' + err);
    throw e;
  }

  console.log(`CAPSULE ${capsule.titre || ''} — ${capsule.scenes.length} scenes`, );
  let totalImages = 0;
  const depart = Date.now();

  for (const scene of capsule.scenes) {
    const images = IMAGES_FORCEES || Math.max(1, Math.round((scene.duree_s || 10) * FPS));
    const journal = await page.evaluate(
      ([d, l, h]) => window.__batir(d, l, h),
      [{ intention: scene.intention, sujet: scene.sujet, gestes: scene.gestes }, L, H]);

    for (const d of journal.degradations) console.log(`DEGRADATION ${scene.id} ${d}`);
    console.log(`COMPOSITION ${scene.id} gestes=${journal.faits.length} `
                + `degradations=${journal.degradations.length}`);

    const t0 = Date.now();
    for (let i = 0; i < images; i++) {
      await page.evaluate((t) => window.__image(t), images > 1 ? i / (images - 1) : 0);
      // JPEG et non PNG : l'encodage PNG d'une image 1080x1920 coute plus cher
      // que le rendu lui-meme. La qualite 95 est visuellement indistinguable sur
      // du filaire, et ffmpeg reencode ensuite de toute facon.
      await page.screenshot({
        path: path.join(DOSSIER, `${scene.id}_${String(i + 1).padStart(4, '0')}.jpg`),
        type: 'jpeg', quality: 95,
      });
    }
    const ecoule = (Date.now() - t0) / 1000;
    totalImages += images;
    console.log(`SCENE ${scene.id} composition images=${images} secondes=${ecoule.toFixed(1)}`);
  }

  await navigateur.close();
  serveur.close();
  fs.rmSync(atelier, { recursive: true, force: true });

  const total = (Date.now() - depart) / 1000;
  console.log(`GENERATEUR_FINI images=${totalImages} secondes=${total.toFixed(1)} `
              + `par_image=${(total / Math.max(1, totalImages)).toFixed(3)}`);
  if (erreurs.length) {
    console.log(`GENERATEUR_ALERTES ${erreurs.length}`);
    for (const e of erreurs.slice(0, 5)) console.log('  - ' + e);
  }
})().catch((e) => { console.error('GENERATEUR_ECHEC ' + e); process.exit(1); });
