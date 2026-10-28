// LES OBJETS DU SUJET, ALLÉGÉS POUR LE TÉLÉPHONE (28/10/2026).
//
// Pourquoi : l'index Objaverse pèse 1,2 Go (médiane 4,9 Mo, « neurone » 370 Mo).
// Sur le TECNO, « rivière » (35,8 Mo) a tenu le lecteur muet 25 s, et le plafond
// de 3 Mo posé en urgence n'en laissait passer que 25 sur 69.
//
// Ce qui pèse ne s'affiche pas : le lecteur n'emploie que la FORME (lecteur.js,
// habiller) et l'habille de son verre, de ses arêtes et de ses points. On retire
// donc textures, matériaux, normales, UV, couleurs, animations ; on soude ; on
// simplifie au-delà de PLAFOND triangles ; on quantifie sur 14 bits et on
// compresse en EXT_meshopt_compression (décodeur MIT de three.js, 25 Ko, dans
// vendor/three/addons/libs/). Mesuré sur 7 objets : ≈ 100 Ko chacun, original et
// allégé indiscernables à l'écran (docs/STUDIO_3D_BIBLIOTHEQUE_ILLUSTRATION_2026-10-28.md).
//
// Sortie : <sortie>/<terme_avec_soulignés>.glb et <sortie>/index.json, qui garde
// pour chaque terme l'uid et la licence de l'index d'origine — l'attribution
// CC-BY reste due et le lecteur l'affiche.
//
// usage : node publier_objets_legers.mjs <glb_bruts> <index_objets.json> <sortie>
//   (dépendances : npm i @gltf-transform/core@4 @gltf-transform/functions@4
//    @gltf-transform/extensions@4 meshoptimizer@0.22 — toutes MIT)
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS, EXTMeshoptCompression } from '@gltf-transform/extensions';
import { dedup, flatten, join, weld, simplify, prune, quantize } from '@gltf-transform/functions';
import { MeshoptEncoder, MeshoptSimplifier } from 'meshoptimizer';
import fs from 'node:fs';
import path from 'node:path';

const PLAFOND = 20000;   // triangles : au-delà, la différence ne se voit plus dans notre filaire
const [bruts, indexChemin, sortie] = process.argv.slice(2);
await MeshoptEncoder.ready; await MeshoptSimplifier.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.encoder': MeshoptEncoder });
const triangles = (doc) => doc.getRoot().listMeshes().flatMap((m) => m.listPrimitives())
  .reduce((n, p) => n + (p.getIndices() ? p.getIndices().getCount() : p.getAttribute('POSITION').getCount()) / 3, 0);

const index = JSON.parse(fs.readFileSync(indexChemin, 'utf-8'));
fs.mkdirSync(sortie, { recursive: true });
const termes = {}, echecs = [];
for (const [terme, candidats] of Object.entries(index.termes)) {
  const r0 = candidats[0];
  const fichier = terme.replace(/ /g, '_') + '.glb';
  try {
    const doc = await io.read(path.join(bruts, fichier));
    for (const t of doc.getRoot().listTextures()) t.dispose();
    for (const m of doc.getRoot().listMaterials()) m.dispose();
    for (const a of doc.getRoot().listAnimations()) a.dispose();
    for (const s of doc.getRoot().listSkins()) s.dispose();
    for (const mesh of doc.getRoot().listMeshes()) for (const p of mesh.listPrimitives()) {
      for (const s of p.listSemantics()) if (s !== 'POSITION') p.setAttribute(s, null);
      for (const c of p.listTargets()) c.dispose();
    }
    await doc.transform(flatten(), join({ keepNamed: false }), weld(), dedup(), prune());
    const origine = triangles(doc);
    if (origine > PLAFOND) await doc.transform(simplify({ simplifier: MeshoptSimplifier, ratio: PLAFOND / origine, error: 0.01 }), prune());
    await doc.transform(quantize({ quantizePosition: 14 }));
    doc.createExtension(EXTMeshoptCompression).setRequired(true)
      .setEncoderOptions({ method: EXTMeshoptCompression.EncoderMethod.QUANTIZE });
    await io.write(path.join(sortie, fichier), doc);
    termes[terme] = { fichier, octets: fs.statSync(path.join(sortie, fichier)).size, triangles: triangles(doc),
      triangles_origine: origine, uid: r0.uid, licence: r0.licence };
  } catch (e) { echecs.push(`${terme} : ${e.message}`); }
}
fs.writeFileSync(path.join(sortie, 'index.json'), JSON.stringify({
  source: index.source, licences_retenues: index.licences_retenues, attribution_requise: index.attribution_requise,
  plafond_triangles: PLAFOND, compression: 'EXT_meshopt_compression + quantification 14 bits', termes,
}, null, 1));
const total = Object.values(termes).reduce((n, t) => n + t.octets, 0);
console.log(`allégés ${Object.keys(termes).length}/${Object.keys(index.termes).length} — total ${(total / 1e6).toFixed(1)} Mo, `
  + `plus lourd ${Math.max(...Object.values(termes).map((t) => t.octets)) / 1e3 | 0} Ko`);
if (echecs.length) { console.log('ÉCHECS :\n' + echecs.join('\n')); process.exitCode = 1; }
