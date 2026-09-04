import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

// BOBODO VOCAL — transcription et voix, pour le WEB.
//
// POURQUOI CETTE FONCTION EXISTE
//
// Sur Android et iOS, Bobodo utilise `speech_to_text` : la reconnaissance
// NATIVE de l'appareil. Elle est gratuite, quasi instantanée, et s'adapte a
// l'accent de son proprietaire. On n'y touche pas.
//
// Sur le web, cette meme API existe (mesure le 04/09/2026 sur
// app.academiea.com : reconnaissance et synthese disponibles, 3 voix
// francaises) — mais seulement dans Chrome et Edge, jamais dans Firefox ni
// Brave, et les voix systeme y sont nettement robotiques. Cette fonction donne
// au web une qualite comparable au reste du produit, et un secours la ou
// l'API du navigateur n'existe pas.
//
// CE QU'ELLE NE FAIT PAS : tourner sur le VPS. La contrainte non negociable
// n°2 du depot — « aucun calcul d'IA sur le VPS » — a ete payee en juin :
// Whisper auto-heberge y saturait 4 coeurs a 261-303 % pour UN utilisateur,
// melangeait les audios de 5 personnes dans un meme tampon, et transcrivait
// « Bobodo » en « Bob au dos ». Verdict archive : NO GO.

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';

// Modeles par defaut, remplacables PAR REQUETE (voir plus bas) : essayer un
// moteur ne doit pas demander un redeploiement, ni changer celui du Smart
// Whiteboard qui est en production.
const STT_MODEL = Deno.env.get('BOBODO_STT_MODEL') ?? 'openai/whisper-large-v3';
const TTS_MODEL = Deno.env.get('BOBODO_TTS_MODEL') ?? 'mistralai/voxtral-mini-tts-2603';
const TTS_VOICE = Deno.env.get('BOBODO_TTS_VOICE') ?? 'fr_marie_neutral';

// Bornes. Une question dictee depasse rarement 30 s ; 25 Mo laisse de la marge
// meme en WAV non compresse. Au-dela, c'est une erreur d'appel, pas un usage.
const MAX_AUDIO_BYTES = 25 * 1024 * 1024;
const MAX_TTS_CHARS = 4000;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

// Le vocabulaire d'Academia, souffle au moteur de transcription.
//
// Ce n'est pas un ornement : l'audit du 14/06 a mesure que « Bobodo » devenait
// « Bob au dos » et « Ki-Zerbo » devenait « Kisebo ». Whisper accepte un
// `prompt` qui oriente son vocabulaire — c'est le levier le plus efficace sur
// les noms propres, et il est gratuit.
const VOCABULAIRE = [
  'Academia', 'Bobodo', 'Burkina Faso', 'Ouagadougou', 'Bobo-Dioulasso',
  'Ki-Zerbo', 'Nazi Boni', 'Norbert Zongo', 'BEPC', 'baccalaureat',
  'licence', 'master', 'filiere', 'orientation', 'bourse', 'concours',
  'candidature', 'inscription', 'FCFA',
].join(', ');

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

/// Le jeton doit etre celui d'un utilisateur connecte. Sans ce controle,
/// n'importe qui consommerait les credits OpenRouter du projet.
///
/// LA SIGNATURE EST VERIFIEE AUPRES DE SUPABASE, pas seulement decodee.
/// Premiere version de cette fonction : elle faisait `atob()` sur la charge
/// utile et lisait le champ `role`. C'etait contournable en trois lignes —
/// fabriquer un base64 contenant {"role":"authenticated"} suffisait. Le
/// deploiement avec `verify_jwt` actif la couvrait (essai reel : un jeton forge
/// recoit 401), mais faire reposer la securite sur un reglage externe qu'un
/// futur deploiement peut desactiver, c'est exactement ce que j'ai refuse le
/// matin meme pour `app_append_bobodo_message`. Deux barrieres, pas une.
async function estAuthentifie(req: Request): Promise<boolean> {
  const brut = req.headers.get('Authorization') ?? '';
  const jeton = brut.replace(/^Bearer\s+/i, '').trim();
  if (!jeton) return false;

  const url = Deno.env.get('SUPABASE_URL') ?? '';
  const cleAnon = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  if (!url || !cleAnon) {
    console.error('[bobodo-vocal] SUPABASE_URL ou SUPABASE_ANON_KEY absente');
    return false;
  }

  try {
    // Supabase valide la signature et l'expiration : on ne fait confiance a
    // aucun champ du jeton avant sa reponse.
    const reponse = await fetch(`${url}/auth/v1/user`, {
      headers: { Authorization: `Bearer ${jeton}`, apikey: cleAnon },
    });
    if (reponse.ok) {
      const utilisateur = await reponse.json();
      return typeof utilisateur?.id === 'string' && utilisateur.id.length > 0;
    }
    return false;
  } catch (e) {
    // Une panne du service d'authentification REFUSE l'appel. Laisser passer
    // « en cas de doute » reviendrait a ouvrir la porte le jour ou elle casse.
    console.error('[bobodo-vocal] verification du jeton impossible', e);
    return false;
  }
}

/// Modeles autorises. Sans cette liste, un utilisateur authentifie pouvait
/// demander N'IMPORTE QUEL modele d'OpenRouter — y compris le plus cher — et
/// faire fondre les credits du projet depuis son telephone.
const STT_AUTORISES = new Set<string>([
  'openai/whisper-large-v3',
  'openai/whisper-large-v3-turbo',
  'openai/gpt-4o-mini-transcribe',
  'microsoft/mai-transcribe-2',
]);
const TTS_AUTORISES = new Set<string>([
  'mistralai/voxtral-mini-tts-2603',
  'hexgrad/kokoro-82m',
  'google/gemini-3.1-flash-tts-preview',
]);

/// Renvoie le modele demande s'il est autorise, `defaut` s'il n'est pas
/// precise, et `null` s'il est refuse — l'appelant repond alors 400 plutot que
/// de retomber silencieusement sur autre chose : un moteur substitue a l'insu
/// de celui qui compare deux moteurs fausse la comparaison.
function modeleAutorise(
  demande: unknown,
  autorises: Set<string>,
  defaut: string,
): string | null {
  if (typeof demande !== 'string' || !demande.trim()) return defaut;
  const propre = demande.trim();
  return autorises.has(propre) ? propre : null;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  if (!(await estAuthentifie(req))) return json({ error: 'unauthenticated' }, 401);
  if (!OPENROUTER_API_KEY) return json({ error: 'OPENROUTER_API_KEY absente' }, 500);

  let charge: Record<string, unknown>;
  try {
    charge = await req.json();
  } catch (_) {
    return json({ error: 'corps JSON invalide' }, 400);
  }

  const action = String(charge.action ?? '');

  // ── TRANSCRIRE ────────────────────────────────────────────────────────────
  if (action === 'transcrire') {
    const audioBase64 = typeof charge.audio === 'string' ? charge.audio : '';
    if (!audioBase64) return json({ error: 'audio manquant' }, 400);

    let octets: Uint8Array<ArrayBuffer>;
    try {
      const binaire = atob(audioBase64);
      // Tampon construit explicitement : sans cela, le type deduit est
      // `ArrayBufferLike`, que `Blob` refuse en verification stricte.
      octets = new Uint8Array(new ArrayBuffer(binaire.length));
      for (let i = 0; i < binaire.length; i++) octets[i] = binaire.charCodeAt(i);
    } catch (_) {
      return json({ error: 'audio base64 illisible' }, 400);
    }
    if (octets.length === 0) return json({ error: 'audio vide' }, 400);
    if (octets.length > MAX_AUDIO_BYTES) {
      return json({ error: `audio trop volumineux (max ${MAX_AUDIO_BYTES} octets)` }, 400);
    }

    const modele = modeleAutorise(charge.model, STT_AUTORISES, STT_MODEL);
    if (modele === null) {
      return json({
        error: 'modele de transcription non autorise',
        autorises: [...STT_AUTORISES],
      }, 400);
    }
    const typeMime = typeof charge.mime === 'string' && charge.mime.trim()
      ? charge.mime.trim()
      : 'audio/webm';
    const extension = typeMime.includes('wav') ? 'wav'
      : typeMime.includes('mp4') || typeMime.includes('m4a') ? 'mp4'
      : typeMime.includes('ogg') ? 'ogg'
      : 'webm';

    const formulaire = new FormData();
    formulaire.append('file', new Blob([octets], { type: typeMime }), `question.${extension}`);
    formulaire.append('model', modele);
    // `fr` IMPOSE, jamais devine : sur une question courte, la detection
    // automatique se trompe de langue et rend un charabia plausible.
    formulaire.append('language', 'fr');
    formulaire.append('prompt', VOCABULAIRE);

    try {
      const reponse = await fetch('https://openrouter.ai/api/v1/audio/transcriptions', {
        method: 'POST',
        headers: { Authorization: `Bearer ${OPENROUTER_API_KEY}` },
        body: formulaire,
      });
      if (!reponse.ok) {
        const detail = (await reponse.text()).slice(0, 400);
        console.error(`[bobodo-vocal] transcription ${reponse.status} modele=${modele}: ${detail}`);
        return json({ error: 'transcription indisponible', status: reponse.status, detail }, 502);
      }
      const data = await reponse.json();
      const texte = String(data?.text ?? '').trim();
      if (!texte) return json({ error: 'transcription vide' }, 502);
      // `modele` est renvoye pour qu'on sache TOUJOURS quel moteur a produit ce
      // texte — sans quoi comparer deux moteurs releverait du souvenir.
      return json({ texte, modele });
    } catch (e) {
      console.error('[bobodo-vocal] transcription erreur', e);
      return json({ error: String(e) }, 502);
    }
  }

  // ── PARLER ────────────────────────────────────────────────────────────────
  if (action === 'parler') {
    const texte = typeof charge.texte === 'string' ? charge.texte.trim() : '';
    if (!texte) return json({ error: 'texte manquant' }, 400);
    if (texte.length > MAX_TTS_CHARS) {
      return json({ error: `texte trop long (max ${MAX_TTS_CHARS} caracteres)` }, 400);
    }

    const modele = modeleAutorise(charge.model, TTS_AUTORISES, TTS_MODEL);
    if (modele === null) {
      return json({
        error: 'modele de voix non autorise',
        autorises: [...TTS_AUTORISES],
      }, 400);
    }
    // La voix n'est pas une liste blanche : elle ne change pas le coût, elle
    // dépend du modèle choisi, et une voix inconnue est refusée par le moteur
    // lui-même avec un message clair. On borne sa longueur, rien de plus.
    const voixDemandee = typeof charge.voice === 'string' ? charge.voice.trim() : '';
    const voix = voixDemandee.length > 0 && voixDemandee.length <= 64
      ? voixDemandee
      : TTS_VOICE;

    try {
      const reponse = await fetch('https://openrouter.ai/api/v1/audio/speech', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${OPENROUTER_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ model: modele, input: texte, voice: voix }),
      });
      if (!reponse.ok) {
        const detail = (await reponse.text()).slice(0, 400);
        console.error(`[bobodo-vocal] voix ${reponse.status} modele=${modele}: ${detail}`);
        return json({ error: 'voix indisponible', status: reponse.status, detail }, 502);
      }
      const audio = new Uint8Array(await reponse.arrayBuffer());
      let binaire = '';
      // Par tranches : `String.fromCharCode(...tableau)` depasse la pile
      // d'appels sur un audio de quelques centaines de kilo-octets.
      const TRANCHE = 8192;
      for (let i = 0; i < audio.length; i += TRANCHE) {
        binaire += String.fromCharCode(...audio.subarray(i, i + TRANCHE));
      }
      return json({ audio: btoa(binaire), mime: 'audio/mpeg', modele, voix });
    } catch (e) {
      console.error('[bobodo-vocal] voix erreur', e);
      return json({ error: String(e) }, 502);
    }
  }

  return json({ error: "action inconnue — attendu « transcrire » ou « parler »" }, 400);
});
