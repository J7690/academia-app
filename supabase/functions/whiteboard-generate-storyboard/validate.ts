// Validation / normalisation du storyboard genere par le modele.
//
// PRINCIPE DIRECTEUR : on NETTOIE, on ne rejette que l'irremplacable.
// Un modele de langage se trompe. Rejeter une generation entiere pour un champ
// qu'on sait DEDUIRE (un ordre = une position dans un tableau) ferait perdre a
// l'etudiant ses credits ET son cours. La question posee devant chaque controle
// est donc : « si ce champ manque, est-ce que je sais quoi mettre ? ». Si oui,
// on le met.
//
// Module separe de index.ts pour etre TESTABLE sans demarrer le serveur HTTP
// (voir validate_test.ts). Une panne de production du 27/07/2026
// (« Block missing field: order ») a montre que cette brique meritait des tests.

// Normalisation legere pour comparer une cible d'annotation au contenu du bloc :
// on ignore la casse, les accents et les espaces multiples. Objectif : detecter les
// cibles totalement absentes du texte (hallucination du modele) sans etre tatillon.
export function normalizeForMatch(s: string): string {
  return s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/\s+/g, ' ').trim();
}

// Identifiant de secours quand le modele oublie un "id". Pas besoin d'un UUID
// cryptographique : il sert uniquement de cle stable a l'interieur du storyboard.
let fallbackIdSeq = 0;
function fallbackId(prefix: string): string {
  fallbackIdSeq += 1;
  return `${prefix}-auto-${Date.now().toString(36)}-${fallbackIdSeq}`;
}

const SCENE_BEATS = ['hook', 'concept', 'example', 'exercise', 'correction', 'recap'];
const BLOCK_TYPES = ['title', 'paragraph', 'formula', 'definition', 'exercise', 'correction', 'diagram', 'graph'];
const EMPHASIS_KINDS = ['circle', 'underline', 'highlight'];
const WRITE_SPEEDS = ['slow', 'normal', 'fast'];

// FORMAT SPOT (28/07/2026) — plafonds resserres pour tenir la cible 90-150 s.
// Mesure a l'origine du changement : un cours de 9 scenes / 30 blocs produisait une
// video de 201 s, rendue en 401 s sur le VPS (ratio 2x). Or le format qui obtient le
// meilleur taux de visionnage complet est 90-150 s. Raccourcir sert donc DEUX fois :
// l'etudiant regarde jusqu'au bout, et il attend deux fois moins longtemps.
// Applique par TRONCATURE (jamais de rejet) : la scene de recap est preservee.
const MAX_SCENES = 7;
const MAX_BLOCKS_PER_SCENE = 4;
const MAX_STORYBOARD_BYTES = 100000;
const DEFAULT_SCENE_DURATION_MS = 8000;

// Budget de duree total. Le modele fixe `duration_ms` par scene ; on borne chaque
// scene puis on ecrete l'ensemble si la somme depasse le plafond.
const MIN_SCENE_DURATION_MS = 4000;
const MAX_SCENE_DURATION_MS = 25000;
const MAX_TOTAL_DURATION_MS = 150000;

// La narration est LUE A VOIX HAUTE : aucun LaTeX ne doit y subsister, sinon la
// synthese vocale lit du charabia.
function stripLatex(s: string): string {
  return s
    .replace(/\$+/g, ' ')
    .replace(/\\[a-zA-Z]+/g, ' ')
    .replace(/[{}^_]/g, ' ')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

export interface ValidationResult { valid: boolean; error?: string }

export function validateStoryboard(json: unknown): ValidationResult {
  if (!json || typeof json !== 'object') return { valid: false, error: 'Not an object' };
  const sb = json as Record<string, unknown>;

  // Seules les scenes sont irremplacables. Les metadonnees (created_by, subject,
  // renderer, theme, narration_mode, created_at) sont ECRASEES par l'appelant avec
  // les valeurs de la requete : les exiger ici n'aurait aucun sens.
  if (!('scenes' in sb)) return { valid: false, error: 'Missing field: scenes' };
  if (sb.version !== '1.0') sb.version = '1.0';
  if (typeof sb.export_settings !== 'object' || sb.export_settings === null || Array.isArray(sb.export_settings)) {
    sb.export_settings = { format: 'mp4', resolution: { width: 1080, height: 1920 }, frame_rate: 30, video_codec: 'h264', audio_codec: 'aac' };
  }
  if (!Array.isArray(sb.scenes)) return { valid: false, error: 'scenes is not an array' };
  if ((sb.scenes as unknown[]).length === 0) return { valid: false, error: 'scenes is empty' };

  // Plafond applique par TRONCATURE : un cours un peu trop long vaut mieux qu'aucun.
  // On coupe au MILIEU, pas a la fin : la DERNIERE scene est le recap ("a retenir"),
  // qui porte la valeur pedagogique de cloture. La supprimer donnerait un cours qui
  // s'arrete net. On garde donc les premieres scenes + la derniere.
  if ((sb.scenes as unknown[]).length > MAX_SCENES) {
    const all = sb.scenes as Record<string, unknown>[];
    const last = all[all.length - 1];
    const isRecap = last && typeof last === 'object' && last.beat === 'recap';
    sb.scenes = isRecap
      ? [...all.slice(0, MAX_SCENES - 1), last]
      : all.slice(0, MAX_SCENES);
  }

  // Une scene sans bloc exploitable est ECARTEE : perdre une scene sur huit est
  // infiniment preferable a perdre le cours entier.
  sb.scenes = (sb.scenes as unknown[]).filter((sc) => {
    if (!sc || typeof sc !== 'object') return false;
    const blks = (sc as Record<string, unknown>).blocks;
    if (!Array.isArray(blks)) return false;
    return blks.some((blk) => {
      if (!blk || typeof blk !== 'object') return false;
      const c = (blk as Record<string, unknown>).content;
      return typeof c === 'string' && c.trim().length > 0;
    });
  });
  if ((sb.scenes as unknown[]).length === 0) return { valid: false, error: 'no usable scene' };

  const scenes = sb.scenes as Record<string, unknown>[];
  for (let sidx = 0; sidx < scenes.length; sidx++) {
    const s = scenes[sidx];

    // transition : tolere la forme courte "fade" comme l'objet { kind: 'fade' }.
    if (typeof s.transition === 'string') s.transition = { kind: s.transition };
    if ('transition' in s && (typeof s.transition !== 'object' || s.transition === null || Array.isArray(s.transition))) s.transition = {};

    // recall : garder seulement s'il pointe vers une scene PRECEDENTE.
    if ('recall' in s) {
      const rc = s.recall as Record<string, unknown> | null;
      const tgt = rc && typeof rc.target === 'number' ? rc.target : -1;
      if (!rc || tgt < 0 || tgt >= sidx) delete s.recall;
    }

    if (typeof s.narration === 'string') s.narration = stripLatex(s.narration);

    // beat v3 : valeur inconnue -> on retire, le moteur rend la scene normalement.
    if ('beat' in s && !SCENE_BEATS.includes(s.beat as string)) delete s.beat;

    // Champs COMPLETES plutot qu'exiges. La duree n'est qu'une indication : le
    // moteur la recalcule d'apres la narration reelle, pour ne jamais couper la voix.
    if (typeof s.id !== 'string' || !s.id.trim()) s.id = fallbackId('scene');
    if (typeof s.order !== 'number') s.order = sidx;
    if (typeof s.title !== 'string') s.title = '';
    let durationMs = typeof s.duration_ms === 'number' && s.duration_ms > 0 ? s.duration_ms : DEFAULT_SCENE_DURATION_MS;
    // Borne haute/basse par scene : une scene de 40 s casse le rythme et allonge le
    // rendu ; une scene de 1 s ne laisse pas le temps de lire.
    if (durationMs > MAX_SCENE_DURATION_MS) durationMs = MAX_SCENE_DURATION_MS;
    if (durationMs < MIN_SCENE_DURATION_MS) durationMs = MIN_SCENE_DURATION_MS;
    s.duration_ms = durationMs;

    // Un bloc sans contenu ne peut rien afficher : on l'ECARTE.
    let blocks = (s.blocks as unknown[]).filter((blk) => {
      if (!blk || typeof blk !== 'object') return false;
      const c = (blk as Record<string, unknown>).content;
      return typeof c === 'string' && c.trim().length > 0;
    }) as Record<string, unknown>[];
    if (blocks.length > MAX_BLOCKS_PER_SCENE) blocks = blocks.slice(0, MAX_BLOCKS_PER_SCENE);
    s.blocks = blocks;

    for (let bidx = 0; bidx < blocks.length; bidx++) {
      const b = blocks[bidx];

      // id, order et visible sont completes silencieusement : l'ordre EST la
      // position dans le tableau, et un bloc est visible par defaut.
      if (typeof b.id !== 'string' || !b.id.trim()) b.id = fallbackId('block');
      if (typeof b.order !== 'number') b.order = bidx;
      if (typeof b.visible !== 'boolean') b.visible = true;
      if (typeof b.style !== 'object' || b.style === null || Array.isArray(b.style)) {
        b.style = { fontSize: 16, fontWeight: 'normal', color: '#000000' };
      }
      if ('animation' in b && (typeof b.animation !== 'object' || b.animation === null || Array.isArray(b.animation))) b.animation = {};
      if ('position' in b && (typeof b.position !== 'object' || b.position === null || Array.isArray(b.position))) b.position = {};

      // Type inconnu : le contenu reste ecrivable, on le traite en paragraphe
      // plutot que de perdre le cours pour une etiquette mal choisie.
      if (!BLOCK_TYPES.includes(b.type as string)) b.type = 'paragraph';

      // emphasis : seules 3 valeurs ont un sens pour le moteur de rendu.
      if ('emphasis' in b && !EMPHASIS_KINDS.includes(b.emphasis as string)) delete b.emphasis;

      // emphasis_target : doit etre un EXTRAIT REEL du contenu, et court. Sinon le
      // moteur ne saurait pas ou dessiner.
      if ('emphasis_target' in b) {
        const tgt = typeof b.emphasis_target === 'string' ? b.emphasis_target.trim() : '';
        const contentNorm = normalizeForMatch(b.content as string);
        const ok = tgt.length >= 2 && tgt.length <= 60 && contentNorm.includes(normalizeForMatch(tgt));
        if (!ok) delete b.emphasis_target;
      }
      // Une cible sans geste n'a pas de sens : on choisit le souligne par defaut.
      if ('emphasis_target' in b && !('emphasis' in b)) b.emphasis = 'underline';

      if ('write_speed' in b && !WRITE_SPEEDS.includes(b.write_speed as string)) delete b.write_speed;

      // narration de BLOC v3 : lue pendant que le bloc s'ecrit.
      if ('narration' in b) {
        if (typeof b.narration !== 'string') delete b.narration;
        else b.narration = stripLatex(b.narration);
      }

      // key_words v3 : chacun doit etre un EXTRAIT REEL du contenu, 3 au maximum.
      if ('key_words' in b) {
        const contentNorm = normalizeForMatch(b.content as string);
        const kws = Array.isArray(b.key_words)
          ? (b.key_words as unknown[])
              .filter((k): k is string => typeof k === 'string')
              .map((k) => k.trim())
              .filter((k) => k.length >= 2 && k.length <= 40 && contentNorm.includes(normalizeForMatch(k)))
              .slice(0, 3)
          : [];
        if (kws.length > 0) b.key_words = kws; else delete b.key_words;
      }
    }
  }

  // BUDGET DE DUREE TOTAL — dernier garde-fou du format spot.
  // Si la somme des scenes depasse le plafond, on reduit proportionnellement chaque
  // scene plutot que d'en supprimer : on garde TOUT le contenu pedagogique (y compris
  // le recap), simplement joue a un rythme plus soutenu. La narration reste maitresse
  // cote worker : elle ne sera jamais coupee, ces durees sont un plancher indicatif.
  {
    const list = sb.scenes as Record<string, unknown>[];
    const total = list.reduce((sum, s) => sum + (typeof s.duration_ms === 'number' ? s.duration_ms : 0), 0);
    if (total > MAX_TOTAL_DURATION_MS && total > 0) {
      const factor = MAX_TOTAL_DURATION_MS / total;
      for (const s of list) {
        if (typeof s.duration_ms === 'number') {
          s.duration_ms = Math.max(MIN_SCENE_DURATION_MS, Math.floor(s.duration_ms * factor));
        }
      }
    }
  }

  if (JSON.stringify(sb).length > MAX_STORYBOARD_BYTES) return { valid: false, error: 'Storyboard too large (max 100KB)' };
  return { valid: true };
}
