// Essai d'allègement des objets du Studio 3D pour le téléphone (28/10/2026).
//
// Le lecteur n'emploie que la FORME (lecteur.js:221, habiller) : verre, arêtes et
// points sont les nôtres. On retire donc tout ce qui n'est pas la position des
// sommets (textures, matériaux, normales, UV, couleurs), on soude, on simplifie
// jusqu'à un plafond de triangles, on quantifie, et on écrit deux variantes :
//   <nom>_<plafond>.glb        quantifiée (lisible par GLTFLoader sans décodeur)
//   <nom>_<plafond>_mo.glb     + EXT_meshopt_compression (décodeur MIT ~20 Ko)
//
// usage : node alleger.mjs <dossier_entree> <dossier_sortie> <plafond1,plafond2,…>
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS, EXTMeshoptCompression } from '@gltf-transform/extensions';
import { dedup, flatten, join, weld, simplify, prune, quantize } from '@gltf-transform/functions';
import { MeshoptEncoder, MeshoptSimplifier } from 'meshoptimizer';
import fs from 'node:fs';
import path from 'node:path';

const [entree, sortie, plafondsTxt] = process.argv.slice(2);
const plafonds = plafondsTxt.split(',').map(Number);
await MeshoptEncoder.ready; await MeshoptSimplifier.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.encoder': MeshoptEncoder });
fs.mkdirSync(sortie, { recursive: true });

const triangles = (doc) => doc.getRoot().listMeshes().flatMap((m) => m.listPrimitives())
  .reduce((n, p) => n + (p.getIndices() ? p.getIndices().getCount() : p.getAttribute('POSITION').getCount()) / 3, 0);

for (const f of fs.readdirSync(entree).filter((x) => x.endsWith('.glb'))) {
  const brut = fs.statSync(path.join(entree, f)).size;
  const base = await io.read(path.join(entree, f));
  const t0 = triangles(base);
  for (const plafond of plafonds) {
    const doc = await io.read(path.join(entree, f));
    for (const t of doc.getRoot().listTextures()) t.dispose();
    for (const m of doc.getRoot().listMaterials()) m.dispose();
    for (const mesh of doc.getRoot().listMeshes()) for (const p of mesh.listPrimitives()) {
      for (const s of p.listSemantics()) if (s !== 'POSITION') p.setAttribute(s, null);
      for (const cible of p.listTargets()) cible.dispose();
    }
    for (const a of doc.getRoot().listAnimations()) a.dispose();
    for (const s of doc.getRoot().listSkins()) s.dispose();
    await doc.transform(flatten(), join({ keepNamed: false }), weld(), dedup(), prune());
    const avant = triangles(doc);
    const ratio = Math.min(1, plafond / avant);
    if (ratio < 1) await doc.transform(simplify({ simplifier: MeshoptSimplifier, ratio, error: 0.01, lockBorder: false }), prune());
    await doc.transform(quantize({ quantizePosition: 14 }));
    const nom = f.replace('.glb', '');
    const q = path.join(sortie, `${nom}_${plafond}.glb`);
    await io.write(q, doc);
    doc.createExtension(EXTMeshoptCompression).setRequired(true).setEncoderOptions({ method: EXTMeshoptCompression.EncoderMethod.QUANTIZE });
    const mo = path.join(sortie, `${nom}_${plafond}_mo.glb`);
    await io.write(mo, doc);
    console.log(JSON.stringify({ objet: nom, brut_Mo: +(brut / 1e6).toFixed(2), tri_origine: t0, plafond, tri_final: triangles(doc),
      quantifie_Ko: Math.round(fs.statSync(q).size / 1e3), meshopt_Ko: Math.round(fs.statSync(mo).size / 1e3) }));
  }
}
