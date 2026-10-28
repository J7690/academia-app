import { assertEquals, assertThrows } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { cheminVoix, enParallele, MAX_CARACTERES, scenesAVoixer } from './voix.ts';

Deno.test('scenesAVoixer garde l\'ordre et saute les scènes muettes', () => {
  const r = scenesAVoixer({ scenes: [
    { id: 's1', narration: ' Bonjour. ' }, { id: 's2', narration: '' }, { id: 's3' }, { id: 's4', narration: 'Fin.' },
  ] });
  assertEquals(r, [{ rang: 0, id: 's1', texte: 'Bonjour.' }, { rang: 3, id: 's4', texte: 'Fin.' }]);
});

Deno.test('scenesAVoixer remplace un identifiant douteux et borne le texte', () => {
  const r = scenesAVoixer({ scenes: [{ id: '../../x', narration: 'a'.repeat(5000) }] });
  assertEquals(r[0].id, 's1');
  assertEquals(r[0].texte.length, MAX_CARACTERES);
});

Deno.test('scenesAVoixer lit la capsule rangée sous storyboard, comme en base', () => {
  // Forme réelle de app.studio_jobs.manifeste (travail 54da352d, 28/10/2026).
  const r = scenesAVoixer({ discipline: 'scientific', project_id: 'p', storyboard: { titre: 'Le cycle de l\'eau', scenes: [
    { id: 's1', narration: 'L\'eau couvre la Terre.' }, { id: 's2', narration: 'Elle s\'évapore.' },
  ] } });
  assertEquals(r.map((s) => s.id), ['s1', 's2']);
});

Deno.test('scenesAVoixer ne plante pas sur un manifeste vide ou faux', () => {
  assertEquals(scenesAVoixer(null), []);
  assertEquals(scenesAVoixer({ scenes: 'non' }), []);
});

Deno.test('cheminVoix reste sous capsules/ et refuse la traversée', () => {
  assertEquals(cheminVoix('168CCB14-0000-4000-8000-000000000000', 's1'), 'capsules/voix/168ccb14-0000-4000-8000-000000000000/s1.mp3');
  assertThrows(() => cheminVoix('../x', 's1'));
  assertThrows(() => cheminVoix('168ccb14-0000-4000-8000-000000000000', '../s1'));
});

Deno.test('enParallele rend chaque résultat dans l\'ordre d\'arrivée, au plus N à la fois', async () => {
  const delais = [60, 10, 30, 5];
  let enCours = 0, pic = 0;
  const arrivee: number[] = [];
  await enParallele(delais.map((d, i) => ({ i, d })), 2, async ({ d }) => {
    enCours++; pic = Math.max(pic, enCours);
    await new Promise((r) => setTimeout(r, d));
    enCours--; return d;
  }, (e) => arrivee.push(e.i));
  assertEquals(pic, 2);
  assertEquals(arrivee.length, 4);
  assertEquals(arrivee[0], 1);   // la plus courte des deux premières arrive d'abord
});
