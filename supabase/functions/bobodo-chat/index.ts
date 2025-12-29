// Supabase Edge Function: bobodo-chat
// Re-implementation of the former FastAPI /bobodo/chat endpoint using Supabase RPCs
// and OpenRouter, with strict authentication via Supabase JWT.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

// CORS headers for browser clients (Flutter Web, SPAs, etc.)
const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY for bobodo-chat Edge Function');
}

const SENSITIVE_KEYWORDS: string[] = [
  'terrorisme', 'terrorist', 'bombe', 'bombe artisanale', 'massacre', 'fusillade',
  'suicide', 'me suicider', 'me tuer', 'tuer quelqu\'un', 'me faire du mal',
  'me mutiler', 'automutilation', 'sexe', 'pornographie', 'porno', 'viol', 'pédophilie',
  'pedophilie', 'nazisme', 'hitler', 'armes', 'drogue', 'drogues dures',
];

function isSensitiveQuery(message: string): boolean {
  const text = message.toLowerCase();
  return SENSITIVE_KEYWORDS.some((kw) => text.includes(kw));
}

async function callOpenRouter(
  prompt: string,
  knowledge: Array<Record<string, unknown>>,
  options?: { systemPrompt?: string | null; includeNoAnswerSentinel?: boolean },
): Promise<string> {
  const systemPrompt = options?.systemPrompt ?? null;
  const includeNoAnswerSentinel = options?.includeNoAnswerSentinel ?? true;

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

  const messages: Array<{ role: 'system' | 'user'; content: string }> = [];
  if (systemPrompt) {
    messages.push({ role: 'system', content: systemPrompt });
  }
  messages.push({ role: 'user', content: finalUserPrompt });

  const payload = {
    model: OPENROUTER_MODEL,
    messages,
    temperature: 0.2,
  };

  const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Erreur OpenRouter (status=${resp.status}): ${text.slice(0, 1000)}`);
  }

  const data = await resp.json();
  const choices = Array.isArray(data?.choices) ? data.choices : null;
  if (!choices || !choices.length) {
    throw new Error('Erreur OpenRouter: choices manquants');
  }

  const first = choices[0];
  const message = first?.message;
  const content = (message?.content ?? '').toString().trim();
  if (!content) {
    throw new Error('Erreur OpenRouter: content vide');
  }

  return content;
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

async function searchKnowledge(supabaseService: ReturnType<typeof createClient>, query: string) {
  const trimmed = query.trim();
  if (!trimmed) return [] as Array<Record<string, unknown>>;

  function extractList(raw: unknown): Array<Record<string, unknown>> {
    if (Array.isArray(raw)) return raw as Array<Record<string, unknown>>;
    if (raw && typeof raw === 'object' && 'result' in (raw as Record<string, unknown>)) {
      const r = (raw as Record<string, unknown>).result;
      if (Array.isArray(r)) return r as Array<Record<string, unknown>>;
    }
    return [];
  }

  // 1) full query
  const { data, error } = await supabaseService.rpc('app_search_bobodo_knowledge', {
    p_query: trimmed,
    p_category: null,
  });
  if (error) {
    console.error('app_search_bobodo_knowledge error', error.message);
  }
  let knowledge = extractList(data);
  if (knowledge.length) return knowledge;

  // 2) fallback simplified queries for Nexiom/Academia
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

  return combined;
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

async function classifyQueryWithOpenRouter(message: string): Promise<string> {
  if (!OPENROUTER_API_KEY) {
    return classifyQueryWithRules(message);
  }

  const CATEGORY_SMALL_TALK_EMOTION = 'SMALL_TALK_EMOTION';
  const CATEGORY_NEXIOM_ACADEMIA_INTERNE = 'NEXIOM_ACADEMIA_INTERNE';
  const CATEGORY_ORIENTATION_ETUDES_EMPLOI = 'ORIENTATION_ETUDES_EMPLOI';
  const CATEGORY_PARTENAIRE_UNIVERSITE_DETAILLEE = 'PARTENAIRE_UNIVERSITE_DETAILLEE';
  const CATEGORY_AUTRE_UNIVERSITE_OU_ENTREPRISE = 'AUTRE_UNIVERSITE_OU_ENTREPRISE';
  const CATEGORY_HORS_SCOPE = 'HORS_SCOPE';

  const VALID_CATEGORIES = new Set([
    CATEGORY_SMALL_TALK_EMOTION,
    CATEGORY_NEXIOM_ACADEMIA_INTERNE,
    CATEGORY_ORIENTATION_ETUDES_EMPLOI,
    CATEGORY_PARTENAIRE_UNIVERSITE_DETAILLEE,
    CATEGORY_AUTRE_UNIVERSITE_OU_ENTREPRISE,
    CATEGORY_HORS_SCOPE,
  ]);

  const classificationSystemPrompt =
    'Tu es Bobodo, assistant IA pour la plateforme Academia. ' +
    'Ta tâche est de COMPRENDRE le sens de la question de l\'utilisateur, même si elle est mal formulée, ' +
    'puis de la CLASSER dans UNE SEULE catégorie parmi la liste suivante:\n' +
    `- ${CATEGORY_SMALL_TALK_EMOTION}: salutations, remerciements, petites discussions, émotions.\n` +
    `- ${CATEGORY_NEXIOM_ACADEMIA_INTERNE}: questions sur Nexiom Group, Nexiom, la plateforme Academia, ses fonctionnalités.\n` +
    `- ${CATEGORY_ORIENTATION_ETUDES_EMPLOI}: questions d\'orientation, choix d\'études, d\'emploi, etc.\n` +
    `- ${CATEGORY_PARTENAIRE_UNIVERSITE_DETAILLEE}: question détaillée sur une université PARTENAIRE d\'Academia.\n` +
    `- ${CATEGORY_AUTRE_UNIVERSITE_OU_ENTREPRISE}: question sur une université ou entreprise NON partenaire.\n` +
    `- ${CATEGORY_HORS_SCOPE}: toute autre question.\n` +
    'Réponds STRICTEMENT par l\'un de ces codes, sans texte supplémentaire. Si tu hésites, utilise HORS_SCOPE.';

  let rawCategory: string;
  try {
    rawCategory = await callOpenRouter(message, [], {
      systemPrompt: classificationSystemPrompt,
      includeNoAnswerSentinel: false,
    });
  } catch (_e) {
    return classifyQueryWithRules(message);
  }

  const category = (rawCategory ?? '').toString().trim().toUpperCase();
  const rulesCategory = await classifyQueryWithRules(message);

  if (rulesCategory === CATEGORY_NEXIOM_ACADEMIA_INTERNE || rulesCategory === CATEGORY_AUTRE_UNIVERSITE_OU_ENTREPRISE) {
    return rulesCategory;
  }

  if (VALID_CATEGORIES.has(category)) {
    return category;
  }

  return rulesCategory;
}

async function generateAnswerForCategory(
  message: string,
  category: string,
  knowledge: Array<Record<string, unknown>>,
  sessionId: string,
): Promise<string> {
  // Pour l\'instant, on utilise un prompt générique très proche du backend Python.
  let systemPrompt =
    'Tu es Bobodo, assistant IA pour Nexiom Group et la plateforme Academia. ' +
    "Tu aides les utilisateurs sur l'orientation, les études, l'emploi et la plateforme Academia. " +
    'Réponds en français clair, bienveillant et structuré, avec des phrases courtes. Ne promets jamais de résultat garanti. ' +
    'Si la question sort du périmètre (santé, finance, droit, etc.), conseille de consulter un professionnel ou un service officiel.';

  // On pourrait ajuster légèrement selon la catégorie si besoin.

  const answer = await callOpenRouter(message, knowledge, {
    systemPrompt,
    includeNoAnswerSentinel: true,
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
    const { error: appendStudentError } = await supabaseForUser.rpc('app_append_bobodo_message', {
      p_session_id: sessionId,
      p_sender: 'student',
      p_content: message,
      p_safety_flag: null,
    });
    if (appendStudentError) {
      console.error('app_append_bobodo_message (student) error', appendStudentError.message);
      return new Response(JSON.stringify({ error: 'Erreur lors de lenregistrement du message étudiant.' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }

    // 2) Recherche de connaissance
    const knowledge = await searchKnowledge(supabaseService, message);

    // 3) Filtre de sécurité, classification et génération
    let assistantMessage: string;
    let category: string | null = null;

    try {
      if (isSensitiveQuery(message)) {
        assistantMessage = await callOpenRouterSafetyRefusal(message);
      } else {
        category = await classifyQueryWithOpenRouter(message);
        assistantMessage = await generateAnswerForCategory(message, category, knowledge, sessionId);
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

      if (!alreadyHasAssistant) {
        const { data: firstNameData, error: firstNameError } = await supabaseService.rpc(
          'app_get_bobodo_student_first_name',
          { p_session_id: sessionId },
        );

        let firstName: string | null = null;
        if (!firstNameError) {
          if (typeof firstNameData === 'string') {
            firstName = firstNameData.trim() || null;
          } else if (
            firstNameData &&
            typeof firstNameData === 'object' &&
            'result' in (firstNameData as Record<string, unknown>) &&
            typeof (firstNameData as any).result === 'string'
          ) {
            firstName = ((firstNameData as any).result as string).trim() || null;
          }
        }

        const greetingPrefix = firstName
          ? `Bonjour ${firstName}, on se rencontre, je suis Bobodo, l'assistant d'Academia. `
          : "Bonjour, je suis Bobodo, l'assistant d'Academia. ";

        finalAssistantMessage = greetingPrefix + (assistantMessage ?? '').toString().trimStart();
      }
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
