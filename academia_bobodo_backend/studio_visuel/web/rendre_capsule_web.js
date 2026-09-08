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

// L'IMPORTMAP N'EST PAS DECORATIVE. `GLTFLoader.js`, tel qu'il est livre dans
// le paquet `three`, importe « from 'three' » -- un specificateur nu, que le
// navigateur ne sait pas resoudre seul. Sans cette table, la page leve
// « Failed to resolve module specifier » et ne demarre pas du tout.
const PAGE = `<!doctype html><html><head><meta charset="utf-8">
<style>html,body{margin:0;background:#000;overflow:hidden}canvas{display:block}</style>
<script type="importmap">{"imports":{"three":"./three.module.js"}}<\/script>
</head><body><script type="module">
import { composer, creerRendu, deposerObjet } from './academia3d_web.js';

// LE CHARGEUR EST FACULTATIF, ET SON ABSENCE DOIT SE DIRE.
// Si GLTFLoader.js n'a pas pu etre copie (paquet three sans examples/), la
// page doit quand meme demarrer : les cinq verbes de forme fonctionnent, seul
// convoquer manquera -- et le journal le dira, au lieu d'un ecran noir.
// (Pas d'accent grave dans ce bloc : il est lui-meme dans un litteral de
//  gabarit, et un accent grave y fermerait la chaine.)
// Le chemin garde son dossier : GLTFLoader importe ses voisins en relatif
// (../utils/...), ce qui n'a de sens que si l'arborescence est preservee.
let Chargeur = null;
try {
  ({ GLTFLoader: Chargeur } = await import('./loaders/GLTFLoader.js'));
} catch (e) {
  window.__sans_chargeur = String(e).slice(0, 200);
}

// PRECHARGEMENT : composer() est synchrone, le chargement glTF ne l'est pas.
// On tire donc tous les maillages AVANT de composer, et convoquer ne fait
// plus que puiser dans ce cache.
window.__precharger = async (fichiers) => {
  const bilan = [];
  if (!Chargeur) return fichiers.map((f) => \`\${f} : chargeur glTF absent\`);
  const loader = new Chargeur();
  for (const fichier of fichiers) {
    try {
      const gltf = await loader.loadAsync('./' + fichier);
      deposerObjet(fichier, gltf.scene);
    } catch (e) {
      bilan.push(\`\${fichier} : \${String(e.message || e).slice(0, 120)}\`);
    }
  }
  return bilan;
};

let rendu = null, courante = null;
window.__batir = (description, L, H) => {
  if (!rendu) rendu = creerRendu(L, H);
  courante = composer(description, L, H);
  return courante.journal;
};
window.__image = (t) => { courante.poser(t); rendu.render(courante.scene, courante.cam); };
window.__pret = true;
</script></body></html>`;

// ── Les maillages de `convoquer`, tires AVANT le navigateur ───────────────
//
// POURQUOI COTE NODE ET NON DANS LA PAGE. La page tourne dans un Chromium
// sans reseau garanti, et un telechargement rate y serait muet. Ici, chaque
// echec s'imprime dans le journal, qui remonte avec le rendu.
//
// L'INDEX PORTE DEJA LE CHEMIN. `construire_index_objets.py` l'y inscrit une
// fois, hors ligne : sans lui il faudrait charger `object-paths.json.gz`,
// 60 Mo, dans la boucle etudiant, sur une machine qui vit dix minutes.
const BASE_HF = 'https://huggingface.co/datasets/allenai/objaverse/resolve/main/';
const INDEX = path.join(ICI, '..', 'contours', 'index_objets.json');
const CACHE = process.env.STUDIO_CACHE_OBJETS
  || path.join(require('os').tmpdir(), 'academia-objets');

function chercher(terme) {
  let table;
  try {
    table = JSON.parse(fs.readFileSync(INDEX, 'utf8')).termes;
  } catch (e) {
    console.log(`DEGRADATION - index des objets illisible : ${e.message}`);
    return [];
  }
  const cle = String(terme || '').toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '').trim();
  if (table[cle]) return table[cle];
  // Tolerant, comme `convoquer.chercher` : « les volcans » trouve « volcan ».
  for (const mot of cle.split(/\s+/).filter((m) => m.length > 3)) {
    if (table[mot]) return table[mot];
    const singulier = mot.endsWith('s') ? mot.slice(0, -1) : mot;
    if (table[singulier]) return table[singulier];
  }
  return [];
}

async function tirer(url, destination) {
  const reponse = await fetch(url, { redirect: 'follow' });
  if (!reponse.ok) throw new Error(`HTTP ${reponse.status}`);
  const octets = Buffer.from(await reponse.arrayBuffer());
  // On ecrit sous un nom provisoire : un telechargement interrompu ne doit pas
  // laisser un fichier tronque que le cache croira valide.
  fs.writeFileSync(destination + '.part', octets);
  fs.renameSync(destination + '.part', destination);
  return octets.length;
}

/** Resout chaque `convoquer` en un fichier local, et renseigne son parametre. */
async function preparerMaillages(capsule, atelier) {
  fs.mkdirSync(CACHE, { recursive: true });
  const voulus = new Set();
  for (const scene of capsule.scenes || []) {
    for (const geste of scene.gestes || []) {
      if (geste.verbe !== 'convoquer') continue;
      const terme = (geste.parametres || {}).terme;
      const candidats = chercher(terme);
      if (!candidats.length) {
        console.log(`DEGRADATION ${scene.id} convoquer : aucun objet connu pour « ${terme} »`);
        continue;
      }
      const choisi = candidats[0];
      const nom = `${choisi.uid}.glb`;
      geste.parametres.fichier = nom;
      voulus.add(JSON.stringify([nom, choisi.chemin, choisi.uid, choisi.licence,
                                 choisi.description]));
    }
  }

  const prets = [];
  for (const brut of voulus) {
    const [nom, chemin, uid, licence, description] = JSON.parse(brut);
    const garde = path.join(CACHE, nom);
    try {
      if (!fs.existsSync(garde) || fs.statSync(garde).size === 0) {
        if (!chemin) throw new Error('entree sans chemin dans l index');
        const ko = Math.round(await tirer(BASE_HF + chemin, garde) / 1024);
        console.log(`FAIT - convoquer tire ${uid.slice(0, 8)} (${licence}) ${ko} Ko — ${String(description).slice(0, 60)}`);
      } else {
        console.log(`FAIT - convoquer en cache ${uid.slice(0, 8)} (${licence}) — ${String(description).slice(0, 60)}`);
      }
      fs.copyFileSync(garde, path.join(atelier, nom));
      prets.push(nom);
    } catch (e) {
      console.log(`DEGRADATION - convoquer ${uid.slice(0, 8)} indisponible : ${e.message}`);
    }
  }
  return prets;
}

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

  // ── Le chargeur glTF, AVEC SES DEPENDANCES ──────────────────────────────
  //
  // Il vit dans `examples/jsm`, pas dans `build`, et il n'est PAS autonome :
  // selon la version de `three`, il importe `../utils/BufferGeometryUtils.js`.
  // Copier le seul GLTFLoader.js le laissait donc importer un module absent,
  // et Chromium repondait « Failed to fetch dynamically imported module » en
  // nommant le module RACINE — un message qui accuse le fichier present et se
  // tait sur celui qui manque.
  //
  // Mesure du 05/09, travail 37483275 : les trois maillages etaient tires
  // (4 214 Ko pour « a volcano with fire »), et aucun n'a pu etre charge.
  //
  // On copie donc l'arborescence `examples/jsm` telle quelle, et le serveur
  // ci-dessous sert des CHEMINS RELATIFS — voir la note qui l'accompagne.
  const JSM = path.join(TROIS, '..', 'examples', 'jsm');
  if (fs.existsSync(path.join(JSM, 'loaders', 'GLTFLoader.js'))) {
    // Copie explicite plutot que `fs.cpSync` : celui-ci n'est stable que sur
    // Node recent, et l'image du pod n'est pas maitrisee ici. Une fonction de
    // six lignes ne peut pas manquer a l'appel.
    const copier = (source, destination) => {
      fs.mkdirSync(destination, { recursive: true });
      for (const entree of fs.readdirSync(source, { withFileTypes: true })) {
        const de = path.join(source, entree.name);
        const vers = path.join(destination, entree.name);
        if (entree.isDirectory()) copier(de, vers);
        else fs.copyFileSync(de, vers);
      }
    };
    let fichiers = 0;
    for (const sous of ['loaders', 'utils', 'libs']) {
      const source = path.join(JSM, sous);
      if (!fs.existsSync(source)) continue;
      copier(source, path.join(atelier, sous));
      fichiers += fs.readdirSync(source).length;
    }
    console.log(`FAIT - chargeur glTF copie (${fichiers} entree(s) depuis examples/jsm)`);
  } else {
    console.log(`DEGRADATION - GLTFLoader absent (${JSM}) — convoquer sera sans effet`);
  }

  const maillages = await preparerMaillages(capsule, atelier);
  fs.writeFileSync(path.join(atelier, 'scene.html'), PAGE);

  const types = { '.html': 'text/html', '.js': 'text/javascript',
                  '.glb': 'model/gltf-binary', '.wasm': 'application/wasm' };
  // ON SERT DES CHEMINS RELATIFS, PLUS UN `basename`.
  //
  // `basename` aplatissait toute l'arborescence : une requete pour
  // `/utils/BufferGeometryUtils.js` cherchait `BufferGeometryUtils.js` A LA
  // RACINE de l'atelier, donc 404. C'est ce qui empechait GLTFLoader de se
  // charger, et donc `convoquer` de placer le moindre objet -- alors que les
  // maillages, eux, etaient bien telecharges.
  //
  // La contrepartie d'un vrai chemin est la traversee (`../../etc/passwd`) :
  // on resout, puis on VERIFIE que le resultat reste sous l'atelier. Le
  // serveur n'ecoute que sur 127.0.0.1 et ne vit que le temps du rendu, mais
  // un garde-fou qui ne coute rien se pose quand meme.
  const serveur = http.createServer((req, res) => {
    const demande = decodeURIComponent(req.url.split('?')[0]).replace(/^\/+/, '')
                    || 'scene.html';
    const cible = path.resolve(atelier, demande);
    if (cible !== atelier && !cible.startsWith(atelier + path.sep)) {
      res.writeHead(403); return res.end('hors atelier');
    }
    fs.readFile(cible, (err, data) => {
      if (err) { res.writeHead(404); return res.end('absent'); }
      res.writeHead(200, { 'Content-Type': types[path.extname(cible)] || 'application/octet-stream' });
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

  // LE PRECHARGEMENT SE FAIT UNE FOIS, POUR TOUTE LA CAPSULE. Les maillages
  // sont partages entre scenes -- « le volcan » en convoque un dans quatre
  // scenes sur cinq -- et les recharger a chaque scene serait payer quatre fois.
  const sansChargeur = await page.evaluate(() => window.__sans_chargeur || null);
  if (sansChargeur) {
    console.log(`DEGRADATION - chargeur glTF indisponible : ${sansChargeur}`);
  }
  if (maillages.length) {
    const echecs = await page.evaluate((liste) => window.__precharger(liste), maillages);
    for (const echec of echecs) console.log(`DEGRADATION - prechargement ${echec}`);
    console.log(`FAIT - ${maillages.length - echecs.length}/${maillages.length} maillage(s) charge(s)`);
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
