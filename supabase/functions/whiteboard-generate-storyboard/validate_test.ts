// Tests de la validation du storyboard.
//   deno test --allow-none supabase/functions/whiteboard-generate-storyboard/validate_test.ts
//
// Le premier test reproduit la panne de production du 27/07/2026 : le modele avait
// omis "order" sur un bloc et TOUT le cours etait rejete.

import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { validateStoryboard } from './validate.ts';

// Storyboard minimal mais REALISTE : c'est la forme que produit le modele.
function baseStoryboard(): Record<string, unknown> {
  return {
    version: '1.0',
    subject: 'La Loi Normale Centree Reduite',
    renderer: 'notebook',
    theme: 'notebook',
    narration_mode: 'tts',
    export_settings: { format: 'mp4' },
    scenes: [
      {
        id: 'scene-001', order: 0, title: 'Pourquoi centrer et reduire ?',
        duration_ms: 7000, beat: 'hook', narration: 'Commencons par une question.',
        transition: { kind: 'fade' },
        blocks: [
          { id: 'b1', type: 'paragraph', content: 'Toute loi normale se ramene a une seule.', order: 0, visible: true },
        ],
      },
    ],
  };
}

Deno.test('REGRESSION 27/07/2026 : un bloc sans "order" ne fait plus echouer le cours', () => {
  const sb = baseStoryboard();
  const blocks = (sb.scenes as Record<string, unknown>[])[0].blocks as Record<string, unknown>[];
  delete blocks[0].order;

  const res = validateStoryboard(sb);
  assert(res.valid, `rejete a tort : ${res.error}`);
  // L'ordre est DEDUIT de la position dans le tableau.
  assertEquals(blocks[0].order, 0);
});

Deno.test('un bloc sans id / visible est complete au lieu d\'etre rejete', () => {
  const sb = baseStoryboard();
  const blocks = (sb.scenes as Record<string, unknown>[])[0].blocks as Record<string, unknown>[];
  delete blocks[0].id;
  delete blocks[0].visible;

  const res = validateStoryboard(sb);
  assert(res.valid, `rejete a tort : ${res.error}`);
  assertEquals(typeof blocks[0].id, 'string');
  assert((blocks[0].id as string).length > 0);
  assertEquals(blocks[0].visible, true);
});

Deno.test('une scene sans id / order / title / duration_ms est completee', () => {
  const sb = baseStoryboard();
  const scene = (sb.scenes as Record<string, unknown>[])[0];
  delete scene.id;
  delete scene.order;
  delete scene.title;
  delete scene.duration_ms;

  const res = validateStoryboard(sb);
  assert(res.valid, `rejete a tort : ${res.error}`);
  assertEquals(scene.order, 0);
  assertEquals(scene.title, '');
  assertEquals(scene.duration_ms, 8000);
  assertEquals(typeof scene.id, 'string');
});

Deno.test('les metadonnees absentes ne bloquent pas : elles sont ecrasees par l\'appelant', () => {
  const sb = baseStoryboard();
  delete sb.subject;
  delete sb.renderer;
  delete sb.theme;
  delete sb.narration_mode;
  delete sb.export_settings;
  delete sb.version;

  const res = validateStoryboard(sb);
  assert(res.valid, `rejete a tort : ${res.error}`);
  assertEquals(sb.version, '1.0');
  assert(typeof sb.export_settings === 'object');
});

Deno.test('un type de bloc inconnu devient paragraph', () => {
  const sb = baseStoryboard();
  const blocks = (sb.scenes as Record<string, unknown>[])[0].blocks as Record<string, unknown>[];
  blocks[0].type = 'theoreme';

  const res = validateStoryboard(sb);
  assert(res.valid, `rejete a tort : ${res.error}`);
  assertEquals(blocks[0].type, 'paragraph');
});

Deno.test('un bloc vide est ECARTE, les autres blocs survivent', () => {
  const sb = baseStoryboard();
  const scene = (sb.scenes as Record<string, unknown>[])[0];
  (scene.blocks as unknown[]).push({ id: 'b2', type: 'paragraph', content: '   ', order: 1, visible: true });
  (scene.blocks as unknown[]).push({ id: 'b3', type: 'formula', content: '\\sigma = 1', order: 2, visible: true });

  const res = validateStoryboard(sb);
  assert(res.valid, `rejete a tort : ${res.error}`);
  const blocks = scene.blocks as Record<string, unknown>[];
  assertEquals(blocks.length, 2);
  assertEquals(blocks[1].content, '\\sigma = 1');
  // Les ordres FOURNIS par le modele sont respectes (le moteur trie dessus) ; seuls
  // les ordres manquants sont deduits de la position.
  assertEquals(blocks[0].order, 0);
});

Deno.test('une scene entierement vide est ECARTEE, le cours survit', () => {
  const sb = baseStoryboard();
  (sb.scenes as unknown[]).push({
    id: 'scene-002', order: 1, title: 'Scene ratee', duration_ms: 5000,
    blocks: [{ id: 'x', type: 'paragraph', content: '', order: 0, visible: true }],
  });
  (sb.scenes as unknown[]).push({
    id: 'scene-003', order: 2, title: 'Scene valide', duration_ms: 5000,
    blocks: [{ id: 'y', type: 'paragraph', content: 'Contenu utile.', order: 0, visible: true }],
  });

  const res = validateStoryboard(sb);
  assert(res.valid, `rejete a tort : ${res.error}`);
  assertEquals((sb.scenes as unknown[]).length, 2);
});

Deno.test('un storyboard SANS AUCUNE scene exploitable est rejete', () => {
  const sb = baseStoryboard();
  sb.scenes = [{ id: 's', order: 0, title: 't', duration_ms: 1000, blocks: [] }];

  const res = validateStoryboard(sb);
  assertEquals(res.valid, false);
});

Deno.test('le LaTeX est retire des narrations de scene ET de bloc', () => {
  const sb = baseStoryboard();
  const scene = (sb.scenes as Record<string, unknown>[])[0];
  scene.narration = 'On note $\\sigma$ l\'ecart-type.';
  const blocks = scene.blocks as Record<string, unknown>[];
  blocks[0].narration = 'La variable $Z$ suit \\mathcal{N}(0,1).';

  const res = validateStoryboard(sb);
  assert(res.valid);
  assert(!(scene.narration as string).includes('$'));
  assert(!(scene.narration as string).includes('\\sigma'));
  assert(!(blocks[0].narration as string).includes('$'));
  assert(!(blocks[0].narration as string).includes('\\mathcal'));
});

Deno.test('key_words : seuls les extraits REELS du contenu sont conserves', () => {
  const sb = baseStoryboard();
  const blocks = (sb.scenes as Record<string, unknown>[])[0].blocks as Record<string, unknown>[];
  blocks[0].content = 'Toute loi normale se ramene a la loi centree reduite.';
  blocks[0].key_words = ['loi normale', 'inexistant ici', 'centree reduite', 'loi', 'de trop'];

  const res = validateStoryboard(sb);
  assert(res.valid);
  const kws = blocks[0].key_words as string[];
  assert(kws.length <= 3);
  assert(kws.includes('loi normale'));
  assert(!kws.includes('inexistant ici'));
});

Deno.test('key_words : insensible aux accents et a la casse', () => {
  const sb = baseStoryboard();
  const blocks = (sb.scenes as Record<string, unknown>[])[0].blocks as Record<string, unknown>[];
  blocks[0].content = 'La loi normale centrée réduite.';
  blocks[0].key_words = ['CENTREE REDUITE'];

  const res = validateStoryboard(sb);
  assert(res.valid);
  assertEquals(blocks[0].key_words, ['CENTREE REDUITE']);
});

Deno.test('un beat inconnu est retire sans rejeter la scene', () => {
  const sb = baseStoryboard();
  const scene = (sb.scenes as Record<string, unknown>[])[0];
  scene.beat = 'introduction';

  const res = validateStoryboard(sb);
  assert(res.valid);
  assertEquals('beat' in scene, false);
});

Deno.test('emphasis_target absent du contenu est retire', () => {
  const sb = baseStoryboard();
  const blocks = (sb.scenes as Record<string, unknown>[])[0].blocks as Record<string, unknown>[];
  blocks[0].emphasis = 'circle';
  blocks[0].emphasis_target = 'formule totalement absente';

  const res = validateStoryboard(sb);
  assert(res.valid);
  assertEquals('emphasis_target' in blocks[0], false);
  assertEquals(blocks[0].emphasis, 'circle');
});

Deno.test('une cible valide sans geste recoit "underline" par defaut', () => {
  const sb = baseStoryboard();
  const blocks = (sb.scenes as Record<string, unknown>[])[0].blocks as Record<string, unknown>[];
  blocks[0].content = 'Toute loi normale se ramene a une seule.';
  blocks[0].emphasis_target = 'une seule';

  const res = validateStoryboard(sb);
  assert(res.valid);
  assertEquals(blocks[0].emphasis, 'underline');
});

Deno.test('recall vers une scene FUTURE ou soi-meme est retire', () => {
  const sb = baseStoryboard();
  const scene = (sb.scenes as Record<string, unknown>[])[0];
  scene.recall = { target: 0, kind: 'circle' };

  const res = validateStoryboard(sb);
  assert(res.valid);
  assertEquals('recall' in scene, false);
});

Deno.test('transition donnee en chaine est normalisee en objet', () => {
  const sb = baseStoryboard();
  const scene = (sb.scenes as Record<string, unknown>[])[0];
  scene.transition = 'slide';

  const res = validateStoryboard(sb);
  assert(res.valid);
  assertEquals(scene.transition, { kind: 'slide' });
});

Deno.test('les plafonds sont appliques par TRONCATURE, pas par rejet', () => {
  const sb = baseStoryboard();
  const scene = (sb.scenes as Record<string, unknown>[])[0];
  for (let i = 0; i < 15; i++) {
    (scene.blocks as unknown[]).push({ type: 'paragraph', content: `Bloc ${i}.` });
  }
  const res = validateStoryboard(sb);
  assert(res.valid, `rejete a tort : ${res.error}`);
  // FORMAT SPOT 28/07/2026 : plafond ramene de 10 a 4 blocs par scene.
  assertEquals((scene.blocks as unknown[]).length, 4);
});

// ─── FORMAT SPOT (28/07/2026) ────────────────────────────────────────────────
// Origine : un cours de 9 scenes produisait 201 s de video, rendue en 401 s sur le
// VPS. Cible retenue : 90-150 s. Ces tests verrouillent les garde-fous.

Deno.test('SPOT : au-dela de 7 scenes, on tronque MAIS on garde le recap final', () => {
  const sb = baseStoryboard();
  const scenes = sb.scenes as Record<string, unknown>[];
  const modele = JSON.stringify(scenes[0]);
  for (let i = 0; i < 12; i++) {
    scenes.push({ ...JSON.parse(modele), order: i + 1, beat: 'concept' });
  }
  scenes.push({ ...JSON.parse(modele), order: 99, beat: 'recap', title: 'A retenir' });

  const res = validateStoryboard(sb);
  assert(res.valid, `rejete a tort : ${res.error}`);
  const out = sb.scenes as Record<string, unknown>[];
  assertEquals(out.length, 7);
  // La conclusion pedagogique doit survivre a la troncature.
  assertEquals(out[out.length - 1].beat, 'recap');
});

Deno.test('SPOT : la duree totale est ramenee sous 150 s', () => {
  // 7 scenes a 25 s = 175 s apres bornage individuel : l'ecretage PROPORTIONNEL
  // doit alors intervenir pour revenir sous 150 s.
  const sb = baseStoryboard();
  const scenes = sb.scenes as Record<string, unknown>[];
  const modele = JSON.stringify(scenes[0]);
  scenes[0].duration_ms = 25000;
  for (let i = 0; i < 6; i++) {
    scenes.push({ ...JSON.parse(modele), order: i + 1, duration_ms: 25000 });
  }

  const res = validateStoryboard(sb);
  assert(res.valid, `rejete a tort : ${res.error}`);
  const out = sb.scenes as Record<string, unknown>[];
  const total = out.reduce((s, sc) => s + (sc.duration_ms as number), 0);
  assert(total <= 150000, `duree totale trop longue : ${total} ms`);
  // Aucune scene n'est supprimee par l'ecretage : on accelere, on ne coupe pas.
  assertEquals(out.length, 7);
});

Deno.test('SPOT : une scene demesuree est bornee a 25 s', () => {
  const sb = baseStoryboard();
  (sb.scenes as Record<string, unknown>[])[0].duration_ms = 90000;
  const res = validateStoryboard(sb);
  assert(res.valid, `rejete a tort : ${res.error}`);
  assertEquals((sb.scenes as Record<string, unknown>[])[0].duration_ms, 25000);
});

Deno.test('les entrees non exploitables restent rejetees', () => {
  assertEquals(validateStoryboard(null).valid, false);
  assertEquals(validateStoryboard('texte').valid, false);
  assertEquals(validateStoryboard({}).valid, false);
  assertEquals(validateStoryboard({ scenes: 'pas un tableau' }).valid, false);
  assertEquals(validateStoryboard({ scenes: [] }).valid, false);
});
