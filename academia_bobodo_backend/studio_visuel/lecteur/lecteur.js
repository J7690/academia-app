/**
 * Le lecteur de capsule — la capsule est JOUÉE par l'appareil, pas filmée.
 *
 * FUSION, PAS RÉÉCRITURE. Les six verbes viennent de `web/academia3d_web.js`
 * (mêmes paramètres, mêmes proportions, même convention d'axes : l'invite et la
 * validation n'ont rien à réapprendre). Le style vient du prototype du 28/10
 * (`prototype_lecture_appareil/`), validé par Jocelyn sur son TECNO : brume,
 * halo, verre à effet Fresnel, sommets lumineux, foyer rouge et particules.
 *
 * Mesure qui a décidé (28/10, TECNO Android 10, Mali-G52 MC2) : palier léger
 * 854×480 à 58,6 i/s en lecture réelle ; palier complet 1280×720 à 14,4 i/s
 * au banc. D'où les deux paliers ci-dessous et la bascule automatique.
 *
 * LE RENDU EST UNE FONCTION PURE DU TEMPS : l'image de l'instant t ne dépend
 * que de t. C'est ce qui permet de lire en direct ET d'exporter image par image
 * le même film, et de vérifier une capsule sans la jouer.
 *
 * Formats acceptés (voir FORMAT_CAPSULE_V2.md) :
 *   v0 — scènes à `archetype` (avant le 12/08) : rejouées en repli texte, et dit ;
 *   v1 — scènes à `gestes` (12/08 → 05/09) : rejouées avec le nouveau style ;
 *   v2 — v1 + `decor`, `foyer`, `voix` par scène, `objets` résolus.
 */
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

// ── Paliers, réglés sur la mesure du TECNO ───────────────────────────────
export const PALIERS = {
  complet: { L: 1280, H: 720, bloom: 1.0, echantillons: 4, particules: 1.0, octaves: 4 },
  leger:   { L: 854,  H: 480, bloom: 0.5, echantillons: 0, particules: 0.45, octaves: 3 },
};

/** Blender (x, y, z) avec Z en haut -> Three (x, y_haut, z_vers_le_spectateur).
 *  La convention de l'invite ; un seul point de passage (cf. academia3d_web.js). */
const v = (x, y, z) => new THREE.Vector3(x, z, -y);

const BLEU = new THREE.Color(0x2f7dff);
const BLEU_VIF = new THREE.Color(0x8cc2ff);
const ROUGE = new THREE.Color(0xff2a10);
const ORANGE = new THREE.Color(0xff8a3a);
const BASE_OBJETS = 'https://huggingface.co/datasets/allenai/objaverse/resolve/main/';

// ── Normalisation : une seule forme interne, quel que soit le format ──────
const DECORS = ['gestes', 'corps', 'gouttes', 'repli'];
const INTENTIONS = ['objet', 'processus', 'comparaison', 'structure', 'echelle', 'flux'];

export function normaliserCapsule(brut) {
  const journal = [];
  const scenes = [];
  let debut = 0;
  for (const [i, s] of (brut.scenes || []).entries()) {
    // `pour: "pod"` : gestes de repli que la validation ajoute pour la chaîne
    // GPU, qui ignore les décors. Sur l'appareil, le décor les remplace.
    const gestes = Array.isArray(s.gestes) ? s.gestes.filter((g) => g && g.verbe && g.pour !== 'pod') : [];
    let decor = DECORS.includes(s.decor) ? s.decor : (gestes.length ? 'gestes' : 'repli');
    if (s.decor && !DECORS.includes(s.decor)) journal.push(`scène ${i + 1} : décor « ${s.decor} » inconnu — ramené à ${decor}`);
    if (decor === 'repli' && s.archetype) journal.push(`scène ${i + 1} : archétype v0 « ${s.archetype} » non porté — repli texte`);
    const duree = Math.max(1.5, Number(s.duree_s ?? s.duree ?? 6) || 6);
    scenes.push({
      id: s.id || `s${i + 1}`, rang: i, decor, gestes,
      intention: INTENTIONS.includes(s.intention) ? s.intention : 'objet',
      foyer: s.foyer ?? null, flux: !!s.flux, plan: s.plan || null,
      narration: (s.narration || '').trim(), voix: s.voix || null,
      texteRepli: String(s.parametres?.texte || s.sujet || s.titre || brut.titre || '').slice(0, 40),
      duree, debut,
    });
    debut += duree;
  }
  const version = scenes.some((s) => s.decor === 'corps' || s.decor === 'gouttes' || s.voix) ? 2
    : (scenes.some((s) => s.gestes.length) ? 1 : 0);
  return { titre: brut.titre || '', version, scenes, duree: debut, journal, objets: brut.objets || null, voix: brut.voix || null };
}

/** La voix commande l'image : on recale les durées sur l'audio réellement décodé.
 *  0,45 s de respiration après chaque scène, comme `narration.py` (SILENCE_FIN_S).
 *  Une scène dont la voix n'est pas encore arrivée garde sa durée provisoire :
 *  on peut donc recaler PENDANT la lecture sans toucher au plan en cours. */
export const RESPIRATION_S = 0.45;
export function recalerSurVoix(capsule, durees) {
  let debut = 0;
  for (const [i, s] of capsule.scenes.entries()) {
    if (durees[i] > 0) s.duree = Math.max(1.5, durees[i] + RESPIRATION_S);
    s.debut = debut; debut += s.duree;
  }
  capsule.duree = debut;
  return capsule;
}

/** Ralentit une voix SANS la rendre plus grave (superposition de fenêtres
 *  alignées par corrélation, dite WSOLA). Remplace l'`atempo=0.88` que ffmpeg
 *  appliquait sur LWS : « au débit natif la voix est trop rapide pour du
 *  pédagogique » (narration.py, mesure du Smart Whiteboard).
 *  Calcul allégé (pas de 2 dans la recherche, de 4 dans la corrélation) : une
 *  scène de 10 s se traite en une fraction de seconde, même sur téléphone. */
export function ralentir(tampon, facteur = 0.88) {
  const sr = tampon.sampleRate, n = tampon.length, canaux = tampon.numberOfChannels;
  const x = new Float32Array(n);
  for (let c = 0; c < canaux; c++) { const d = tampon.getChannelData(c); for (let i = 0; i < n; i++) x[i] += d[i] / canaux; }
  const N = Math.max(256, Math.round(sr * 0.03) & ~1), hSortie = N / 2, hEntree = hSortie * facteur, tol = Math.round(N / 4);
  const fen = new Float32Array(N);
  for (let i = 0; i < N; i++) fen[i] = 0.5 - 0.5 * Math.cos(2 * Math.PI * i / (N - 1));
  const longueur = Math.ceil(n / facteur) + N;
  const y = new Float32Array(longueur), poids = new Float32Array(longueur);
  let precedent = 0, fin = 0;
  for (let k = 0; ; k++) {
    const sortie = k * hSortie, nominal = Math.round(k * hEntree);
    if (nominal + N + tol >= n || sortie + N >= longueur) break;
    let depart = nominal;
    if (k > 0) {
      const ref = precedent + hSortie;
      if (ref + N / 2 < n) {
        let meilleur = -Infinity;
        for (let d = -tol; d <= tol; d += 2) {
          const s = nominal + d; if (s < 0) continue;
          let c = 0; for (let i = 0; i < N / 2; i += 4) c += x[s + i] * x[ref + i];
          if (c > meilleur) { meilleur = c; depart = s; }
        }
      }
    }
    for (let i = 0; i < N; i++) { y[sortie + i] += x[depart + i] * fen[i]; poids[sortie + i] += fen[i]; }
    precedent = depart; fin = sortie + N;
  }
  const out = new AudioBuffer({ length: Math.max(1, fin), numberOfChannels: 1, sampleRate: sr });
  const o = out.getChannelData(0);
  for (let i = 0; i < fin; i++) o[i] = poids[i] > 1e-3 ? y[i] / poids[i] : 0;
  return out;
}

/** Sous-titres : chaque phrase reçoit une part de sa scène, au prorata de sa longueur. */
export function phrasesDe(capsule) {
  const out = [];
  for (const s of capsule.scenes) {
    if (!s.narration) continue;
    const morceaux = s.narration.match(/[^.!?]+[.!?]+|[^.!?]+$/g) || [s.narration];
    const total = morceaux.reduce((a, m) => a + m.trim().length, 0) || 1;
    let t = s.debut;
    for (const m of morceaux) {
      const d = s.duree * m.trim().length / total;
      if (m.trim()) out.push({ debut: t, fin: t + d, texte: m.trim() });
      t += d;
    }
  }
  return out;
}

// ── Matières : le style, que l'IA ne décide pas ──────────────────────────
const BRUIT = `
float h21(vec2 p){ p = fract(p*vec2(123.34,456.21)); p += dot(p,p+45.32); return fract(p.x*p.y); }
float bruit(vec2 p){ vec2 i=floor(p), f=fract(p); vec2 u=f*f*(3.0-2.0*f);
  return mix(mix(h21(i),h21(i+vec2(1,0)),u.x), mix(h21(i+vec2(0,1)),h21(i+vec2(1,1)),u.x), u.y); }
uniform float uOctaves;
float fbm(vec2 p){ float s=0.0, a=0.5; for(int i=0;i<4;i++){ if(float(i)>=uOctaves) break; s+=a*bruit(p); p*=2.03; a*=0.5; } return s; }
`;

function fondBrume(communs, teinte, bandes) {
  const m = new THREE.ShaderMaterial({
    uniforms: { ...communs, uTeinte: { value: teinte }, uBandes: { value: bandes } },
    vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.9999, 1.0); }`,
    fragmentShader: BRUIT + `
      uniform float uTemps; uniform vec3 uTeinte; uniform float uBandes; varying vec2 vUv;
      void main(){ vec2 p = vec2(vUv.x*2.2, vUv.y*1.2);
        float n = fbm(p*1.6 + vec2(uTemps*0.035, 0.0));
        float b = sin((vUv.y + n*0.35)*uBandes + uTemps*0.12)*0.5+0.5;
        b = smoothstep(0.35, 1.0, b) * (0.55 + 0.45*fbm(p*3.0 - uTemps*0.02));
        float vig = smoothstep(1.15, 0.25, length(vUv-vec2(0.5,0.48))*1.6);
        gl_FragColor = vec4(vec3(0.004,0.010,0.030) + uTeinte*b*0.42*vig + uTeinte*0.05*vig, 1.0); }`,
    depthWrite: false, depthTest: false,
  });
  const q = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), m);
  q.frustumCulled = false; q.renderOrder = -10; q.userData.decor = true;
  return q;
}

// Arêtes et sommets : bleu, virant au rouge près du foyer. Le foyer est en
// coordonnées du MONDE, pour servir aussi bien le corps que n'importe quel geste.
function matiereAretes(communs, chaleur, opacite) {
  return new THREE.ShaderMaterial({
    uniforms: { ...communs, ...chaleur, uBleu: { value: BLEU }, uRouge: { value: ROUGE }, uOpacite: { value: opacite } },
    vertexShader: `uniform vec3 uFoyer; uniform float uRayon; varying float vChaud; varying float vProf;
      void main(){ vec4 pw = modelMatrix*vec4(position,1.0);
        vChaud = uRayon > 0.0 ? 1.0 - smoothstep(0.0, uRayon, distance(pw.xyz, uFoyer)) : 0.0;
        vec4 mv = viewMatrix*pw; vProf = -mv.z; gl_Position = projectionMatrix*mv; }`,
    fragmentShader: `uniform vec3 uBleu, uRouge; uniform float uOpacite, uTemps, uChaleur; varying float vChaud; varying float vProf;
      void main(){ float k = vChaud*uChaleur; float pulse = 0.8 + 0.2*sin(uTemps*5.0);
        vec3 c = mix(uBleu, uRouge*(1.6*pulse), k);
        float a = uOpacite*(0.6 + 0.9*k) * clamp(14.0/vProf, 0.25, 1.0);
        gl_FragColor = vec4(c*a, 1.0); }`,
    transparent: true, blending: THREE.AdditiveBlending, depthWrite: false,
  });
}
function matierePoints(communs, chaleur, taille, opacite) {
  return new THREE.ShaderMaterial({
    uniforms: { ...communs, ...chaleur, uTaille: { value: taille }, uCouleur: { value: BLEU_VIF }, uOpacite: { value: opacite }, uRouge: { value: ORANGE } },
    vertexShader: `uniform float uTaille, uEchelle, uRayon; uniform vec3 uFoyer; varying float vChaud;
      void main(){ vec4 pw = modelMatrix*vec4(position,1.0);
        vChaud = uRayon > 0.0 ? 1.0 - smoothstep(0.0, uRayon, distance(pw.xyz, uFoyer)) : 0.0;
        vec4 mv = viewMatrix*pw; gl_PointSize = uTaille*uEchelle/max(0.1, -mv.z); gl_Position = projectionMatrix*mv; }`,
    fragmentShader: `uniform vec3 uCouleur, uRouge; uniform float uOpacite, uChaleur; varying float vChaud;
      void main(){ float d = length(gl_PointCoord-0.5); if(d>0.5) discard;
        float a = smoothstep(0.5,0.0,d)*uOpacite; gl_FragColor = vec4(mix(uCouleur, uRouge*1.8, vChaud*uChaleur)*a, 1.0); }`,
    transparent: true, blending: THREE.AdditiveBlending, depthWrite: false,
  });
}
function matiereVerre(couleur, force) {
  return new THREE.ShaderMaterial({
    uniforms: { uCouleur: { value: couleur }, uForce: { value: force } },
    vertexShader: `varying vec3 vN; varying vec3 vV;
      void main(){ vec4 mv = modelViewMatrix*vec4(position,1.0); vN = normalize(normalMatrix*normal); vV = normalize(-mv.xyz);
        gl_Position = projectionMatrix*mv; }`,
    fragmentShader: `uniform vec3 uCouleur; uniform float uForce; varying vec3 vN; varying vec3 vV;
      void main(){ float f = pow(1.0 - abs(dot(normalize(vN), normalize(vV))), 2.6); gl_FragColor = vec4(uCouleur*f*uForce, 1.0); }`,
    transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide,
  });
}

/** Un objet = peau de verre + arêtes + sommets. Un maillage dense ne garde que
 *  ses arêtes marquées : sinon le halo le fond en aplat blanc (ETAT §4.2 bis). */
function habiller(geo, ctx, role) {
  if (!geo.attributes.normal) geo.computeVertexNormals();
  const g = new THREE.Group();
  const sujet = role === 'sujet';
  const triangles = (geo.index ? geo.index.count : geo.attributes.position.count) / 3;
  const dense = triangles > 3000;
  g.add(new THREE.Mesh(geo, matiereVerre(sujet ? BLEU_VIF : BLEU, sujet ? 0.45 : 0.3)));
  g.add(new THREE.LineSegments(dense ? new THREE.EdgesGeometry(geo, 24) : new THREE.WireframeGeometry(geo),
    matiereAretes(ctx.communs, ctx.chaleur, dense ? 0.3 : (sujet ? 0.3 : 0.2))));
  if (!dense) g.add(new THREE.Points(geo, matierePoints(ctx.communs, ctx.chaleur, 0.006, sujet ? 0.45 : 0.3)));
  return g;
}

// ── Le foyer : braises qui bouillonnent, braises qui s'échappent ─────────
function foyerEtFlux(communs, nBraises, nFuite) {
  const g = new THREE.Group();
  const graine = (i, k) => { const x = Math.sin(i * 127.1 + k * 311.7) * 43758.5453; return x - Math.floor(x); };
  const nuage = (n, decalage) => {
    const geo = new THREE.BufferGeometry();
    const a = new Float32Array(n * 4);
    for (let i = 0; i < n; i++) for (let k = 0; k < 4; k++) a[i * 4 + k] = graine(i + decalage, k);
    geo.setAttribute('position', new THREE.BufferAttribute(new Float32Array(n * 3), 3));
    geo.setAttribute('aAlea', new THREE.BufferAttribute(a, 4));
    return geo;
  };
  const matB = new THREE.ShaderMaterial({
    uniforms: { ...communs, uCentre: { value: new THREE.Vector3() }, uTaille: { value: 0.035 }, uAmpleur: { value: 0.4 }, uForce: { value: 0 } },
    vertexShader: `attribute vec4 aAlea; uniform vec3 uCentre; uniform float uTemps, uTaille, uEchelle, uAmpleur, uForce; varying float vA;
      void main(){ float t = uTemps*(0.4+aAlea.w*0.8) + aAlea.x*6.283;
        vec3 dir = normalize(vec3(sin(aAlea.x*6.283+t*0.7), cos(aAlea.y*6.283+t*0.5), sin(aAlea.z*6.283-t*0.6)));
        vec3 p = uCentre + dir*uAmpleur*pow(aAlea.w,0.6)*(0.75+0.25*sin(t*1.3))*vec3(1.4,1.0,0.9);
        vec4 mv = modelViewMatrix*vec4(p,1.0); vA = (1.0-aAlea.w*0.6)*uForce;
        gl_PointSize = uTaille*uEchelle*(0.5+aAlea.y)/max(0.1,-mv.z); gl_Position = projectionMatrix*mv; }`,
    fragmentShader: `varying float vA; void main(){ float d = length(gl_PointCoord-0.5); if(d>0.5) discard;
        float a = smoothstep(0.5,0.0,d)*vA; gl_FragColor = vec4(mix(vec3(1.0,0.12,0.02), vec3(1.0,0.55,0.2), vA*0.6)*a*1.6, 1.0); }`,
    transparent: true, blending: THREE.AdditiveBlending, depthWrite: false,
  });
  const matF = new THREE.ShaderMaterial({
    uniforms: { ...communs, uCentre: { value: new THREE.Vector3() }, uDirection: { value: new THREE.Vector3(1, 0, 0) },
      uLongueur: { value: 3.4 }, uTaille: { value: 0.02 }, uFlux: { value: 0 } },
    vertexShader: `attribute vec4 aAlea; uniform vec3 uCentre, uDirection; uniform float uTemps, uLongueur, uTaille, uEchelle, uFlux; varying float vA;
      void main(){ float av = fract(uTemps*(0.05+aAlea.x*0.09) + aAlea.y);
        vec3 ecart = normalize(vec3(aAlea.z-0.5, aAlea.w-0.5, aAlea.x-0.5)) * (0.12 + 0.6*av) * (0.4+aAlea.w);
        vec3 p = uCentre + uDirection*av*uLongueur*(0.4+aAlea.z) + ecart + 0.09*vec3(sin(uTemps*2.0+aAlea.x*20.0), cos(uTemps*1.7+aAlea.y*20.0), 0.0);
        vec4 mv = modelViewMatrix*vec4(p,1.0); vA = (1.0-av)*smoothstep(0.0,0.08,av)*uFlux;
        gl_PointSize = uTaille*uEchelle*(0.4+aAlea.w)/max(0.1,-mv.z); gl_Position = projectionMatrix*mv; }`,
    fragmentShader: `varying float vA; void main(){ float d = length(gl_PointCoord-0.5); if(d>0.5) discard;
        gl_FragColor = vec4(vec3(1.0,0.18,0.06)*smoothstep(0.5,0.0,d)*vA*1.4, 1.0); }`,
    transparent: true, blending: THREE.AdditiveBlending, depthWrite: false,
  });
  for (const [geo, mat] of [[nuage(nBraises, 0), matB], [nuage(nFuite, 9000), matF]]) {
    const p = new THREE.Points(geo, mat); p.frustumCulled = false; g.add(p);
  }
  g.userData.decor = true;
  return { groupe: g, braises: matB, fuite: matF };
}

// ── La grille et sa lueur qui affleure ───────────────────────────────────
function grille(communs, cote = 70, pas = 70, amplitude = 0.12, lueurOn = true) {
  const g = new THREE.Group(); g.userData.decor = true;
  if (lueurOn) {
    const lueur = new THREE.Mesh(new THREE.PlaneGeometry(cote * 1.3, cote * 1.3), new THREE.ShaderMaterial({
      uniforms: { ...communs },
      vertexShader: `varying vec3 vP; void main(){ vP = (modelMatrix*vec4(position,1.0)).xyz; gl_Position = projectionMatrix*viewMatrix*vec4(vP,1.0); }`,
      fragmentShader: BRUIT + `uniform float uTemps; varying vec3 vP;
        void main(){ float n = fbm(vP.xz*0.16 + vec2(uTemps*0.03, -uTemps*0.02));
          gl_FragColor = vec4(vec3(1.0,0.10,0.03)*smoothstep(0.52,0.85,n)*0.9*smoothstep(42.0,6.0,length(vP.xz)), 1.0); }`,
      transparent: true, blending: THREE.AdditiveBlending, depthWrite: false,
    }));
    lueur.rotation.x = -Math.PI / 2; lueur.position.y = -0.06; g.add(lueur);
  }
  const plan = new THREE.PlaneGeometry(cote, cote, pas, pas);
  g.add(new THREE.LineSegments(new THREE.WireframeGeometry(plan), new THREE.ShaderMaterial({
    uniforms: { ...communs, uAmp: { value: amplitude } },
    vertexShader: BRUIT + `uniform float uTemps, uAmp; varying float vChaud; varying float vProf;
      void main(){ vec3 p = position.xzy; p.z = -p.z;
        p.y = uAmp*sin(p.x*0.25+uTemps*0.4)*cos(p.z*0.21);
        vChaud = smoothstep(0.52, 0.85, fbm(p.xz*0.16 + vec2(uTemps*0.03, -uTemps*0.02)));
        vec4 mv = modelViewMatrix*vec4(p,1.0); vProf = -mv.z; gl_Position = projectionMatrix*mv; }`,
    fragmentShader: `varying float vChaud; varying float vProf;
      void main(){ float loin = clamp(1.0 - vProf/38.0, 0.0, 1.0);
        gl_FragColor = vec4(mix(vec3(0.16,0.42,1.0)*0.55, vec3(1.0,0.22,0.08)*1.2, vChaud)*loin*loin, 1.0); }`,
    transparent: true, blending: THREE.AdditiveBlending, depthWrite: false,
  })));
  return g;
}

// ── Texte 3D : un panneau lumineux tourné vers la caméra ─────────────────
// Le verbe `ecrire` manquait au moteur navigateur (ETAT §4.2 ter) : chaque
// occurrence faisait perdre son texte à la scène. Pas de police 3D à embarquer :
// une toile 2D suffit, et elle passe dans le halo comme le reste.
function panneauTexte(texte, hauteur, couleur = '#cfe3ff') {
  const toile = document.createElement('canvas');
  const c = toile.getContext('2d');
  const px = 96;
  c.font = `600 ${px}px Poppins, "IBM Plex Sans", sans-serif`;
  const l = Math.min(2048, Math.ceil(c.measureText(texte).width + px));
  toile.width = l; toile.height = Math.round(px * 1.5);
  c.font = `600 ${px}px Poppins, "IBM Plex Sans", sans-serif`;
  c.textAlign = 'center'; c.textBaseline = 'middle';
  c.shadowColor = '#3f8cff'; c.shadowBlur = px * 0.25; c.fillStyle = couleur;
  c.fillText(texte, l / 2, toile.height / 2);
  const tex = new THREE.CanvasTexture(toile); tex.colorSpace = THREE.SRGBColorSpace;
  // Teinte atténuée : à pleine intensité, le halo faisait baver le texte (mesuré
  // le 28/10 sur « 100 m » : 59 % de l'image allumée, lettres illisibles de près).
  const m = new THREE.Mesh(new THREE.PlaneGeometry(hauteur * l / toile.height, hauteur),
    new THREE.MeshBasicMaterial({ map: tex, color: 0x6f86a8, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  m.userData.face = true;
  return m;
}

// ── Les verbes, portés de academia3d_web.js (mêmes paramètres) ───────────
const BASES = { ovoide: [0.78, 0.78, 1.00], sphere: [1, 1, 1], galet: [1.00, 0.72, 0.55], goutte: [0.70, 0.70, 1.35], lentille: [1.00, 1.00, 0.32] };
const placer = (o, p) => { const [x, y, z] = p.position || [0, 0, 0]; o.position.copy(v(x ?? 0, y ?? 0, z ?? 0)); return o; };

const VERBES = {
  revolutionner(p, ctx, role) {
    const profil = (p.profil || []).map(([r, h]) => new THREE.Vector2(Math.max(0, r), h));
    if (profil.length < 2) throw new Error('moins de deux points');
    return placer(habiller(new THREE.LatheGeometry(profil, Math.min(64, Math.max(8, p.tours || 40))), ctx, role), p);
  },
  sculpter(p, ctx, role) {
    const [bx, by, bz] = BASES[p.base] || BASES.ovoide;
    const e = Math.max(0.1, Math.min(8, p.echelle ?? 1));
    const geo = new THREE.IcosahedronGeometry(1, Math.max(1, Math.min(3, p.facettes ?? 2)));
    const d = Math.max(0, Math.min(0.35, p.deformation ?? 0));
    if (d > 0) {
      let graine = (p.graine ?? 0) * 9301 + 49297; const pos = geo.attributes.position;
      for (let i = 0; i < pos.count; i++) {
        graine = (graine * 9301 + 49297) % 233280;
        const f = 1 + ((graine / 233280) * 2 - 1) * d;
        pos.setXYZ(i, pos.getX(i) * f, pos.getY(i) * f, pos.getZ(i) * f);
      }
    }
    const g = habiller(geo, ctx, role);
    g.scale.set(bx * e, bz * e, by * e);
    return placer(g, p);
  },
  extruder(p, ctx, role) {
    const pts = p.contour || [];
    if (pts.length < 3) throw new Error('moins de trois points');
    const forme = new THREE.Shape(); forme.moveTo(pts[0][0], pts[0][1]);
    for (const [x, y] of pts.slice(1)) forme.lineTo(x, y);
    forme.closePath();
    const ep = Math.max(0.02, Math.min(3, p.epaisseur ?? 0.25));
    return placer(habiller(new THREE.ExtrudeGeometry(forme, { depth: ep, bevelEnabled: false }), ctx, role), p);
  },
  silhouetter(p, ctx, role) {
    const branches = p.segments || [], rayons = p.rayons || [];
    const g = new THREE.Group(); let rang = 0;
    for (const b of branches) {
      if (!Array.isArray(b) || b.length < 2) { rang += b?.length || 0; continue; }
      const courbe = new THREE.CatmullRomCurve3(b.map(([x, y, z]) => v(x, y, z)), false, 'catmullrom', 0.4);
      const r = b.map((_, i) => rayons[rang + i]).filter((x) => typeof x === 'number');
      const moyen = r.length ? r.reduce((a, c) => a + c, 0) / r.length : 0.18;
      g.add(habiller(new THREE.TubeGeometry(courbe, Math.max(12, b.length * 8), Math.max(0.03, Math.min(2, moyen)), 8, false), ctx, role));
      rang += b.length;
    }
    if (!g.children.length) throw new Error('aucune branche exploitable');
    return g;
  },
  napper(p, ctx) {
    const cote = Math.max(20, Math.min(260, p.cote ?? 190));
    // Le pas du dépôt (46 sur 190) donne des mailles de 4 unités : on garde
    // la maille de la référence (1 unité près du sujet), bornée pour le mobile.
    return grille(ctx.communs, Math.min(cote, 90), Math.min(90, Math.round(Math.min(cote, 90))), Math.max(0, Math.min(1, (p.amplitude ?? 1.2) * 0.1)));
  },
  ecrire(p) {
    const texte = String(p.texte || '').slice(0, 60);
    if (!texte.trim()) throw new Error('texte vide');
    return placer(panneauTexte(texte, Math.max(0.2, Math.min(3, p.taille ?? 0.6))), p);
  },
  convoquer(p, ctx, role) {
    const o = ctx.objets.get(p.terme || p.fichier);
    if (!o) throw new Error(`aucun maillage pour « ${p.terme} »`);
    const g = new THREE.Group();
    o.scene.updateMatrixWorld(true);
    o.scene.traverse((n) => {
      if (n.isMesh && n.geometry) {
        const geo = n.geometry.clone(); geo.applyMatrix4(n.matrixWorld);
        g.add(habiller(geo, ctx, role));
      }
    });
    const boite = new THREE.Box3().setFromObject(g), dim = boite.getSize(new THREE.Vector3());
    const plus = Math.max(dim.x, dim.y, dim.z) || 1, taille = Math.max(0.2, Math.min(12, p.taille ?? 2));
    g.scale.setScalar(taille / plus);
    g.position.sub(boite.getCenter(new THREE.Vector3()).multiplyScalar(taille / plus));
    const enveloppe = new THREE.Group(); enveloppe.add(g);
    ctx.attributions.add(o.attribution);
    return placer(enveloppe, p);
  },
};
export const VERBES_CONNUS = Object.keys(VERBES);

// ── Cadrage (porté de academia3d_web.js) : mesuré sur ce qui existe ──────
const CADRAGE = {
  objet: { marge: 1.15, balayage: 26, direction: [0.18, -1.0, 0.30] },
  processus: { marge: 1.25, balayage: 22, direction: [0.30, -1.0, 0.34] },
  comparaison: { marge: 1.22, balayage: 14, direction: [0.05, -1.0, 0.22] },
  structure: { marge: 1.20, balayage: 24, direction: [0.26, -1.0, 0.42] },
  echelle: { marge: 1.35, balayage: 34, direction: [0.22, -1.0, 0.50] },
  flux: { marge: 1.28, balayage: 30, direction: [0.34, -1.0, 0.30] },
};
function cadreur(objets, intention, aspect, fov) {
  const boite = new THREE.Box3();
  for (const o of objets) boite.expandByObject(o);
  if (boite.isEmpty()) boite.setFromCenterAndSize(new THREE.Vector3(0, 1, 0), new THREE.Vector3(4, 4, 4));
  const centre = boite.getCenter(new THREE.Vector3()), taille = boite.getSize(new THREE.Vector3());
  const cadre = CADRAGE[intention] || CADRAGE.objet;
  const demiV = (fov * Math.PI / 180) / 2, demiH = Math.atan(Math.tan(demiV) * aspect);
  const distance = Math.max((taille.x / 2) / Math.tan(demiH), (taille.y / 2) / Math.tan(demiV)) * cadre.marge + taille.z / 2;
  const [dx, dy, dz] = cadre.direction, versCam = v(dx, dy, dz).normalize();
  const d = Math.max(distance, 1.5), rayon = Math.hypot(versCam.x, versCam.z) * d;
  const depart = Math.atan2(versCam.z, versCam.x), hauteur = versCam.y * d, demi = (cadre.balayage * Math.PI / 180) / 2;
  return {
    centre, taille, distance,
    poser(cam, t) {
      const a = depart - demi + cadre.balayage * Math.PI / 180 * t;
      cam.position.set(centre.x + rayon * Math.cos(a), centre.y + hauteur - taille.y * 0.15 + taille.y * 0.3 * t, centre.z + rayon * Math.sin(a));
      cam.lookAt(centre);
    },
  };
}
const lisse = (x) => x * x * (3 - 2 * x);

// ── Construction d'une scène ─────────────────────────────────────────────
function construireScene(s, ctx) {
  const scene = new THREE.Scene();
  const journal = { faits: [], degradations: [] };
  const chaleur = { uFoyer: { value: new THREE.Vector3() }, uRayon: { value: 0 }, uChaleur: { value: 0 } };
  const c = { ...ctx, chaleur };
  scene.add(fondBrume(ctx.communs, new THREE.Color(s.decor === 'gouttes' ? 0x1a4fb8 : 0x1f5fd0), s.decor === 'gouttes' ? 6 : 9));
  const poses = [];
  let foyer = null, cadre = null, regler = () => {};

  if (s.decor === 'corps' && ctx.corps) {
    const r = decorCorps(scene, c, s); foyer = r.foyer; regler = r.regler; cadre = r.cadre;
    journal.faits.push(`décor corps, foyer ${typeof s.foyer === 'string' ? s.foyer : 'thorax'}`);
  } else if (s.decor === 'corps') {
    journal.degradations.push('décor corps demandé mais corps.json absent — gestes seuls');
  }
  if (s.decor === 'gouttes') {
    const r = decorGouttes(scene, c, s); regler = r.regler; cadre = r.cadre;
    journal.faits.push('décor gouttes');
  }

  const gestes = s.decor === 'repli'
    ? [{ verbe: 'napper', parametres: { cote: 60 } }, { verbe: 'ecrire', role: 'sujet', parametres: { texte: s.texteRepli || '…', taille: 0.55, position: [0, 0, 1.2] } }]
    : s.gestes;
  for (const [rang, g] of gestes.entries()) {
    const faire = VERBES[g.verbe];
    if (!faire) { journal.degradations.push(`geste ${rang} : verbe « ${g.verbe} » inconnu`); continue; }
    try {
      const o = faire(g.parametres || {}, c, g.role);
      scene.add(o); poses.push([o, g.verbe, g.role]);
      journal.faits.push(g.verbe);
    } catch (e) {
      journal.degradations.push(`geste ${rang} « ${g.verbe} » : ${e.message}`);
    }
  }
  if (s.decor !== 'corps' && s.decor !== 'gouttes' && !poses.some(([, vb]) => vb !== 'napper')) {
    // Rien n'a tenu : on montre au moins le sujet, et on le dit.
    journal.degradations.push('aucun geste n\'a produit d\'objet — repli texte');
    const o = VERBES.ecrire({ texte: s.texteRepli || '…', taille: 0.55, position: [0, 0, 1.2] });
    scene.add(o); poses.push([o, 'ecrire', 'sujet']);
  }
  scene.updateMatrixWorld(true);

  // Foyer sur un geste : au centre du sujet (v2, `foyer: "sujet"`).
  if (!foyer && s.foyer) {
    const cible = poses.find(([, vb, role]) => role === 'sujet' && vb !== 'napper') || poses.find(([, vb]) => vb !== 'napper');
    if (cible) {
      const b = new THREE.Box3().setFromObject(cible[0]);
      const t = b.getSize(new THREE.Vector3());
      foyer = { centre: b.getCenter(new THREE.Vector3()), rayon: Math.max(t.x, t.y, t.z) * 0.35, direction: new THREE.Vector3(0, 1, 0.2).normalize() };
    } else journal.degradations.push('foyer demandé sans objet où se loger — ignoré');
  }
  let ff = null;
  if (foyer) {
    ff = foyerEtFlux(ctx.communs, Math.round(700 * ctx.palier.particules), Math.round(900 * ctx.palier.particules));
    scene.add(ff.groupe);
    chaleur.uFoyer.value.copy(foyer.centre); chaleur.uRayon.value = foyer.rayon;
    ff.braises.uniforms.uCentre.value.copy(foyer.centre); ff.braises.uniforms.uAmpleur.value = foyer.rayon * 0.62;
    ff.fuite.uniforms.uCentre.value.copy(foyer.centre); ff.fuite.uniforms.uDirection.value.copy(foyer.direction);
    ff.fuite.uniforms.uLongueur.value = foyer.longueur || foyer.rayon * 5;
  }

  if (!cadre) {
    const cadrables = poses.filter(([, vb]) => vb !== 'napper').map(([o]) => o);
    cadre = cadreur(cadrables.length ? cadrables : poses.map(([o]) => o), s.intention, ctx.aspect, ctx.fov);
    journal.faits.push(`cadrage « ${s.intention} » à ${cadre.distance.toFixed(1)} u`);
  }
  const faces = []; scene.traverse((n) => { if (n.userData.face) faces.push(n); });
  // Un décor porte son sujet (le corps, les gouttes) : il compte comme un objet.
  const objetsDecor = (s.decor === 'corps' && ctx.corps) || s.decor === 'gouttes' ? 1 : 0;
  return {
    scene, journal, objets: poses.length + objetsDecor,
    regler(local, t, cam) {
      regler(local, t);
      cadre.poser(cam, lisse(Math.min(1, Math.max(0, local))));
      for (const f of faces) f.quaternion.copy(cam.quaternion);
      const monte = Math.min(1, local * 2.5);
      chaleur.uChaleur.value = foyer ? monte : 0;
      if (ff) { ff.braises.uniforms.uForce.value = monte; ff.fuite.uniforms.uFlux.value = (s.flux ? 1 : 0.25) * Math.min(1, local * 3); }
    },
  };
}

// Décor « corps » — référence, image 1. Le corps est en coordonnées d'origine
// (pieds en 0, tête en 1), tourné et allongé d'un bloc.
const ZONES = { tete: [0, 0.925, 0.0, 0.085], thorax: [0, 0.72, 0.03, 0.13], ventre: [0, 0.6, 0.04, 0.11], bassin: [0, 0.5, 0.0, 0.1], jambes: [0.06, 0.25, 0.0, 0.12], bras: [0.17, 0.62, 0.0, 0.08] };
function decorCorps(scene, c, s) {
  const d = c.corps, e = d.echelle, pos = new Float32Array(d.v.length);
  for (let i = 0; i < d.v.length; i++) pos[i] = d.v[i] / e;
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3)); geo.setIndex(d.f); geo.computeVertexNormals();
  const corps = new THREE.Group();
  corps.add(new THREE.Mesh(geo, matiereVerre(BLEU, 0.28)));
  corps.add(new THREE.LineSegments(new THREE.WireframeGeometry(geo), matiereAretes(c.communs, c.chaleur, 0.2)));
  corps.add(new THREE.Points(geo, matierePoints(c.communs, c.chaleur, 0.005, 0.35)));
  corps.rotation.z = Math.PI / 2;
  const allonge = new THREE.Group(); allonge.add(corps);
  allonge.rotation.x = -Math.PI / 2 + 0.42; allonge.scale.setScalar(6.2); allonge.position.set(3.1, -0.2, 0);
  scene.add(allonge); scene.updateMatrixWorld(true);
  const zone = ZONES[s.foyer] || (Array.isArray(s.foyer) ? [...s.foyer, 0.12] : ZONES.thorax);
  const centre = corps.localToWorld(new THREE.Vector3(zone[0], zone[1], zone[2]));
  const tete = corps.localToWorld(new THREE.Vector3(0, 0.925, 0)), thorax = corps.localToWorld(new THREE.Vector3(0, 0.72, 0.03));
  // Vers les pieds (+X) ; depuis le thorax, la chaleur sort aussi du corps.
  const direction = new THREE.Vector3(1, s.foyer === 'thorax' ? 0.35 : 0.05, 0.1).normalize();
  const plan = s.plan || { objet: 'approche', structure: 'profil', processus: 'profil', flux: 'reference', echelle: 'profil', comparaison: 'reference' }[s.intention];
  const cadre = {
    poser(cam, k) {
      if (plan === 'approche') { const f = s.foyer === 'tete' || !s.foyer ? tete : centre; cam.position.set(f.x + 1.5 + 0.6 * k, f.y + 1.6 - 0.3 * k, 3.6 - 1.2 * k); cam.lookAt(f.x + 0.4, f.y - 0.1, f.z); }
      else if (plan === 'profil') { cam.position.set(-2.4 + 3.0 * k, 2.6, 7.6 - 0.6 * k); cam.lookAt(0.2 * k, 0.1, 0); }
      else { cam.position.set(1.2 - 1.6 * k, 2.1 + 0.2 * k, 6.2 - 0.8 * k); cam.lookAt(thorax.x + 1.6, thorax.y - 0.35, thorax.z); }
    },
  };
  return { foyer: s.foyer !== false ? { centre, rayon: zone[3] * 6.2, direction, longueur: 3.4 } : null, cadre, regler() {} };
}

// Décor « gouttes » — référence, image 2.
const GOUTTES = [[0, 0.62, 0, 0.62], [-2.3, 0.5, -2.2, 0.5], [2.4, 0.48, -1.6, 0.46], [-4.6, 0.38, -6.5, 0.4], [4.9, 0.42, -7.4, 0.44],
  [0.9, 0.3, -10, 0.34], [-1.4, 0.2, 2.2, 0.2], [3.2, 0.18, 1.6, 0.16], [-6.5, 0.32, -2.5, 0.3], [6.8, 0.3, -3.4, 0.28]];
function decorGouttes(scene, c, s) {
  scene.add(grille(c.communs));
  const geo = new THREE.IcosahedronGeometry(1, 2); geo.scale(0.72, 1.0, 0.72); geo.computeVertexNormals();
  const ar = matiereAretes(c.communs, c.chaleur, 0.5), pt = matierePoints(c.communs, c.chaleur, 0.012, 0.6);
  const verre = matiereVerre(new THREE.Color(0x6fb0ff), 1.0), lot = [];
  const n = c.palier.particules < 1 ? 7 : GOUTTES.length;
  for (let i = 0; i < n; i++) {
    const [x, y, z, s] = GOUTTES[i], g = new THREE.Group();
    g.add(new THREE.Mesh(geo, verre)); g.add(new THREE.LineSegments(new THREE.WireframeGeometry(geo), ar)); g.add(new THREE.Points(geo, pt));
    g.position.set(x, y + s * 0.98, z); g.scale.setScalar(s); g.userData = { base: g.position.y, i, decor: true };
    scene.add(g); lot.push(g);
  }
  const plan = s.plan || (s.intention === 'comparaison' || s.intention === 'echelle' ? 'arc' : 'rase');
  return {
    regler(local, t) { for (const g of lot) { g.position.y = g.userData.base + 0.04 * Math.sin(t * 0.9 + g.userData.i * 1.7); g.rotation.y = g.userData.i * 0.7 + t * 0.08; } },
    cadre: {
      poser(cam, k) {
        if (plan === 'rase') { cam.position.set(-1.0 + 1.6 * k, 1.15, 6.4 - 2.2 * k); cam.lookAt(0.2, 0.75, -1.5); }
        else { const a = -0.5 + k; cam.position.set(Math.sin(a) * 6, 1.6 - 0.3 * k, Math.cos(a) * 6); cam.lookAt(0, 0.6, -1.2); }
      },
    },
  };
}

// ── Le lecteur ───────────────────────────────────────────────────────────
export function creerLecteur(toile, { corps = null } = {}) {
  const renderer = new THREE.WebGLRenderer({ canvas: toile, antialias: false, powerPreference: 'high-performance' });
  renderer.setPixelRatio(1);
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  const FOV = 36;
  const camera = new THREE.PerspectiveCamera(FOV, 16 / 9, 0.05, 400);
  const communs = { uTemps: { value: 0 }, uOctaves: { value: 4 }, uEchelle: { value: 720 } };

  // Surcouche : sous-titres et attribution DANS la toile WebGL, après le halo,
  // pour qu'ils entrent dans l'export sans montage.
  const ortho = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1), surcouche = new THREE.Scene();
  const toileTexte = document.createElement('canvas'); toileTexte.width = 1280; toileTexte.height = Math.round(720 * 0.17);
  const ctxTexte = toileTexte.getContext('2d'), texTexte = new THREE.CanvasTexture(toileTexte); texTexte.colorSpace = THREE.SRGBColorSpace;
  const bandeau = new THREE.Mesh(new THREE.PlaneGeometry(2, 0.34), new THREE.MeshBasicMaterial({ map: texTexte, transparent: true, depthTest: false, toneMapped: false }));
  bandeau.position.y = -0.76; surcouche.add(bandeau);
  const toileCredit = document.createElement('canvas'); toileCredit.width = 1280; toileCredit.height = 40;
  const ctxCredit = toileCredit.getContext('2d'), texCredit = new THREE.CanvasTexture(toileCredit); texCredit.colorSpace = THREE.SRGBColorSpace;
  const credit = new THREE.Mesh(new THREE.PlaneGeometry(2, 2 * 40 / 720), new THREE.MeshBasicMaterial({ map: texCredit, transparent: true, depthTest: false, toneMapped: false }));
  credit.position.y = 1 - 40 / 720 - 0.02; surcouche.add(credit);
  const noir = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), new THREE.MeshBasicMaterial({ color: 0, transparent: true, opacity: 0, depthTest: false }));
  surcouche.add(noir);
  let texteCourant = null, creditCourant = null;

  function ecrireTexte(texte) {
    if (texte === texteCourant) return; texteCourant = texte;
    const c = ctxTexte, L = toileTexte.width, taille = Math.round(720 * 0.042);
    c.clearRect(0, 0, L, toileTexte.height);
    if (texte) {
      c.font = `600 ${taille}px Poppins, "IBM Plex Sans", sans-serif`; c.textAlign = 'center'; c.textBaseline = 'middle';
      const lignes = []; let l = '';
      for (const m of texte.split(' ')) { const e = l ? l + ' ' + m : m; if (c.measureText(e).width > L * 0.82 && l) { lignes.push(l); l = m; } else l = e; }
      if (l) lignes.push(l);
      const pas = taille * 1.25, y0 = toileTexte.height / 2 - (lignes.length - 1) * pas / 2;
      c.shadowColor = 'rgba(0,0,0,0.85)'; c.shadowBlur = taille * 0.35; c.fillStyle = '#ffffff';
      lignes.forEach((li, i) => c.fillText(li, L / 2, y0 + i * pas));
    }
    texTexte.needsUpdate = true;
  }
  function ecrireCredit(texte) {
    if (texte === creditCourant) return; creditCourant = texte;
    const c = ctxCredit; c.clearRect(0, 0, 1280, 40);
    if (texte) { c.font = '400 15px "IBM Plex Sans", sans-serif'; c.textAlign = 'right'; c.textBaseline = 'middle'; c.fillStyle = 'rgba(220,230,245,0.75)'; c.fillText(texte, 1260, 20); }
    texCredit.needsUpdate = true;
  }

  const etat = { capsule: null, phrases: [], palierNom: 'complet', palier: PALIERS.complet, composer: null, cache: new Map(),
    objets: new Map(), attributionsParScene: new Map() };

  function vider() {
    for (const s of etat.cache.values()) s.scene.traverse((n) => { n.geometry?.dispose?.(); n.material?.dispose?.(); });
    etat.cache.clear();
  }
  function palier(nom) {
    etat.palierNom = nom; etat.palier = PALIERS[nom];
    const p = etat.palier;
    renderer.setSize(p.L, p.H, false);
    communs.uOctaves.value = p.octaves; communs.uEchelle.value = p.H;
    etat.composer?.dispose();
    const cible = new THREE.WebGLRenderTarget(p.L, p.H, { type: THREE.HalfFloatType, samples: p.echantillons });
    const comp = new EffectComposer(renderer, cible); comp.setPixelRatio(1); comp.setSize(p.L, p.H);
    comp.addPass(new RenderPass(new THREE.Scene(), camera));
    comp.addPass(new UnrealBloomPass(new THREE.Vector2(p.L * p.bloom, p.H * p.bloom), 0.85, 0.5, 0.18));
    comp.addPass(new OutputPass());
    etat.composer = comp;
    vider();
  }
  function sceneDe(s) {
    if (!etat.cache.has(s.rang)) {
      const attributions = new Set();
      const sc = construireScene(s, { communs, palier: etat.palier, corps, objets: etat.objets, attributions, aspect: 16 / 9, fov: FOV });
      etat.attributionsParScene.set(s.rang, [...attributions]);
      etat.cache.set(s.rang, sc);
    }
    return etat.cache.get(s.rang);
  }
  function sceneA(t) {
    const sc = etat.capsule.scenes;
    for (let i = sc.length - 1; i >= 0; i--) if (t >= sc[i].debut) return sc[i];
    return sc[0];
  }

  function dessiner(t) {
    const cap = etat.capsule;
    t = Math.max(0, Math.min(cap.duree - 0.001, t));
    const s = sceneA(t), local = (t - s.debut) / s.duree;
    communs.uTemps.value = t;
    const sc = sceneDe(s);
    sc.regler(local, t, camera);
    etat.composer.passes[0].scene = sc.scene;
    const ph = etat.phrases.find((p) => t >= p.debut && t < p.fin);
    ecrireTexte(ph ? ph.texte : '');
    const attr = etat.attributionsParScene.get(s.rang) || [];
    ecrireCredit(attr.length ? attr.join(' · ') : '');
    noir.material.opacity = Math.max(0, 1 - Math.min(t - s.debut, s.debut + s.duree - t) / 0.35);
    etat.composer.render();
    renderer.autoClear = false; renderer.render(surcouche, ortho); renderer.autoClear = true;
    return s;
  }

  /** Télécharge les objets `convoquer` d'une capsule (v1 : par l'index ; v2 : `objets` résolus). */
  async function prechargerObjets(capsule, index, delaiMs = 25000) {
    const termes = new Set();
    for (const s of capsule.scenes) for (const g of s.gestes) if (g.verbe === 'convoquer') termes.add(g.parametres?.terme);
    const loader = new GLTFLoader(), rapport = [];
    await Promise.all([...termes].filter(Boolean).map(async (terme) => {
      const resolu = capsule.objets?.[terme] || (index?.termes?.[terme] || [])[0];
      if (!resolu) { rapport.push(`${terme} : absent de l'index`); return; }
      const url = resolu.url || BASE_OBJETS + resolu.chemin;
      try {
        const gltf = await Promise.race([loader.loadAsync(url), new Promise((_, r) => setTimeout(() => r(new Error('délai dépassé')), delaiMs))]);
        etat.objets.set(terme, { scene: gltf.scene, attribution: resolu.attribution || `Modèle 3D : sketchfab.com/3d-models/${resolu.uid} (CC-${String(resolu.licence || 'by').toUpperCase()})` });
        rapport.push(`${terme} : chargé`);
      } catch (e) { rapport.push(`${terme} : ${e.message}`); }
    }));
    return rapport;
  }

  return {
    renderer, camera, PALIERS,
    get palierNom() { return etat.palierNom; }, get palierCourant() { return etat.palier; }, get capsule() { return etat.capsule; },
    palier, dessiner, prechargerObjets,
    charger(capsule) { etat.capsule = capsule; etat.phrases = phrasesDe(capsule); vider(); texteCourant = null; },
    // Seuls les sous-titres dépendent des durées : les scènes construites
    // restent valables (la caméra suit la FRACTION du plan, pas la seconde).
    // Ne rien reconstruire ici, sinon chaque voix arrivée ferait accrocher la lecture.
    recaler() { etat.phrases = phrasesDe(etat.capsule); },
    // Construire toutes les scènes d'avance : sinon la première image de
    // chaque scène paie la construction, et la lecture accroche à chaque plan.
    preparerTout() { for (const s of etat.capsule.scenes) sceneDe(s); },
    journalScene(rang) { const s = etat.capsule.scenes[rang]; return sceneDe(s).journal; },
    objetsScene(rang) { const s = etat.capsule.scenes[rang]; return sceneDe(s).objets; },
    attributions() { return [...new Set([...etat.attributionsParScene.values()].flat())]; },
  };
}
