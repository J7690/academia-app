// Supabase Edge Function : studio-voix
//
// LA VOIX D'UNE CAPSULE, SCÈNE PAR SCÈNE, TOUTES EN MÊME TEMPS.
//
// Avant (28/10) : `studio-preparateur` sur LWS synthétisait les scènes l'une
// après l'autre, puis calait, mixait, déposait — ≈ 35 s avant que la machine
// GPU ne commence seulement (ETAT §1 bis). Le lecteur sur l'appareil n'a besoin
// que de la voix de la scène 1 pour commencer à jouer.
//
// Ici : une requête TTS par scène, lancées ensemble, et une réponse en flux
// (une ligne JSON par scène, dans l'ORDRE D'ARRIVÉE). Le lecteur démarre dès
// que la scène 1 est là ; les suivantes arrivent pendant qu'il la joue.
//
// Ce que cette fonction NE fait pas, délibérément :
//   - le ralentissement à 0,88 et la respiration de fin de phrase : faits dans
//     le lecteur (pas de ffmpeg ici) ;
//   - la nappe sonore : le lecteur la synthétisera (lot suivant) ;
//   - débiter des crédits : la capsule a déjà été payée par
//     whiteboard-generate-storyboard. Une voix déjà faite est RENDUE, pas refaite.
//
// Appel :  POST { job_id }               — JWT de l'étudiant propriétaire ;
//          POST { job_id, manifeste }    — appel interne (service_role).
// Réponse : application/x-ndjson
//   {"type":"debut","scenes":[{"rang":0,"id":"s1"},…]}
//   {"type":"voix","rang":0,"id":"s1","url":"…","cache":false,"ms":2310,"ms_tts":2190,"octets":61234}
//   {"type":"voix","rang":3,"id":"s4","erreur":"…","ms":…}
//   {"type":"fin","ms":3120,"faites":5,"echecs":0}

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { cheminVoix, enParallele, PARALLELE_MAX, scenesAVoixer } from './voix.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
// Mêmes réglages que la chaîne 3D actuelle (narration.py : STUDIO_VOIX), pour
// que la nouvelle voix soit EXACTEMENT l'ancienne.
const MODELE = Deno.env.get('OPENROUTER_TTS_MODEL') ?? 'mistralai/voxtral-mini-tts-2603';
// PAS `OPENROUTER_TTS_VOICE` : c'est le réglage du tableau manuscrit, et
// narration.py envoie toujours sa propre voix. Les deux produits doivent pouvoir
// diverger sans se gêner (cf. whiteboard-tts).
const VOIX = Deno.env.get('STUDIO_VOIX') ?? 'fr_marie_neutral';
const BUCKET = 'studio-visuel';
const VALIDITE_S = 24 * 3600;

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept,x-client-info',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};
const json = (d: unknown, status = 200) =>
  new Response(JSON.stringify(d), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

// La passerelle Supabase a déjà vérifié la signature du jeton (verify_jwt) :
// lire le rôle suffit à reconnaître un appel interne.
function role(jeton: string): string {
  try { return JSON.parse(atob(jeton.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))).role ?? ''; }
  catch { return ''; }
}

async function synthetiser(texte: string): Promise<Uint8Array> {
  let derniere = '';
  // Trois essais, comme narration.py : une coupure réseau ne doit pas coûter la scène.
  for (let essai = 1; essai <= 3; essai++) {
    try {
      const r = await fetch('https://openrouter.ai/api/v1/audio/speech', {
        method: 'POST',
        headers: { Authorization: `Bearer ${OPENROUTER_API_KEY}`, 'Content-Type': 'application/json', Accept: 'audio/mpeg' },
        body: JSON.stringify({ model: MODELE, input: texte, voice: VOIX, response_format: 'mp3' }),
      });
      if (!r.ok) { derniere = `TTS ${r.status} ${(await r.text()).slice(0, 160)}`; }
      else {
        const octets = new Uint8Array(await r.arrayBuffer());
        if (octets.byteLength > 0) return octets;
        derniere = 'TTS : audio vide';
      }
    } catch (e) { derniere = `TTS : ${(e as Error).message}`; }
    await new Promise((ok) => setTimeout(ok, 600 * essai));
  }
  throw new Error(derniere);
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (!OPENROUTER_API_KEY) return json({ error: 'tts_non_configure' }, 500);

  const jeton = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '').trim();
  const service = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  let corps: { job_id?: unknown; manifeste?: unknown };
  try { corps = await req.json(); } catch { return json({ error: 'invalid_json' }, 400); }
  const jobId = typeof corps.job_id === 'string' ? corps.job_id : '';
  if (!/^[0-9a-f-]{36}$/i.test(jobId)) return json({ error: 'job_id_invalide' }, 400);

  // QUI LIT LA CAPSULE. Le rôle de service n'a PAS de droit de lecture sur
  // app.studio_jobs (mesuré le 28/10 : « permission denied ») ; la seule règle
  // est « l'étudiant lit ses propres travaux ». On s'y tient :
  //   - étudiant : lecture AVEC SON JETON, la règle d'accès garantit la propriété ;
  //   - appel interne (service_role) : l'appelant fournit le manifeste — il
  //     détient déjà la clé de service, il n'apprend rien de plus.
  let manifeste: unknown;
  if (role(jeton) === 'service_role') {
    manifeste = corps.manifeste;
    if (!manifeste) return json({ error: 'manifeste_requis_en_appel_interne' }, 400);
  } else {
    const etudiant = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false }, global: { headers: { Authorization: `Bearer ${jeton}` } } });
    const { data: u, error: errU } = await etudiant.auth.getUser(jeton);
    if (errU || !u?.user) return json({ error: 'not_authenticated' }, 401);
    const { data: job, error: errJob } = await etudiant.schema('app').from('studio_jobs')
      .select('manifeste').eq('id', jobId).maybeSingle();
    if (errJob) return json({ error: 'lecture_job', detail: errJob.message }, 500);
    // Même réponse pour « absent » et « pas à toi » : la règle d'accès les confond, et c'est voulu.
    if (!job) return json({ error: 'introuvable' }, 404);
    manifeste = job.manifeste;
  }
  const job = { id: jobId.toLowerCase() };

  const scenes = scenesAVoixer(manifeste);
  if (!scenes.length) return json({ error: 'aucune_narration' }, 422);

  const t0 = performance.now();
  const ms = () => Math.round(performance.now() - t0);
  const enc = new TextEncoder();
  let faites = 0, echecs = 0;

  const flux = new ReadableStream({
    async start(controle) {
      const ecrire = (o: unknown) => controle.enqueue(enc.encode(JSON.stringify(o) + '\n'));
      ecrire({ type: 'debut', scenes: scenes.map(({ rang, id }) => ({ rang, id })) });
      await enParallele(scenes, PARALLELE_MAX, async (s) => {
        const chemin = cheminVoix(job.id, s.id);
        try {
          // Déjà faite ? On la rend : une capsule rouverte ne repaie pas sa voix.
          const deja = await service.storage.from(BUCKET).createSignedUrl(chemin, VALIDITE_S);
          if (!deja.error && deja.data?.signedUrl) return { url: deja.data.signedUrl, cache: true };
          const d = performance.now();
          const octets = await synthetiser(s.texte);
          const ms_tts = Math.round(performance.now() - d);
          const dep = await service.storage.from(BUCKET).upload(chemin, octets, { contentType: 'audio/mpeg', upsert: true });
          if (dep.error) throw new Error(`dépôt : ${dep.error.message}`);
          const signe = await service.storage.from(BUCKET).createSignedUrl(chemin, VALIDITE_S);
          if (signe.error || !signe.data?.signedUrl) throw new Error(`signature : ${signe.error?.message ?? 'vide'}`);
          return { url: signe.data.signedUrl, cache: false, ms_tts, octets: octets.byteLength };
        } catch (e) {
          return { erreur: (e as Error).message.slice(0, 300) };
        }
      }, (s, r) => {
        if ('erreur' in r) echecs++; else faites++;
        ecrire({ type: 'voix', rang: s.rang, id: s.id, ...r, ms: ms() });
      });
      ecrire({ type: 'fin', ms: ms(), faites, echecs });
      controle.close();
    },
  });
  return new Response(flux, { headers: { ...CORS, 'Content-Type': 'application/x-ndjson; charset=utf-8', 'Cache-Control': 'no-store' } });
});
