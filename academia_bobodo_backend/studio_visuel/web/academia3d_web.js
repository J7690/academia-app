/**
 * Les six verbes du compositeur, en Three.js.
 *
 * PORTAGE DE `academia3d.py`, PAS UNE REECRITURE. Chaque verbe rend ici la meme
 * forme que son homologue Blender, a partir des MEMES parametres : l'IA n'a rien
 * a apprendre de nouveau, l'invite ne change pas, la validation non plus.
 *
 * POURQUOI CE PORTAGE EXISTE. Mesure du 18/08, banc `bancs/mesure_navigateur.js` :
 * un navigateur SANS carte graphique rend une scene du compositeur a 0,284 s
 * l'image, contre ~1,3 s pour Blender sur une RTX 4090 louee -- 4,6 fois plus
 * vite. S'y ajoute ce qui disparait : une image Docker de 4,47 Go a tirer avant
 * chaque rendu (amorcage mesure de 3 s a plus de 25 minutes selon l'hote), la
 * facturation a l'heure, et une machine sur deux qui meurt avant de demarrer.
 *
 * LA CONVENTION EST DECLAREE UNE SEULE FOIS, ET C'EST DELIBERE.
 *
 * Le depot parle en coordonnees Blender -- Z est la HAUTEUR, Y la PROFONDEUR
 * (negatif = loin) -- et c'est ce que l'invite enseigne au modele. Three.js, lui,
 * a Y vers le haut. Le 14/08, `extruder` construisait son contour dans le plan
 * XY en croyant le dresser : chaque fleche est sortie COUCHEE AU SOL, pointe vers
 * le fond, dans une scene intitulee « Force vers le haut ». Deux couches qui se
 * croyaient d'accord.
 *
 * D'ou `v()` ci-dessous : un seul point de passage, que tout le fichier utilise.
 */
import {
  Scene, Color, PerspectiveCamera, WebGLRenderer, Group, Vector2, Vector3,
  Mesh, MeshBasicMaterial, LatheGeometry, IcosahedronGeometry, ExtrudeGeometry,
  Shape, TubeGeometry, CatmullRomCurve3, PlaneGeometry, Box3,
  AdditiveBlending, DoubleSide,
} from './three.module.js';

/** Blender (x, y, z) avec Z en haut -> Three (x, y_haut, z_vers_le_spectateur). */
export const v = (x, y, z) => new Vector3(x, z, -y);

// ── Le style, repris de `academia3d_style.py` ────────────────────────────
// Ce que l'IA NE decide PAS : couleurs, halo, exposition, epaisseur des traits.
// C'est ce qui fait qu'une capsule ressemble a toutes les autres tout en parlant
// de son sujet.
export const STYLE = {
  BLEU: 0x2f86ff,
  BLEU_VIF: 0x7ab8ff,
  ORANGE: 0xff7a3d,
  FOND: 0x000000,
  OPACITE_VERRE: 0.16,
  // Epaisseur d'arete en fraction du rayon, cf. ARETE_PAR_RAYON.
  ARETE_PAR_RAYON: 0.006,
};

const matiereFilaire = (couleur = STYLE.BLEU) => new MeshBasicMaterial({
  color: couleur, wireframe: true, transparent: true, opacity: 0.95,
  blending: AdditiveBlending, depthWrite: false,
});

// LA SURFACE CONSERVEE DOIT ETRE TRAVERSABLE.
// Le 14/08, le verre n'etait pose que sur le role « sujet » : un becher gardait
// une peau opaque et MASQUAIT la sphere posee dedans. `sculpter` n'a jamais ete
// en cause. Regle depuis : toute surface conservee est du verre.
const matiereVerre = (couleur = STYLE.BLEU) => new MeshBasicMaterial({
  color: couleur, transparent: true, opacity: STYLE.OPACITE_VERRE,
  side: DoubleSide, depthWrite: false, blending: AdditiveBlending,
});

/** Un objet = sa peau de verre + son filaire. Les deux, toujours. */
function habiller(geometrie, couleur, avecVerre = true) {
  const groupe = new Group();
  if (avecVerre) groupe.add(new Mesh(geometrie, matiereVerre(couleur)));
  groupe.add(new Mesh(geometrie, matiereFilaire(couleur)));
  return groupe;
}

// ── Les six verbes ────────────────────────────────────────────────────────

/** Un profil [rayon, hauteur] tourne autour de la verticale. */
export function revolutionner(p, couleur) {
  const profil = (p.profil || []).map(([r, h]) => new Vector2(Math.max(0, r), h));
  if (profil.length < 2) throw new Error('revolutionner : moins de deux points');
  const g = habiller(new LatheGeometry(profil, Math.min(64, Math.max(8, p.tours || 40))), couleur);
  const [x, y, z] = p.position || [0, 0, 0];
  g.position.copy(v(x, y, z));
  return g;
}

/** Un volume facette. Cinq bases, comme en Python -- memes proportions. */
const BASES = {
  ovoide:  [0.78, 0.78, 1.00],
  sphere:  [1.00, 1.00, 1.00],
  galet:   [1.00, 0.72, 0.55],
  goutte:  [0.70, 0.70, 1.35],
  lentille:[1.00, 1.00, 0.32],
};
export function sculpter(p, couleur) {
  const [bx, by, bz] = BASES[p.base] || BASES.ovoide;
  const e = Math.max(0.1, Math.min(8, p.echelle ?? 1));
  const geo = new IcosahedronGeometry(1, Math.max(1, Math.min(3, p.facettes ?? 2)));
  // La deformation, avec la MEME graine qu'en Python : un rendu doit etre
  // reproductible, sinon deux passages donnent deux capsules differentes.
  const d = Math.max(0, Math.min(0.35, p.deformation ?? 0));
  if (d > 0) {
    let graine = (p.graine ?? 0) * 9301 + 49297;
    const pos = geo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      graine = (graine * 9301 + 49297) % 233280;
      const f = 1 + ((graine / 233280) * 2 - 1) * d;
      pos.setXYZ(i, pos.getX(i) * f, pos.getY(i) * f, pos.getZ(i) * f);
    }
  }
  const g = habiller(geo, couleur);
  // Les proportions de la base sont exprimees en (x, y_profondeur, z_hauteur).
  g.scale.set(bx * e, bz * e, by * e);
  const [x, y, z] = p.position || [0, 0, 0];
  g.position.copy(v(x, y, z));
  return g;
}

/** Un contour 2D pousse en epaisseur. DEBOUT, face au spectateur. */
export function extruder(p, couleur) {
  const pts = p.contour || [];
  if (pts.length < 3) throw new Error('extruder : moins de trois points');
  const forme = new Shape();
  forme.moveTo(pts[0][0], pts[0][1]);
  for (const [x, y] of pts.slice(1)) forme.lineTo(x, y);
  forme.closePath();
  const ep = Math.max(0.02, Math.min(3, p.epaisseur ?? 0.25));
  const geo = new ExtrudeGeometry(forme, { depth: ep, bevelEnabled: false });
  // Le contour est trace dans le plan XY de Three -- qui est deja le plan
  // VERTICAL face a la camera. Aucune rotation : c'est la correction du 14/08.
  const g = habiller(geo, couleur);
  const [x, y, z] = p.position || [0, 0, 0];
  g.position.copy(v(x, y, z));
  return g;
}

/** Un squelette de segments, epaissi en volume. Le seul verbe a orientation libre. */
export function silhouetter(p, couleur) {
  const branches = p.segments || [];
  const rayons = p.rayons || [];
  const groupe = new Group();
  let rang = 0;
  for (const branche of branches) {
    if (!Array.isArray(branche) || branche.length < 2) { rang += branche?.length || 0; continue; }
    const points = branche.map(([x, y, z]) => v(x, y, z));
    const courbe = new CatmullRomCurve3(points, false, 'catmullrom', 0.4);
    // Un rayon qui grossit puis diminue donne un fuseau : c'est ainsi qu'on
    // obtient une coque ou un sous-marin. On prend la moyenne des rayons de la
    // branche -- TubeGeometry ne sait pas varier le sien.
    const r = branche.map((_, i) => rayons[rang + i]).filter((x) => typeof x === 'number');
    const moyen = r.length ? r.reduce((a, b) => a + b, 0) / r.length : 0.18;
    groupe.add(habiller(
      new TubeGeometry(courbe, Math.max(12, branche.length * 8),
                       Math.max(0.03, Math.min(2, moyen)), 8, false),
      couleur));
    rang += branche.length;
  }
  if (!groupe.children.length) throw new Error('silhouetter : aucune branche exploitable');
  return groupe;
}

/** Un terrain quadrille. Donne l'echelle, jamais le sujet. */
export function napper(p, couleur) {
  const cote = Math.max(20, Math.min(260, p.cote ?? 190));
  const pas = Math.max(12, Math.min(80, p.pas ?? 46));
  const geo = new PlaneGeometry(cote, cote, pas, pas);
  const amp = Math.max(0, Math.min(5, p.amplitude ?? 1.2));
  const pos = geo.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), y = pos.getY(i);
    pos.setZ(i, Math.sin(x * 0.08) * Math.cos(y * 0.08) * amp);
  }
  geo.computeVertexNormals();
  const m = new Mesh(geo, matiereFilaire(couleur));
  m.rotation.x = -Math.PI / 2;   // a plat, au sol
  const g = new Group(); g.add(m);
  return g;
}

export const VERBES = { revolutionner, sculpter, extruder, silhouetter, napper };

// ── Le cadrage, porte de `academia3d.cadrer_sur` ──────────────────────────
//
// LA DISTANCE EST MESUREE SUR CE QUI EXISTE, jamais choisie d'avance. Le 14/08,
// une distance constante de 9 unites cadrait un becher de 6 unites de large avec
// une focale qui n'en montrait que 3,6 : l'image ne contenait que la paroi.
export const CADRAGE = {
  objet:       { marge: 1.15, balayage: 26, direction: [0.18, -1.0, 0.30] },
  processus:   { marge: 1.25, balayage: 22, direction: [0.30, -1.0, 0.34] },
  comparaison: { marge: 1.22, balayage: 14, direction: [0.05, -1.0, 0.22] },
  structure:   { marge: 1.20, balayage: 24, direction: [0.26, -1.0, 0.42] },
  echelle:     { marge: 1.35, balayage: 34, direction: [0.22, -1.0, 0.50] },
  flux:        { marge: 1.28, balayage: 30, direction: [0.34, -1.0, 0.30] },
};

/**
 * Construit une scene complete et rend une fonction `poser(t)`, t de 0 a 1.
 *
 * Le rendu est DETERMINISTE : l'image i ne depend que de i. C'est ce qui permet
 * de decouper le rendu en plages paralleles sans la moindre derive, la ou une
 * animation temps reel oblige a rejouer depuis le debut.
 */
export function composer(description, largeur, hauteur) {
  const scene = new Scene();
  scene.background = new Color(STYLE.FOND);
  const journal = { faits: [], degradations: [] };

  const intention = CADRAGE[description.intention] ? description.intention : 'objet';
  if (intention !== description.intention) {
    journal.degradations.push(`intention « ${description.intention} » inconnue — ramenee a objet`);
  }

  const produits = [];
  for (const [rang, geste] of (description.gestes || []).entries()) {
    const faire = VERBES[geste.verbe];
    if (!faire) { journal.degradations.push(`geste ${rang} : verbe « ${geste.verbe} » inconnu`); continue; }
    try {
      const couleur = geste.role === 'sujet' ? STYLE.BLEU_VIF : STYLE.BLEU;
      const objet = faire(geste.parametres || {}, couleur);
      scene.add(objet); produits.push(objet);
      journal.faits.push(`${geste.verbe}(${Object.keys(geste.parametres || {}).sort().join(', ')})`);
    } catch (e) {
      journal.degradations.push(`geste ${rang} « ${geste.verbe} » : ${e.message}`);
    }
  }

  const cam = new PerspectiveCamera(38, largeur / hauteur, 0.1, 1000);

  // ON CADRE SUR LE SUJET, PAS SUR L'HORIZON.
  //
  // `napper` produit un terrain de 190 unites de cote. Compte dans la boite
  // englobante, il l'ecrase : la camera recule assez pour contenir 190 unites,
  // et un derrick de 3 unites devient un point.
  //
  // Mesure du 19/08, capsule « le petrole », travail be3b09ba : quatre plans sur
  // six ne montraient QUE la grille du sol. Le derrick, l'oleoduc et la coque du
  // navire -- que l'IA avait pourtant bien decrits, en fuseau -- etaient
  // invisibles. C'est le defaut de la distance fixe retourne : on cadrait sur le
  // decor au lieu du sujet.
  //
  // Le terrain reste dans la scene : il donne l'echelle et la profondeur. Il ne
  // COMMANDE simplement plus le cadrage.
  const cadrables = produits.filter((_, i) =>
    (description.gestes || [])[i]?.verbe !== 'napper');
  const aCadrer = cadrables.length ? cadrables : produits;
  if (cadrables.length !== produits.length) {
    journal.faits.push(`cadrage : ${produits.length - cadrables.length} terrain(s) exclu(s) de la mesure`);
  }

  const boite = new Box3();
  for (const o of aCadrer) boite.expandByObject(o);
  if (aCadrer.length === 0) boite.setFromCenterAndSize(new Vector3(0, 1, 0), new Vector3(4, 4, 4));

  const centre = boite.getCenter(new Vector3());
  const taille = boite.getSize(new Vector3());
  const cadre = CADRAGE[intention];

  // Le champ REEL, calcule -- pas suppose. Cadre vertical : la largeur est la
  // ressource rare, et c'est elle qui a fait deborder le becher.
  const demiV = (cam.fov * Math.PI / 180) / 2;
  const demiH = Math.atan(Math.tan(demiV) * (largeur / hauteur));
  const distance = Math.max(
    (taille.x / 2) / Math.tan(demiH),
    (taille.y / 2) / Math.tan(demiV)) * cadre.marge + taille.z / 2;

  const [dx, dy, dz] = cadre.direction;
  const versCam = v(dx, dy, dz).normalize();
  const rayon = Math.hypot(versCam.x, versCam.z) * Math.max(distance, 1.5);
  const depart = Math.atan2(versCam.z, versCam.x);
  const hauteurCam = versCam.y * Math.max(distance, 1.5);
  const demiBalayage = (cadre.balayage * Math.PI / 180) / 2;

  const poser = (t) => {
    const a = depart - demiBalayage + cadre.balayage * Math.PI / 180 * t;
    cam.position.set(centre.x + rayon * Math.cos(a),
                     centre.y + hauteurCam - taille.y * 0.15 + taille.y * 0.3 * t,
                     centre.z + rayon * Math.sin(a));
    cam.lookAt(centre);
  };
  poser(0);

  journal.faits.push(`cadrage « ${intention} » a ${distance.toFixed(2)} unites`);
  return { scene, cam, poser, journal };
}

/** Le rendu, avec le fond noir et sans lumiere : la matiere brille d'elle-meme.
 *
 * LE CANEVAS EST ATTACHE A LA PAGE, ET CE N'EST PAS UN DETAIL.
 * Sans cette ligne, tout fonctionne et rien ne se voit : le rendu s'execute, le
 * journal annonce ses gestes, les fichiers sortent -- et ils sont noirs, parce
 * que la capture photographie la PAGE, pas le canevas. Mesure du 18/08 :
 * soixante images produites, toutes de 12 998 octets, c'est-a-dire la meme image
 * vide. Un echec parfaitement silencieux, decouvert en REGARDANT les fichiers.
 */
export function creerRendu(largeur, hauteur) {
  const r = new WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  r.setSize(largeur, hauteur, false);
  r.setClearColor(STYLE.FOND, 1);
  if (typeof document !== 'undefined' && document.body) {
    document.body.appendChild(r.domElement);
  }
  return r;
}
