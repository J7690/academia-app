// Supabase Edge Function: bobodo-chat
// Re-implementation of the former FastAPI /bobodo/chat endpoint using Supabase RPCs
// and OpenRouter, with strict authentication via Supabase JWT.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';
const OPENROUTER_EMBEDDING_MODEL = Deno.env.get('OPENROUTER_EMBEDDING_MODEL') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

// CORS headers for browser clients (Flutter Web, SPAs, etc.)
const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept,x-client-info',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY for bobodo-chat Edge Function');
}

// [FIX P2] Phrases précises au lieu de mots isolés pour éviter les faux positifs
// (ex: 'armes' bloquait 'mes armes pour réussir', 'drogue' bloquait 'politique anti-drogue')
// [FIX P4] Ajout couches: violence, corruption, religion, Dieu, sexualité élargie
const SENSITIVE_PHRASES: string[] = [
  // ── Terrorisme / explosifs ──
  'terrorisme', 'acte terroriste', 'attaque terroriste',
  'fabriquer une bombe', 'bombe artisanale', 'fabriquer un explosif',
  'faire exploser', 'faire sauter',
  'massacre', 'fusillade de masse',
  // ── Violence / meurtre / suicide ──
  'me suicider', 'me tuer', 'envie de mourir', 'mettre fin à ma vie',
  'tuer quelqu\'un', 'tuer une personne', 'assassiner',
  'me faire du mal', 'me mutiler', 'automutilation',
  'violence conjugale', 'battre quelqu\'un', 'frapper quelqu\'un',
  'torture', 'torturer', 'enlèvement', 'kidnapping', 'kidnapper',
  'génocide', 'crime de guerre', 'crime contre l\'humanité',
  // ── Sexualité / pornographie ──
  'pornographie', 'porno', 'contenu sexuel explicite',
  'viol', 'pédophilie', 'pedophilie', 'contenu pédopornographique',
  'sexe explicite', 'acte sexuel', 'relation sexuelle',
  'prostitution', 'escort', 'strip-tease', 'striptease',
  'nudité', 'nu intégral', 'contenu adulte', 'contenu pour adulte',
  'orgasme', 'masturbation', 'sodomie', 'fellation',
  // ── Religion / Dieu ──
  'dieu', 'allah', 'jésus', 'jesus', 'prophète', 'prophete',
  'bible', 'coran', 'torah', 'évangile', 'evangile',
  'religion', 'religieux', 'religieuse',
  'christianisme', 'islam', 'judaïsme', 'judaisme', 'bouddhisme', 'hindouisme',
  'église', 'eglise', 'mosquée', 'mosquee', 'synagogue', 'temple',
  'prière', 'priere', 'prier',
  'spiritualité', 'spiritualite', 'ésotérisme', 'esoterisme',
  'secte', 'sectaire', 'radicalisation',
  // ── Corruption / politique ──
  'corruption', 'corrompre', 'pot-de-vin', 'pot de vin',
  'blanchiment d\'argent', 'blanchiment', 'fraude fiscale',
  'détournement de fonds', 'détournement',
  // ── Extrémisme / idéologies ──
  'nazisme', 'idéologie nazie', 'suprematie blanche',
  'extrémisme', 'extremisme', 'radicalisme',
  // ── Armes / drogues ──
  'fabriquer une arme', 'arme de guerre', 'arme illégale', 'arme de destruction',
  'trafic de drogue', 'vendre de la drogue', 'dealer de drogue',
  'cannabis', 'cocaïne', 'cocaine', 'héroïne', 'heroine', 'crack', 'ecstasy',
  // ── Piratage ──
  'pirater', 'hacker un compte', 'accès non autorisé',
];

function isSensitiveQuery(message: string): boolean {
  const text = message.toLowerCase();
  return SENSITIVE_PHRASES.some((phrase) => text.includes(phrase));
}

// [FIX P4] Bloquer TOUTES les questions sur les universités (partenaires ou non).
// L'utilisateur doit consulter l'onglet Universités de la plateforme Academia.
const UNIVERSITY_KEYWORDS: string[] = [
  'université', 'universite', 'universitaire',
  'universités partenaires', 'universites partenaires',
  'quelles universités', 'quelles universites',
  'liste des universités', 'liste des universites',
  'université partenaire', 'universite partenaire',
  'école', 'ecole', 'grande école', 'grande ecole',
  'centre de formation',
  'lycée', 'lycee',
  'institut', 'faculté', 'faculte',
  'campus', 'établissement', 'etablissement',
  'inscription université', 'inscription universite',
  'admission université', 'admission universite',
  'université publique', 'universite publique',
  'université privée', 'universite privee',
  'partenaires de nexiom', 'partenaires nexiom',
  'partenaires d\'academia', 'partenaires academia',
];

const UNIVERSITY_REFUSAL_MESSAGE =
  'Je ne suis pas en mesure de fournir des informations sur les universités, ' +
  'écoles ou établissements de formation. ' +
  'Pour consulter la liste des universités partenaires et obtenir toutes les informations détaillées, ' +
  'je t\'invite à te rendre dans l\'onglet **Universités** de la plateforme Academia. ' +
  'Tu y trouveras les programmes, conditions d\'admission et contacts de chaque établissement partenaire. ' +
  'Y a-t-il autre chose sur lequel je peux t\'aider ?';

function isUniversityQuery(message: string): boolean {
  const text = message.toLowerCase();
  return UNIVERSITY_KEYWORDS.some((kw) => text.includes(kw));
}

async function embedQuery(text: string): Promise<string | null> {
  const trimmed = text.trim();
  if (!trimmed) return null;
  if (!OPENROUTER_API_KEY) return null;
  if (!OPENROUTER_EMBEDDING_MODEL) return null;

  const payload = {
    model: OPENROUTER_EMBEDDING_MODEL,
    input: trimmed,
  };

  const resp = await fetch('https://openrouter.ai/api/v1/embeddings', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!resp.ok) {
    const body = await resp.text();
    console.error(
      `OpenRouter embeddings error status=${resp.status} model=${OPENROUTER_EMBEDDING_MODEL} body=${body.slice(0, 500)}`,
    );
    return null;
  }

  const data = await resp.json();
  const arr = Array.isArray(data?.data) ? data.data : null;
  if (!arr || !arr.length) return null;
  const first = arr[0] as { embedding?: unknown };
  const rawVec = (first?.embedding as unknown) as unknown[] | undefined;
  if (!Array.isArray(rawVec) || !rawVec.length) return null;

  const normalized = rawVec.map((x) => {
    const v = typeof x === 'number' ? x : Number(x);
    if (!Number.isFinite(v)) return 0;
    return Number(v.toFixed(8));
  });

  const inner = normalized.join(',');
  return `[${inner}]`;
}

type ChatHistoryMessage = { role: 'user' | 'assistant'; content: string };

async function callOpenRouter(
  prompt: string,
  knowledge: Array<Record<string, unknown>>,
  options?: {
    systemPrompt?: string | null;
    includeNoAnswerSentinel?: boolean;
    history?: ChatHistoryMessage[];
    max_tokens?: number;
    stream?: boolean;
  },
): Promise<string | ReadableStream<Uint8Array>> {
  const systemPrompt = options?.systemPrompt ?? null;
  const includeNoAnswerSentinel = options?.includeNoAnswerSentinel ?? true;
  const history = options?.history ?? [];

  if (!OPENROUTER_API_KEY || !OPENROUTER_MODEL) {
    throw new Error('OPENROUTER_API_KEY or OPENROUTER_MODEL not configured');
  }

  const basePrompt = (prompt ?? '').trim();
  if (!basePrompt) {
    throw new Error('Prompt vide');
  }

  const knowledgeParts: string[] = [];
  for (const raw of knowledge ?? []) {
    const item = raw as Record<string, unknown>;
    const title = (item.title ?? '').toString().trim();
    const content = (item.content ?? '').toString().trim();
    if (!content) continue;
    if (title) {
      knowledgeParts.push(`### ${title}\n${content}`);
    } else {
      knowledgeParts.push(content);
    }
  }

  let finalUserPrompt = basePrompt;
  const knowledgeText = knowledgeParts.join('\n\n');
  if (knowledgeText) {
    finalUserPrompt = `${basePrompt}\n\nContexte (RAG):\n${knowledgeText}`;
  }

  const NO_ANSWER_SENTINEL = '__BOBODO_NO_ANSWER__';
  if (includeNoAnswerSentinel) {
    finalUserPrompt =
      finalUserPrompt +
      `\n\nSi tu ne peux pas répondre de façon fiable, réponds exactement par: ${NO_ANSWER_SENTINEL}`;
  }

  const messages: Array<{ role: 'system' | 'user' | 'assistant'; content: string }> = [];
  if (systemPrompt) {
    messages.push({ role: 'system', content: systemPrompt });
  }
  for (const h of history) {
    const content = (h?.content ?? '').toString().trim();
    if (!content) continue;
    const role: 'user' | 'assistant' = h.role === 'assistant' ? 'assistant' : 'user';
    messages.push({ role, content });
  }
  messages.push({ role: 'user', content: finalUserPrompt });

  const modelsToTry = [
    OPENROUTER_MODEL,
    OPENROUTER_FALLBACK_MODEL,
  ].filter(m => m);
  const maxTokens = options?.max_tokens ?? 500;
  const stream = options?.stream ?? false;
  const errors: string[] = [];

  for (const model of modelsToTry) {
    if (!model) continue;
    try {
      const payload = {
        model,
        messages,
        temperature: 0.2,
        max_tokens: maxTokens,
        stream: stream,
      };

      const headers: Record<string, string> = {
        Authorization: `Bearer ${OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
      };

      if (stream) {
        headers['Accept'] = 'text/event-stream';
      } else {
        headers['Accept'] = 'application/json';
      }

      const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
      });

      if (!resp.ok) {
        const text = await resp.text();
        errors.push(`${model}(${resp.status}): ${text.slice(0, 100)}`);
        console.log(`[bobodo-chat] ${model} failed (${resp.status}), trying next...`);
        continue;
      }

      if (stream) {
        // Return the stream directly for streaming responses
        return resp.body!;
      } else {
        const data = await resp.json();
        const choices = Array.isArray(data?.choices) ? data.choices : null;
        if (!choices || !choices.length) {
          errors.push(`${model}: no choices`);
          continue;
        }

        const first = choices[0];
        const msgContent = first?.message;
        const content = (msgContent?.content ?? '').toString().trim();
        if (!content) {
          errors.push(`${model}: empty content`);
          continue;
        }

        return content;
      }
    } catch (e) {
      errors.push(`${model}: ${(e as Error).message?.slice(0, 80)}`);
      console.log(`[bobodo-chat] ${model} error, trying next...`);
    }
  }

  throw new Error(`All models failed: ${errors.join(' | ')}`);
}

async function callOpenRouterSafetyRefusal(message: string): Promise<string> {
  const systemPrompt =
    "Tu es un assistant IA pour la plateforme Academia. L'utilisateur demande un contenu sensible ou dangereux. " +
    "Tu dois refuser poliment en français, expliquer brièvement que tu ne peux pas aider, et proposer une alternative sûre " +
    "(conseils généraux, prévention, orientation vers un professionnel).";

  return await callOpenRouter(message, [], {
    systemPrompt,
    includeNoAnswerSentinel: false,
  });
}

// Streaming SSE decoder
async function* streamSSE(reader: ReadableStreamDefaultReader<Uint8Array>) {
  const decoder = new TextDecoder();
  let buffer = '';

  for await (const chunk of reader) {
    buffer += decoder.decode(chunk, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() || '';

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = line.slice(6);
        if (data === '[DONE]') return;
        try {
          const parsed = JSON.parse(data);
          const content = parsed.choices?.[0]?.delta?.content;
          if (content) yield content;
        } catch (e) {
          console.error('Error parsing SSE line:', e);
        }
      }
    }
  }
}

// ── HELPERS V2 ────────────────────────────────────────────────────────────

/**
 * Détecte l’état émotionnel du message : suivi, frustration, satisfaction, neutre.
 * Base sur patterns simples, zéro appel IA.
 */
function detectEmotionalState(
  message: string,
  history: ChatHistoryMessage[],
): 'neutral' | 'frustrated' | 'satisfied' | 'follow_up' {
  const text = message.trim().toLowerCase();

  // ── COUCHE 1 : Réactions à un seul mot / ultra-courtes ──────────────
  // Réponses typiques de cette génération : "oui", "non", "ok", "waw", "vraiment?"
  const oneWordReactions = [
    'oui', 'non', 'ok', 'okay', 'oki', 'okok', 'd\'acc', 'dac', 'vu', 'reçu', 'compris',
    'waw', 'waaw', 'waouh', 'wow', 'ah', 'oh', 'aïe', 'aie', 'aha',
    'vraiment', 'sérieux', 'serieux', 'c\'est vrai', 'pour de vrai', 'c\'est sûr', 'c\'est sur',
    'genre', 'et alors', 'et donc', 'et après', 'et apres', 'ensuite', 'après', 'apres',
    'continue', 'vas-y', 'vas y', 'allons-y', 'allons y', 'je vois', 'logique', 'normal',
    'trop bien', 'c\'est chaud', 'c\'est cool', 'intéressant', 'interessant', 'sympa',
    'pourquoi', 'comment', 'quand', 'où', 'ou', 'combien', 'lequel', 'laquelle',
    'dans mon cas', 'pour moi', 'et moi', 'dans mon cas', 'en pratique',
  ];
  if (history.length >= 1 && oneWordReactions.some((p) => text === p || text === p + '?' || text === p + ' ?')) {
    return 'follow_up';
  }

  // ── COUCHE 2 : Confirmation / reformulation — l'utilisateur valide ce qu'il a compris ──
  const confirmationPatterns = [
    'ah ok', 'ok donc', 'donc c\'est', 'donc il', 'donc on', 'donc vous',
    'c\'est bien ça', 'c\'est ça?', 'c\'est ça ?', 'c est bien ca', 'c est ca',
    'au cas par cas', 'c\'est au cas', 'selon les cas', 'ça dépend', 'ca depend',
    'en gros', 'autrement dit', 'en d\'autres termes', 'c\'est à dire', 'c est a dire',
    'si je comprends bien', 'si je comprends', 'si j\'ai bien compris', 'si j ai bien compris',
    'si je résume', 'si je resume', 'pour résumer', 'pour résumé',
    'c\'est correct', 'est-ce bien', 'est ce bien', 'c\'est exact', 'c est exact',
    'c\'est pour ça', 'c est pour ca', 'c\'est pourquoi', 'voilà pourquoi', 'voila pourquoi',
    'ça veut dire', 'ca veut dire', 'ça signifie', 'ca signifie',
    'ok je comprends', 'ok je vois', 'ah je vois', 'je vois donc',
    "j'ai bien compris", "j'ai compris", "bien compris",
    'pas garanti', 'pas fixe', 'pas précis', 'pas precis',
  ];
  if (confirmationPatterns.some((p) => text.includes(p)) && history.length >= 1) {
    return 'follow_up';
  }

  // ── COUCHE 3 : Message court avec point d'interrogation → relance implicite ──
  // Ex: "et pour les partenaires?", "c'est combien?", "dans mon cas?"
  if (text.endsWith('?') && text.length < 80 && history.length >= 1) {
    return 'follow_up';
  }

  // ── COUCHE 4 : Message court en contexte actif (Bobodo venait de parler) ──
  if (text.length < 100 && history.length >= 2) {
    const lastAssistant = [...history].reverse().find((h) => h.role === 'assistant');
    if (lastAssistant) return 'follow_up';
  }

  // Frustration / incompréhension
  if (
    [
      'pas clair', 'pas compris', 'je comprends pas', 'comprends pas', 'ne comprends pas',
      'pas satisfait', 'pas satisfaisante', 'mauvaise réponse', 'pas ce que je cherchais',
      "c'est pas ça", "c'est pas ce que", 'reformule', 'explique mieux', 'pas utile',
      'inutile', 'faux', 'incorrect', 'pas la bonne', 'autre explication', 're-explique',
      'non pas', 'non, pas', 'non ce n', 'pas vraiment',
      'tu ne réponds pas', 'tu ne réponds pas à ma question', 'tu ne réponds pas ma question',
    ].some((k) => text.includes(k))
  ) return 'frustrated';

  // Satisfaction / remerciements
  if (
    [
      'merci', 'super', 'excellent', 'parfait', 'très bien', 'tres bien',
      'bien compris', "d'accord", 'ok merci', 'nickel', 'top', 'génial', 'genial',
      'satisfait', "c'est clair", "j'ai compris", 'bien vu', 'impeccable', "c'est bon",
    ].some((k) => text.includes(k))
  ) return 'satisfied';

  return 'neutral';
}

/**
 * Génère 2 reformulations sémantiques de la question pour le RAG.
 * Appelée uniquement quand la recherche initiale n’a rien trouvé (évite la latence sur cache hit).
 */
async function generateSemanticVariants(
  message: string,
  history: ChatHistoryMessage[],
): Promise<string[]> {
  if (!OPENROUTER_API_KEY || message.trim().length < 8) return [message];

  const lastMsgs = history
    .slice(-4)
    .map((h) => `${h.role === 'user' ? 'Utilisateur' : 'Bobodo'}: ${h.content.trim().slice(0, 80)}`)
    .join('\n');

  const contextHint = lastMsgs ? `\nContexte récent:\n${lastMsgs}\n\n` : '';
  const systemPrompt =
    'Génère 2 reformulations sémantiques différentes de la question, en conservant son sens exact. ' +
    'Réponds UNIQUEMENT avec 2 lignes, une reformulation par ligne, sans numérotation ni explication.';

  try {
    const raw = await callOpenRouter(`${contextHint}Question: ${message}`, [], {
      systemPrompt,
      includeNoAnswerSentinel: false,
      max_tokens: 100,
    });
    const lines = raw
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l.length > 4 && l.toLowerCase() !== message.trim().toLowerCase());
    return [message, ...lines.slice(0, 2)];
  } catch {
    return [message];
  }
}

/**
 * Recherche web via Perplexity sonar-small-online (accès internet réel).
 * Utilisé comme fallback quand la base locale ne contient aucun résultat pertinent.
 * Désactivé pour NEXIOM_ACADEMIA_INTERNE (on doit connaître nos propres infos)
 * et SMALL_TALK_EMOTION (pas besoin du web pour les émotions).
 */
async function searchWebWithPerplexity(
  query: string,
  category: string,
): Promise<string | null> {
  // ARCHITECTURE 3 NIVEAUX — Règles de déclenchement du niveau 2 (web) :
  // ✅ ORIENTATION_ETUDES_EMPLOI : conseils d'orientation générale quand base locale vide
  // ❌ NEXIOM_ACADEMIA_INTERNE   : on doit connaître nos propres infos — pas de web
  // ❌ SMALL_TALK_EMOTION        : émotions/salutations ne nécessitent pas de web
  // ❌ AUTRE_UNIVERSITE_OU_ENTREPRISE : interdit de donner des infos sur les universités (toutes)
  // ❌ PARTENAIRE_UNIVERSITE_DETAILLEE  : interdit aussi — rediriger vers l'onglet Universités
  // ❌ PARTENAIRE_UNIVERSITE_DETAILLEE: les infos partenaires viennent de la base interne
  // ❌ HORS_SCOPE                : Bobodo n'est pas un assistant général web
  if (
    !OPENROUTER_API_KEY ||
    category !== 'ORIENTATION_ETUDES_EMPLOI'
  ) return null;

  try {
    const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'perplexity/sonar-small-online',
        messages: [
          {
            role: 'system',
            content:
              'Tu es un assistant éducatif qui répond en français. ' +
              'Fournis une réponse factuelle, utile et concise (3 à 5 phrases) basée sur des sources fiables. ' +
              'Concentre-toi sur l\'essentiel, sans introduction inutile.',
          },
          { role: 'user', content: query },
        ],
        max_tokens: 400,
        temperature: 0.1,
      }),
    });

    if (!resp.ok) return null;
    const data = await resp.json();
    const content = (data?.choices?.[0]?.message?.content ?? '').toString().trim();
    return content || null;
  } catch (e) {
    console.error('searchWebWithPerplexity error', e);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CACHE SÉMANTIQUE — évite les appels OpenRouter pour les questions déjà vues
// Toutes les fonctions sont best-effort : toute erreur → null, le flow normal reprend
// ─────────────────────────────────────────────────────────────────────────────

async function checkAnswerCache(
  embedding: string,
  supabaseService: ReturnType<typeof createClient>,
): Promise<{ answer: string; cacheId: string } | null> {
  try {
    const { data, error } = await supabaseService.rpc('app_search_bobodo_answer_cache', {
      p_query_embedding: embedding,
      p_threshold: 0.92,
    });
    if (error || !data) return null;
    const rows = Array.isArray(data) ? data : ((data as any)?.result ?? []);
    const row = rows[0];
    if (!row?.answer) return null;
    return { answer: String(row.answer), cacheId: String(row.cache_id) };
  } catch {
    return null;
  }
}

async function registerCacheHit(
  cacheId: string,
  supabaseService: ReturnType<typeof createClient>,
): Promise<void> {
  try {
    await supabaseService.rpc('app_bobodo_cache_hit', { p_cache_id: cacheId });
  } catch { /* best-effort */ }
}

async function saveAnswerToCache(
  questionText: string,
  embedding: string,
  answer: string,
  category: string | null,
  supabaseService: ReturnType<typeof createClient>,
): Promise<void> {
  try {
    await supabaseService.rpc('app_insert_bobodo_answer_cache', {
      p_question_text: questionText,
      p_question_embedding: embedding,
      p_answer_text: answer,
      p_category: category ?? null,
    });
  } catch { /* best-effort */ }
}

// [FIX P3] searchKnowledge accepte un contexte optionnel (historique récent) pour enrichir la recherche RAG
async function searchKnowledge(supabaseService: ReturnType<typeof createClient>, query: string, recentHistory?: ChatHistoryMessage[]) {
  // Enrichir la query avec les derniers messages si la question est trop courte (<30 chars)
  let effectiveQuery = query.trim();
  if (effectiveQuery.length < 30 && recentHistory && recentHistory.length >= 2) {
    const lastUserMsgs = recentHistory
      .filter((h) => h.role === 'user')
      .slice(-2)
      .map((h) => h.content.trim())
      .join(' ');
    if (lastUserMsgs) {
      effectiveQuery = `${lastUserMsgs} ${effectiveQuery}`.trim().slice(0, 300);
    }
  }
  const trimmed = effectiveQuery;
  if (!trimmed) return [] as Array<Record<string, unknown>>;

  function extractList(raw: unknown): Array<Record<string, unknown>> {
    if (Array.isArray(raw)) return raw as Array<Record<string, unknown>>;
    if (raw && typeof raw === 'object' && 'result' in (raw as Record<string, unknown>)) {
      const r = (raw as Record<string, unknown>).result;
      if (Array.isArray(r)) return r as Array<Record<string, unknown>>;
    }
    return [];
  }

  let knowledge: Array<Record<string, unknown>> = [];

  try {
    const vec = await embedQuery(trimmed);
    if (vec) {
      const { data: vecData, error: vecError } = await supabaseService.rpc('app_search_bobodo_knowledge_vector', {
        p_embedding: vec,
        p_limit: 5,
      });
      if (vecError) {
        console.error('app_search_bobodo_knowledge_vector error', vecError.message);
      } else {
        knowledge = extractList(vecData);
      }
    }
  } catch (e) {
    console.error('searchKnowledge vector error', e);
  }

  if (knowledge.length) return knowledge;

  const { data, error } = await supabaseService.rpc('app_search_bobodo_knowledge', {
    p_query: trimmed,
    p_category: null,
  });
  if (error) {
    console.error('app_search_bobodo_knowledge error', error.message);
  }
  knowledge = extractList(data);
  if (knowledge.length) return knowledge;

  const lower = trimmed.toLowerCase();
  const terms: string[] = [];
  if (lower.includes('nexiom') || lower.includes('nexium')) terms.push('nexiom');
  if (lower.includes('academia')) terms.push('academia');

  const combined: Array<Record<string, unknown>> = [];
  for (const term of terms) {
    try {
      const { data: dataTerm } = await supabaseService.rpc('app_search_bobodo_knowledge', {
        p_query: term,
        p_category: null,
      });
      combined.push(...extractList(dataTerm));
    } catch (e) {
      console.error('app_search_bobodo_knowledge fallback error', e);
    }
  }
  if (combined.length) return combined;

  // ── EXPANSION SÉMANTIQUE V2 ──────────────────────────────────
  // Si TOUT a échoué, générer 2 reformulations et réessayer.
  // Cela permet de répondre correctement même si la question est formulée différemment.
  if (trimmed.length > 5) {
    try {
      const variants = await generateSemanticVariants(query, recentHistory ?? []);
      for (const variant of variants.slice(1)) { // skip [0] = original déjà essayé
        const vt = variant.trim();
        if (!vt || vt.toLowerCase() === trimmed.toLowerCase()) continue;

        // Vector search avec variante
        const vec2 = await embedQuery(vt);
        if (vec2) {
          const { data: vd2 } = await supabaseService.rpc('app_search_bobodo_knowledge_vector', {
            p_embedding: vec2,
            p_limit: 3,
          });
          const r2 = extractList(vd2);
          if (r2.length) return r2;
        }

        // Text search avec variante
        const { data: td2 } = await supabaseService.rpc('app_search_bobodo_knowledge', {
          p_query: vt,
          p_category: null,
        });
        const r3 = extractList(td2);
        if (r3.length) return r3;
      }
    } catch (e) {
      console.error('searchKnowledge semantic expansion error', e);
    }
  }

  return [];
}

// [FIX P3] Historique étendu à 14 messages (7 échanges complets) pour meilleur contexte
async function loadConversationHistoryForSession(
  supabaseForUser: ReturnType<typeof createClient>,
  sessionId: string,
  maxMessages = 14,
): Promise<ChatHistoryMessage[]> {
  if (!sessionId) return [];

  try {
    const { data, error } = await supabaseForUser.rpc('app_list_bobodo_messages', {
      p_session_id: sessionId,
    });

    if (error) {
      console.error('app_list_bobodo_messages error', error.message);
      return [];
    }

    let rows: any[] = [];
    if (Array.isArray(data)) {
      rows = data as any[];
    } else if (data && typeof data === 'object' && 'result' in (data as Record<string, unknown>)) {
      const r = (data as any).result;
      if (Array.isArray(r)) rows = r as any[];
    }

    const history: ChatHistoryMessage[] = [];
    for (const raw of rows) {
      const row = raw as Record<string, unknown>;
      const sender = (row.sender ?? '').toString();
      const content = (row.content ?? '').toString().trim();
      if (!content) continue;

      if (sender === 'student') {
        history.push({ role: 'user', content });
      } else if (sender === 'assistant') {
        history.push({ role: 'assistant', content });
      }
    }

    if (history.length > maxMessages) {
      return history.slice(history.length - maxMessages);
    }

    return history;
  } catch (e) {
    console.error('loadConversationHistoryForSession error', e);
    return [];
  }
}

// [PHASE 1] Récupération du profil étudiant pour injection dans le prompt
async function loadStudentProfile(
  supabaseForUser: ReturnType<typeof createClient>,
  sessionId: string,
): Promise<Record<string, unknown>> {
  if (!sessionId) return {};

  try {
    // Récupérer le student_id depuis la session
    const { data: sessionData, error: sessionError } = await supabaseForUser
      .from('bobodo_sessions')
      .select('student_id')
      .eq('id', sessionId)
      .single();

    if (sessionError || !sessionData?.student_id) {
      console.error('Error fetching session for profile', sessionError?.message);
      return {};
    }

    const studentId = sessionData.student_id as string;

    // Récupérer le profil étudiant
    const { data: studentData, error: studentError } = await supabaseForUser
      .from('students')
      .select('full_name, bac_series, bac_year, bac_mention, bac_institution, bac_country, bepc_year, bepc_mention, bepc_institution, bepc_country, study_project_text, country, city, bio')
      .eq('id', studentId)
      .single();

    if (studentError || !studentData) {
      console.error('Error fetching student profile', studentError?.message);
      return {};
    }

    // Récupérer les candidatures récentes
    const { data: applicationsData, error: applicationsError } = await supabaseForUser
      .from('applications')
      .select('program_id, status, created_at')
      .eq('student_id', studentId)
      .order('created_at', { ascending: false })
      .limit(5);

    const applications = applicationsError ? [] : (applicationsData ?? []);

    // Extraire le prénom (premier mot)
    const fullName = (studentData.full_name ?? '') as string;
    const firstName = fullName.split(' ')[0] || '';

    return {
      first_name: firstName,
      full_name: fullName,
      bac_series: studentData.bac_series,
      bac_year: studentData.bac_year,
      bac_mention: studentData.bac_mention,
      bac_institution: studentData.bac_institution,
      bac_country: studentData.bac_country,
      bepc_year: studentData.bepc_year,
      bepc_mention: studentData.bepc_mention,
      bepc_institution: studentData.bepc_institution,
      bepc_country: studentData.bepc_country,
      study_project: studentData.study_project_text,
      country: studentData.country,
      city: studentData.city,
      bio: studentData.bio,
      applications: applications,
    };
  } catch (e) {
    console.error('loadStudentProfile error', e);
    return {};
  }
}

// [PHASE 2] Récupération de la mémoire cross-session
async function loadCrossSessionMemory(
  supabaseForUser: ReturnType<typeof createClient>,
  sessionId: string,
): Promise<Record<string, unknown>> {
  if (!sessionId) return {};

  try {
    // Récupérer le student_id depuis la session
    const { data: sessionData, error: sessionError } = await supabaseForUser
      .from('bobodo_sessions')
      .select('student_id')
      .eq('id', sessionId)
      .single();

    if (sessionError || !sessionData?.student_id) {
      console.error('Error fetching session for cross-session memory', sessionError?.message);
      return {};
    }

    const studentId = sessionData.student_id as string;

    // Récupérer la mémoire cross-session via RPC
    const { data: memoryData, error: memoryError } = await supabaseForUser.rpc(
      'get_bobodo_cross_session_memory',
      { p_student_id: studentId }
    );

    if (memoryError || !memoryData) {
      console.error('Error fetching cross-session memory', memoryError?.message);
      return {};
    }

    return memoryData as Record<string, unknown>;
  } catch (e) {
    console.error('loadCrossSessionMemory error', e);
    return {};
  }
}

// [PHASE 2] Génération et sauvegarde du résumé de conversation
async function saveConversationSummary(
  supabaseService: ReturnType<typeof createClient>,
  sessionId: string,
  history: ChatHistoryMessage[],
): Promise<void> {
  if (!sessionId || history.length < 4) {
    // Ne résumer que s'il y a au moins 2 échanges (4 messages)
    return;
  }

  try {
    // Générer le résumé via OpenRouter
    const conversationText = history
      .map((msg) => `${msg.role === 'user' ? 'Étudiant' : 'Bobodo'}: ${msg.content}`)
      .join('\n');

    const summaryPrompt = `Résume cette conversation en 2-3 phrases maximum. Identifie les intérêts, objectifs d'étude et préférences de l'étudiant.\n\nConversation:\n${conversationText}`;

    const summary = await callOpenRouter(summaryPrompt, [], {
      systemPrompt: 'Tu es un assistant qui résume des conversations entre un étudiant et Bobodo. Résume en 2-3 phrases maximum. Identifie les intérêts, objectifs et préférences.',
      includeNoAnswerSentinel: false,
      max_tokens: 150,
    });

    if (!summary || summary.includes('__BOBODO_NO_ANSWER__')) {
      return;
    }

    // Sauvegarder le résumé via RPC
    const { error: saveError } = await supabaseService.rpc(
      'save_bobodo_conversation_memory',
      {
        p_session_id: sessionId,
        p_summary: summary,
        p_interests: null,
        p_study_goals: null,
        p_preferences: null,
        p_key_information: null,
      }
    );

    if (saveError) {
      console.error('Error saving conversation summary', saveError.message);
    } else {
      console.log('Conversation summary saved successfully');
    }
  } catch (e) {
    console.error('saveConversationSummary error', e);
  }
}

// [PHASE 4] Enregistrement de l'état émotionnel
async function logEmotionalState(
  supabaseService: ReturnType<typeof createClient>,
  sessionId: string,
  emotionalState: string,
): Promise<void> {
  if (!sessionId || !emotionalState) {
    return;
  }

  // Ne logger que les états significatifs (pas greeting, follow_up, confirmation, neutral)
  const significantStates = new Set(['satisfied', 'frustrated', 'emotional']);
  if (!significantStates.has(emotionalState)) {
    return;
  }

  try {
    const { error: logError } = await supabaseService.rpc(
      'log_bobodo_emotional_state',
      {
        p_session_id: sessionId,
        p_emotional_state: emotionalState,
      }
    );

    if (logError) {
      console.error('Error logging emotional state', logError.message);
    } else {
      console.log(`Emotional state logged: ${emotionalState}`);
    }
  } catch (e) {
    console.error('logEmotionalState error', e);
  }
}

async function logDetectedNeed(
  supabaseService: ReturnType<typeof createClient>,
  sessionId: string,
  question: string,
  category: string,
): Promise<void> {
  const usefulCategories = new Set([
    'NEXIOM_ACADEMIA_INTERNE',
    'ORIENTATION_ETUDES_EMPLOI',
    'PARTENAIRE_UNIVERSITE_DETAILLEE',
    'AUTRE_UNIVERSITE_OU_ENTREPRISE',
  ]);

  if (!usefulCategories.has(category)) return;

  let needSummary = question.trim();

  if (OPENROUTER_API_KEY) {
    const needSystemPrompt =
      "Tu es Bobodo, assistant IA pour la plateforme Academia. On te fournit une question posée par un utilisateur. " +
      "Ta tâche est de résumer en UNE ou DEUX phrases le BESOIN principal exprimé, en français simple, sans citer de nom propre " +
      "ni inclure de données personnelles, et sans promettre de résultat. Concentre-toi sur le type de formation, d'orientation " +
      "ou de service recherché.";

    try {
      const rawSummary = await callOpenRouter(question, [], {
        systemPrompt: needSystemPrompt,
        includeNoAnswerSentinel: false,
      });
      const cleaned = rawSummary.trim();
      if (cleaned) needSummary = cleaned.slice(0, 1000);
    } catch (e) {
      console.error('logDetectedNeed OpenRouter error, fallback to raw question', e);
    }
  }

  const { error } = await supabaseService.rpc('app_log_bobodo_detected_need', {
    p_session_id: sessionId,
    p_question_text: question,
    p_category: category,
    p_need_summary: needSummary,
  });

  if (error) {
    console.error('app_log_bobodo_detected_need error', error.message);
  }
}

async function classifyQueryWithRules(message: string): Promise<string> {
  const text = message.toLowerCase();

  if (
    [
      'bonjour',
      'bonsoir',
      'salut',
      'merci',
      'désolé',
      'desole',
      'excuse',
      'triste',
      'heureux',
      'heureuse',
      'content',
      'contente',
      'stressé',
      'stresse',
      'inquiet',
      'inquiète',
    ].some((k) => text.includes(k))
  ) {
    return 'SMALL_TALK_EMOTION';
  }

  if (text.includes('nexiom') || text.includes('nexium') || text.includes('nexion') || text.includes('academia')) {
    return 'NEXIOM_ACADEMIA_INTERNE';
  }

  if (
    [
      'orientation',
      'étude',
      'etude',
      'filière',
      'filiere',
      'métier',
      'metier',
      'emploi',
      'travail',
      'carrière',
      'carriere',
      'cv',
      'lettre de motivation',
      'actuariat',
      'actuaria',
      'actuaire',
    ].some((k) => text.includes(k))
  ) {
    return 'ORIENTATION_ETUDES_EMPLOI';
  }

  if (
    [
      'université',
      'universite',
      'centre de formation',
      'école',
      'ecole',
      'lycée',
      'lycee',
      'entreprise',
    ].some((k) => text.includes(k))
  ) {
    return 'AUTRE_UNIVERSITE_OU_ENTREPRISE';
  }

  return 'HORS_SCOPE';
}

type ClassificationResult = { category: string; intent: string };

const VALID_CATEGORIES = new Set([
  'SMALL_TALK_EMOTION', 'NEXIOM_ACADEMIA_INTERNE', 'ORIENTATION_ETUDES_EMPLOI',
  'PARTENAIRE_UNIVERSITE_DETAILLEE', 'AUTRE_UNIVERSITE_OU_ENTREPRISE', 'HORS_SCOPE',
]);

const VALID_INTENTS = new Set([
  'greeting', 'factual', 'confirmation', 'follow_up',
  'frustration', 'satisfaction', 'emotional',
]);

async function classifyQueryWithOpenRouter(
  message: string,
  history?: ChatHistoryMessage[],
): Promise<ClassificationResult> {
  const fallbackCategory = await classifyQueryWithRules(message);
  const fallbackResult: ClassificationResult = { category: fallbackCategory, intent: 'factual' };

  if (!OPENROUTER_API_KEY) return fallbackResult;

  const recentHistory = (history ?? []).slice(-6);
  const historyContext = recentHistory.length > 0
    ? '\nHistorique récent de la conversation:\n' +
      recentHistory.map((h: ChatHistoryMessage) =>
        `${h.role === 'user' ? 'Utilisateur' : 'Bobodo'}: ${h.content.trim().slice(0, 150)}`
      ).join('\n') + '\n'
    : '';

  const classificationSystemPrompt =
    'Tu es Bobodo, assistant IA pour Academia. Analyse le message de l\'utilisateur ' +
    'en tenant compte de l\'historique de conversation.\n\n' +
    'Tu dois retourner EXACTEMENT 2 mots séparés par un pipe |:\n' +
    'CATEGORIE|INTENTION\n\n' +
    'CATÉGORIES possibles:\n' +
    '- SMALL_TALK_EMOTION: salutations (bonjour, salut, bonsoir), remerciements, émotions, ' +
    'petites discussions (comment tu vas, ça va, quoi de neuf)\n' +
    '- NEXIOM_ACADEMIA_INTERNE: questions sur Nexiom Group, la plateforme Academia\n' +
    '- ORIENTATION_ETUDES_EMPLOI: orientation, études, métiers, emploi, CV\n' +
    '- PARTENAIRE_UNIVERSITE_DETAILLEE: question détaillée sur un partenaire d\'Academia\n' +
    '- AUTRE_UNIVERSITE_OU_ENTREPRISE: université/entreprise non partenaire\n' +
    '- HORS_SCOPE: tout le reste\n\n' +
    'INTENTIONS possibles:\n' +
    '- greeting: l\'utilisateur salue ou dit bonjour/bonsoir/salut\n' +
    '- factual: l\'utilisateur pose une vraie question factuelle\n' +
    '- confirmation: l\'utilisateur valide/confirme ce qui a été dit (ah ok, c\'est ça, d\'accord)\n' +
    '- follow_up: l\'utilisateur continue le sujet avec une sous-question\n' +
    '- frustration: l\'utilisateur est mécontent ou ne comprend pas\n' +
    '- satisfaction: l\'utilisateur remercie ou est satisfait\n' +
    '- emotional: l\'utilisateur exprime une émotion (stress, joie, tristesse)\n\n' +
    'EXEMPLES:\n' +
    '- "bonjour" → SMALL_TALK_EMOTION|greeting\n' +
    '- "comment tu vas?" → SMALL_TALK_EMOTION|greeting\n' +
    '- "c\'est quoi nexiom?" → NEXIOM_ACADEMIA_INTERNE|factual\n' +
    '- "ah ok donc c\'est au cas par cas?" → (même catégorie que le sujet)|confirmation\n' +
    '- "oui" (après une question de Bobodo) → (même catégorie)|follow_up\n' +
    '- "merci beaucoup" → SMALL_TALK_EMOTION|satisfaction\n' +
    '- "je comprends pas, reformule" → (même catégorie)|frustration\n' +
    '- "je suis stressé" → SMALL_TALK_EMOTION|emotional\n\n' +
    'Réponds STRICTEMENT au format CATEGORIE|INTENTION, rien d\'autre.';

  try {
    const raw = await callOpenRouter(
      `${historyContext}Message actuel: ${message}`,
      [],
      {
        systemPrompt: classificationSystemPrompt,
        includeNoAnswerSentinel: false,
        max_tokens: 20,
      },
    );

    const cleaned = (raw ?? '').toString().trim().toUpperCase();
    const parts = cleaned.split('|').map((p: string) => p.trim());

    let category = parts[0] ?? '';
    let intent = (parts[1] ?? 'factual').toLowerCase();

    if (!VALID_CATEGORIES.has(category)) category = fallbackCategory;
    if (!VALID_INTENTS.has(intent)) intent = 'factual';

    return { category, intent };
  } catch (_e) {
    return fallbackResult;
  }
}

function getSystemPromptForCategory(category: string): string {
  // ── Système prompt maître (niveau ChatGPT) ─────────────────────
  const masterSystemPrompt =
    'Tu es Bobodo, assistant IA de Nexiom Group et de la plateforme Academia.\n\n' +
    'Ta mission est d\'accompagner les étudiants dans leur parcours : guider, informer, rassurer, orienter, encourager.\n\n' +
    'RÈGLES DE PERSONNALITÉ:\n\n' +
    '1. TON CHALEUREUX: Sois naturel, comme un ami bienveillant. Utilise un langage simple, accessible. ' +
    'Évite le jargon administratif. Sois empathique et encourageant.\n\n' +
    '2. CONCISION: Sois bref et direct. Pas de phrases inutiles. Pas de paragraphes interminables. ' +
    'Questions simples → 1-2 phrases. Questions complexes → 3-5 phrases max.\n\n' +
    '3. PERSONNALISATION: Utilise les informations du profil étudiant pour personnaliser tes réponses. ' +
    'Adapte tes exemples au niveau de l\'étudiant. Relie tes réponses à son projet d\'étude.\n\n' +
    '4. ENCOURAGEMENT: Encourage l\'étudiant naturellement. Félicite les réussites. ' +
    'Valide les efforts. Rassure en cas de difficulté.\n\n' +
    '5. QUESTIONS NATURELLES: Pose des questions de manière naturelle, pas comme un formulaire. ' +
    'Adapte tes questions au contexte. Évite le spam de questions.\n\n' +
    '6. SUIVI CONTEXTUEL: Connecte les réponses courtes au contexte précédent. ' +
    'Comprends les références implicites. Relie les sujets entre eux.\n\n' +
    '7. RÈGLES MÉTIER (CONSERVÉES):\n' +
    '- Compréhension sémantique\n' +
    '- Gestion frustration (reformule avec exemple)\n' +
    '- Gestion satisfaction (réponds chaleureusement)\n' +
    '- Redirection hors domaine\n' +
    '- Blocage universités (redirige vers onglet Universités)\n' +
    '- Gestion confirmation (confirme sans répéter)\n\n' +
    '8. ESCALADE VERS LE SUPPORT HUMAIN:\n' +
    '- Lorsque tu ne peux pas répondre avec suffisamment de certitude, invite l\'utilisateur à utiliser l\'icône flottante Support située juste à côté de Bobodo dans l\'application Academia afin de contacter directement l\'équipe d\'administration.\n' +
    '- Cas concernés: absence de réponse fiable, utilisateur insatisfait, plusieurs reformulations sans succès, demande administrative, problème de candidature, problème de paiement, université non disponible, question hors périmètre, besoin d\'un accompagnement humain.\n' +
    '- Formule: "Pour t\'aider davantage, je t\'invite à utiliser l\'icône flottante Support située juste à côté de moi dans l\'application Academia. L\'équipe d\'administration pourra te répondre directement."\n\n' +
    '9. FÉLICITATIONS PROACTIVES: Félicite l\'étudiant quand il réussit quelque chose. ' +
    'Exemples de réussites: réussir un examen, obtenir une mention, valider un dossier, réussir un concours, ' +
    'comprendre un concept difficile, progresser dans ses études. ' +
    'Formules de félicitations: "Bravo !", "Félicitations !", "Super travail !", "C\'est une excellente nouvelle !", "Tu as bien mérité ça !".\n\n' +
    '10. QUESTIONS DE DÉCOUVERTE NATURELLES: Pose des questions pour mieux connaître l\'étudiant de manière naturelle. ' +
    'Exemples: "Qu\'est-ce qui t\'intéresse le plus dans tes études ?", "Comment se passe ta préparation ?", ' +
    '"Tu as déjà une idée de ton orientation ?", "Quels sont tes objectifs pour cette année ?". ' +
    'Ces questions doivent être pertinentes et naturelles, pas comme un formulaire.\n\n' +
    '11. PAS DE QUESTIONS FORCÉES: Ne termine pas systématiquement par une question d\'engagement. ' +
    'Pose une question seulement si c\'est naturel et pertinent pour la conversation.';

  return masterSystemPrompt;
}

async function generateAnswerForCategory(
  message: string,
  category: string,
  knowledge: Array<Record<string, unknown>>,
  sessionId: string,
  history: ChatHistoryMessage[],
  intent: string = 'factual',
  supabaseForUser?: ReturnType<typeof createClient>,
): Promise<string> {
  // ── L'intent est maintenant déterminé par l'IA (pas par patterns) ──
  const emotionalState = intent as any;

  // ── [PHASE 1] Récupération du profil étudiant ─────────────────────
  let studentProfile: Record<string, unknown> = {};
  if (supabaseForUser && sessionId) {
    try {
      studentProfile = await loadStudentProfile(supabaseForUser, sessionId);
    } catch (e) {
      console.error('Error loading student profile', e);
    }
  }

  // ── Construction du contexte profil pour le prompt ─────────────
  let profileContext = '';
  if (studentProfile && Object.keys(studentProfile).length > 0) {
    const profileParts: string[] = [];
    if (studentProfile.first_name) profileParts.push(`Prénom: ${studentProfile.first_name}`);
    if (studentProfile.bac_series) profileParts.push(`Série du bac: ${studentProfile.bac_series}`);
    if (studentProfile.bac_mention) profileParts.push(`Mention du bac: ${studentProfile.bac_mention}`);
    if (studentProfile.study_project) profileParts.push(`Projet d'étude: ${studentProfile.study_project}`);
    if (studentProfile.country) profileParts.push(`Pays: ${studentProfile.country}`);
    if (studentProfile.city) profileParts.push(`Ville: ${studentProfile.city}`);
    
    const applications = studentProfile.applications as Array<Record<string, unknown>> | undefined;
    if (applications && applications.length > 0) {
      profileParts.push(`Candidatures: ${applications.length} en cours`);
    }

    if (profileParts.length > 0) {
      profileContext = '\n\nPROFIL ÉTUDIANT:\n' + profileParts.join('\n') + '\n';
    }
  }

  // ── [PHASE 2] Récupération de la mémoire cross-session ─────────────
  let crossSessionMemory: Record<string, unknown> = {};
  if (supabaseForUser && sessionId) {
    try {
      crossSessionMemory = await loadCrossSessionMemory(supabaseForUser, sessionId);
    } catch (e) {
      console.error('Error loading cross-session memory', e);
    }
  }

  // ── Construction du contexte mémoire cross-session pour le prompt ──
  let memoryContext = '';
  if (crossSessionMemory && Object.keys(crossSessionMemory).length > 0) {
    const memoryParts: string[] = [];
    
    const recentSummaries = crossSessionMemory.recent_summaries as Array<Record<string, unknown>> | undefined;
    if (recentSummaries && recentSummaries.length > 0) {
      memoryParts.push('Résumés des conversations précédentes:');
      for (const summary of recentSummaries.slice(0, 3)) {
        const summaryText = summary.summary as string;
        if (summaryText) {
          memoryParts.push(`- ${summaryText.slice(0, 200)}...`);
        }
      }
    }
    
    const allInterests = crossSessionMemory.all_interests as string[] | undefined;
    if (allInterests && allInterests.length > 0) {
      memoryParts.push(`Intérêts identifiés: ${allInterests.join(', ')}`);
    }
    
    const allStudyGoals = crossSessionMemory.all_study_goals as string[] | undefined;
    if (allStudyGoals && allStudyGoals.length > 0) {
      memoryParts.push(`Objectifs d'étude: ${allStudyGoals.join(', ')}`);
    }

    if (memoryParts.length > 0) {
      memoryContext = '\n\nMÉMOIRE CROSS-SESSION:\n' + memoryParts.join('\n') + '\n';
    }
  }

  // ── Système prompt maître (niveau ChatGPT) ─────────────────────
  const masterSystemPrompt = getSystemPromptForCategory(category);

  // ── Instruction contextuelle selon l'état émotionnel ────────────────
  let contextualInstruction = '';
  let promptForModel = message;

  if (emotionalState === 'greeting') {
    contextualInstruction =
      '\n\nCONTEXTE: L\'utilisateur te salue ou fait du small talk (bonjour, salut, bonsoir, coucou, hey, etc.). ' +
      'Réponds naturellement et chaleureusement en 1-2 phrases MAXIMUM. ' +
      'Exemples: "Salut 👋", "Bonsoir, content de te revoir.", "Hey !", "Coucou !". ' +
      'NE fais JAMAIS de bloc de présentation institutionnel. ' +
      'NE commence JAMAIS par "Bonjour, je suis Bobodo, assistant IA de Nexiom Group...". ' +
      'Sois bref et naturel.';
  } else if (emotionalState === 'emotional') {
    contextualInstruction =
      '\n\nCONTEXTE: L\'utilisateur exprime une émotion (stress, tristesse, joie, inquiétude...). ' +
      'Fais preuve d\'empathie en 1-2 phrases. Si c\'est du stress ou de l\'inquiétude, encourage-le avec des mots rassurants. ' +
      'Exemples: "Tu vas y arriver, continue tes efforts !", "Ne t\'inquiète pas, tu es sur la bonne voie.", ' +
      '"C\'est normal de se sentir comme ça, mais tu as les capacités pour réussir.", "Courage, tu fais déjà du bon travail !". ' +
      'Propose ensuite ton aide de façon bienveillante.';
  } else if (emotionalState === 'frustrated') {
    contextualInstruction =
      '\n\nCONTEXTE: L\'utilisateur est insatisfait ou n\'a pas compris. ' +
      'REFORMULE ta réponse précédente différemment, plus simplement, avec un exemple concret. ' +
      'Commence par "Permettez-moi d\'expliquer autrement :". ' +
      'Si après reformulation l\'utilisateur reste insatisfait, invite-le à utiliser l\'icône flottante Support située juste à côté de Bobodo dans l\'application Academia pour contacter directement l\'équipe d\'administration.';
  } else if (emotionalState === 'satisfied') {
    contextualInstruction =
      '\n\nCONTEXTE: L\'utilisateur exprime sa satisfaction. ' +
      'Réponds chaleureusement en 1-2 phrases. NE propose PAS systématiquement ton aide pour autre chose. ' +
      'Ne développe pas de nouveau contenu.';
  } else if (emotionalState === 'confirmation') {
    const lastAssistantMsg = [...history].reverse().find((h) => h.role === 'assistant');
    if (lastAssistantMsg) {
      contextualInstruction =
        `\n\nCONTEXTE: L'utilisateur CONFIRME ce qu'il a compris de ta réponse précédente:\n` +
        `"${lastAssistantMsg.content.trim().slice(0, 300)}"\n` +
        `Il dit: "${message.trim()}"\n` +
        `CONFIRME simplement en 1-2 phrases ("Oui, exactement !", "C'est bien ça !") ` +
        `et propose de continuer. NE RÉPÈTE PAS tout le contenu.`;
      promptForModel =
        `L'utilisateur dit "${message.trim()}" pour confirmer ce que Bobodo a expliqué. ` +
        `Confirme brièvement et propose de continuer.`;
    }
  } else if (emotionalState === 'follow_up') {
    // Récupérer les 2 derniers messages de Bobodo pour un contexte plus riche
    const assistantMessages = [...history].reverse().filter((h) => h.role === 'assistant');
    const lastAssistant = assistantMessages[0] ?? null;
    const prevAssistant = assistantMessages[1] ?? null;

    if (lastAssistant) {
      // Contexte enrichi avec jusqu'à 2 échanges précédents
      const prevContext = prevAssistant
        ? `\nMessage précédent de Bobodo: "${prevAssistant.content.trim().slice(0, 150)}"\n`
        : '';

      contextualInstruction =
        `\n\nCONTEXTE CONVERSATIONNEL:${prevContext}` +
        `Dernier message de Bobodo: "${lastAssistant.content.trim().slice(0, 300)}"\n` +
        `Réponse de l'utilisateur: "${message.trim()}"\n\n` +
        `L'utilisateur réagit au contenu ci-dessus. Possibilités: il confirme ce qu'il a compris, ` +
        `pose une précision, ou continue le sujet. Ne répète pas tout. Réponds directement et brièvement.`;

      // Toujours enrichir le prompt pour les follow_ups (pas seulement < 50 chars)
      promptForModel =
        `Contexte: Bobodo vient de dire "${lastAssistant.content.trim().slice(0, 300)}".\n` +
        `L'utilisateur répond maintenant: "${message.trim()}".\n` +
        `Réponds directement à cette réaction en 1-3 phrases maximum, ` +
        `sans reformuler tout le contexte. Si c'est une confirmation ("ah ok", "c'est ça?", ` +
        `"au cas par cas"...), confirme simplement ("Oui, exactement!") et propose de continuer.`;
    }
  }

  const fullSystemPrompt = masterSystemPrompt + profileContext + memoryContext + contextualInstruction;

  // ── Fallback web si base locale vide (Perplexity sonar) ─────────────
  let effectiveKnowledge = knowledge;
  if (
    knowledge.length === 0 &&
    emotionalState !== 'frustrated' &&
    emotionalState !== 'satisfied'
  ) {
    const webResult = await searchWebWithPerplexity(message, category);
    if (webResult) {
      effectiveKnowledge = [{ title: 'Source web', content: webResult }];
    }
  }

  // ── max_tokens selon contexte ──────────────────────────────────
  const maxTok =
    emotionalState === 'satisfied' ? 150 :
    category === 'SMALL_TALK_EMOTION' ? 200 :
    emotionalState === 'frustrated' ? 500 : 600;

  const answer = await callOpenRouter(promptForModel, effectiveKnowledge, {
    systemPrompt: fullSystemPrompt,
    includeNoAnswerSentinel: true,
    history,
    max_tokens: maxTok,
  });

  return answer;
}

serve(async (req) => {
  // CORS preflight support
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    const authHeader = req.headers.get('authorization') ?? req.headers.get('Authorization');
    const apiKeyHeader = req.headers.get('apikey');

    if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
      return new Response(JSON.stringify({ error: 'Authorization Bearer manquant' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    const jwt = authHeader.split(' ', 2)[1]?.trim();
    if (!jwt) {
      return new Response(JSON.stringify({ error: 'JWT invalide' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    if (!apiKeyHeader) {
      return new Response(JSON.stringify({ error: 'apikey manquante' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ error: 'Supabase backend non configuré' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    // Check if streaming is requested
    const url = new URL(req.url);
    const isStreaming = url.searchParams.get('stream') === 'true';

    const supabaseForUser = createClient(SUPABASE_URL, apiKeyHeader, {
      global: {
        headers: {
          Authorization: `Bearer ${jwt}`,
        },
      },
    });

    const supabaseService = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== 'object') {
      return new Response(JSON.stringify({ error: 'Payload JSON invalide' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    const sessionId = (body as any).session_id?.toString() ?? '';
    const message = (body as any).message?.toString() ?? '';

    if (!message.trim()) {
      return new Response(JSON.stringify({ error: 'Le message ne peut pas être vide.' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    if (!sessionId) {
      return new Response(
        JSON.stringify({ error: 'session_id manquant. La session Bobodo doit être créée côté client.' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
        },
      );
    }

    // 1) Enregistrer le message de l'étudiant (RPC, contexte utilisateur pour respecter RLS)
    //
    // `p_origine` dit si la question a été DICTÉE ou TAPÉE. Sans elle,
    // l'administrateur voyait les questions sans pouvoir juger la
    // transcription : une phrase mal comprise par le micro ressemblait à une
    // question mal posée. Ajouté le 04/09/2026.
    // Une valeur absente ou inattendue devient NULL plutôt que de faire
    // échouer l'enregistrement — la base la refuserait (contrainte CHECK), et
    // perdre la question de l'étudiant pour un champ de traçabilité serait
    // un mauvais échange.
    const origineRecue = typeof (body as { origine?: unknown }).origine === 'string'
      ? (body as { origine: string }).origine.trim()
      : '';
    const origine = origineRecue === 'vocal' || origineRecue === 'texte' ? origineRecue : null;

    const { error: appendStudentError } = await supabaseForUser.rpc('app_append_bobodo_message', {
      p_session_id: sessionId,
      p_sender: 'student',
      p_content: message,
      p_safety_flag: null,
      p_origine: origine,
    });
    if (appendStudentError) {
      console.error('app_append_bobodo_message (student) error', appendStudentError.message);
      return new Response(JSON.stringify({ error: 'Erreur lors de lenregistrement du message étudiant.' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    // 2) Charger l'historique de conversation (doit être avant searchKnowledge)
    const history = await loadConversationHistoryForSession(supabaseForUser, sessionId);

    // 2b) CACHE SÉMANTIQUE — vérifier si une réponse identique existe déjà
    // Conditions de mise en cache : message non-sensible, pas de suivi contextuel actif,
    // première question de la session OU conversation déjà en cours mais question factuelle
    let questionEmbedding: string | null = null;
    let cacheHitId: string | null = null;
    let cachedAnswer: string | null = null;

    const isLikelyFactual = !isSensitiveQuery(message) && history.length <= 6;
    if (isLikelyFactual) {
      questionEmbedding = await embedQuery(message).catch(() => null);
      if (questionEmbedding) {
        const cached = await checkAnswerCache(questionEmbedding, supabaseService);
        if (cached) {
          cachedAnswer = cached.answer;
          cacheHitId = cached.cacheId;
          console.log('[BOBODO CACHE HIT] similarity threshold met, skipping OpenRouter');
        }
      }
    }

    // 3) Recherche de connaissance (ignorée si cache hit)
    // [FIX P3] Passer l'historique à searchKnowledge pour enrichir le RAG sur les questions courtes
    const knowledge = cachedAnswer ? [] : await searchKnowledge(supabaseService, message, history);

    // 4) Filtre de sécurité, classification et génération
    let assistantMessage: string;
    let category: string | null = null;

    try {
      if (cachedAnswer) {
        // Réponse en cache : 0 crédit OpenRouter consommé
        assistantMessage = cachedAnswer;
        if (cacheHitId) await registerCacheHit(cacheHitId, supabaseService);
      } else if (isSensitiveQuery(message)) {
        assistantMessage = await callOpenRouterSafetyRefusal(message);
      } else if (isUniversityQuery(message)) {
        // [FIX P4] Blocage total des questions sur les universités
        assistantMessage = UNIVERSITY_REFUSAL_MESSAGE;
        category = 'UNIVERSITE_BLOQUEE';
      } else {
        const classification = await classifyQueryWithOpenRouter(message, history);
        category = classification.category;
        const intent = classification.intent;

        // [PHASE 4] Logger l'état émotionnel (async, non bloquant)
        logEmotionalState(supabaseService, sessionId, intent).catch((e) => {
          console.error('Error in logEmotionalState (async)', e);
        });

        // Streaming mode
        if (isStreaming) {
          const stream = await callOpenRouter(message, knowledge, {
            systemPrompt: getSystemPromptForCategory(category),
            includeNoAnswerSentinel: true,
            history,
            max_tokens: 500,
            stream: true,
          }) as ReadableStream<Uint8Array>;

          // Return SSE stream
          const headers = {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            ...CORS_HEADERS,
          };

          return new Response(stream, { headers });
        }

        assistantMessage = await generateAnswerForCategory(message, category, knowledge, sessionId, history, intent, supabaseForUser);

        // [FIX P1] Intercepter le sentinel avant de sauvegarder/retourner
        const NO_ANSWER_SENTINEL = '__BOBODO_NO_ANSWER__';
        if (assistantMessage.includes(NO_ANSWER_SENTINEL)) {
          assistantMessage =
            "Je n'ai pas suffisamment d'informations pour répondre précisément à cette question. " +
            'N\'hésite pas à reformuler ou à me poser une question sur l\'orientation, ' +
            'les études, l\'emploi ou la plateforme Academia.';
        }

        // Sauvegarder dans le cache (seulement factual, pas follow_up/frustration/greeting)
        const isCacheable =
          category &&
          category !== 'SMALL_TALK_EMOTION' &&
          intent === 'factual' &&
          questionEmbedding &&
          !assistantMessage.includes('__BOBODO_NO_ANSWER__');
        if (isCacheable && questionEmbedding) {
          await saveAnswerToCache(message, questionEmbedding, assistantMessage, category, supabaseService);
        }

        if (category) {
          await logDetectedNeed(supabaseService, sessionId, message, category);
        }
      }
    } catch (e) {
      console.error('Bobodo AI error', e);
      return new Response(
        JSON.stringify({ error: 'Erreur IA', detail: (e as Error).message ?? 'unknown' }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
        },
      );
    }

    // 4) Enrichir éventuellement le premier message de Bobodo avec un préfixe de salutation
    let finalAssistantMessage = assistantMessage;

    try {
      const { data: hasAssistantData, error: hasAssistantError } = await supabaseService.rpc(
        'app_has_bobodo_assistant_message',
        { p_session_id: sessionId },
      );
      let alreadyHasAssistant = false;
      if (!hasAssistantError) {
        if (typeof hasAssistantData === 'boolean') alreadyHasAssistant = hasAssistantData;
        else if (
          hasAssistantData &&
          typeof hasAssistantData === 'object' &&
          'result' in (hasAssistantData as Record<string, unknown>) &&
          typeof (hasAssistantData as any).result === 'boolean'
        ) {
          alreadyHasAssistant = Boolean((hasAssistantData as any).result);
        }
      }

      // [PHASE 1] Suppression de l'enrichissement des salutations côté serveur
      // Les salutations sont maintenant gérées par l'instruction contextuelle dans le prompt
    } catch (e) {
      console.error('Bobodo greeting enrichment error', e);
    }

    // 5) Enregistrer la réponse IA dans la session (RPC avec service_role pour contourner RLS si nécessaire)
    const { error: appendAssistantError } = await supabaseService.rpc('app_append_bobodo_message', {
      p_session_id: sessionId,
      p_sender: 'assistant',
      p_content: finalAssistantMessage,
      p_safety_flag: null,
    });
    if (appendAssistantError) {
      console.error('app_append_bobodo_message (assistant) error', appendAssistantError.message);
      return new Response(JSON.stringify({ error: 'Erreur lors de lenregistrement de la réponse IA.' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    // [PHASE 2] Sauvegarder le résumé de conversation (async, non bloquant)
    saveConversationSummary(supabaseService, sessionId, history).catch((e) => {
      console.error('Error in saveConversationSummary (async)', e);
    });

    // 6) Réponse HTTP
    return new Response(JSON.stringify({ reply: finalAssistantMessage }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
    });
  } catch (e) {
    console.error('bobodo-chat unexpected error', e);
    return new Response(JSON.stringify({ error: 'Erreur interne', detail: (e as Error).message ?? 'unknown' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
    });
  }
});
