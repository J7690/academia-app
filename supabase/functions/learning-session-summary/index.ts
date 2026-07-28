// Supabase Edge Function : learning-session-summary
//
// Produit la fiche de séance d'un live Academia, en deux versions :
// une pour l'étudiant qui révise, une pour l'enseignant qui ajuste son cours.
//
// ── Choix de conception : pas de transcription vocale ────────────────────
//
// Résumer « ce qui a été dit » supposerait une transcription en temps réel,
// facturée environ 0,01 $ la minute d'agent LiveKit — vingt fois le coût d'un
// participant humain, soit ~0,90 $ pour une séance de 90 minutes.
//
// On s'en passe, parce que l'essentiel est déjà capté sans rien coûter :
//   · le chat persistant contient les questions réellement posées
//   · les quiz contiennent ce qui a été travaillé et ce qui a résisté
//   · le journal d'événements contient le déroulé
//   · le tableau blanc contient ce qui a été écrit
//
// La transcription pourra s'ajouter plus tard, en option activable par
// l'enseignant, une fois le circuit de la fiche éprouvé. Engager 0,90 $ par
// séance avant de savoir si le document sert à quelqu'un serait prématuré.
//
// Secrets requis : OPENROUTER_API_KEY, OPENROUTER_MODEL, OPENROUTER_FALLBACK_MODEL

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const OPENROUTER_MODEL = Deno.env.get('OPENROUTER_MODEL') ?? '';
const OPENROUTER_FALLBACK_MODEL = Deno.env.get('OPENROUTER_FALLBACK_MODEL') ?? '';
const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

// ── Appel du modèle, avec repli ──────────────────────────────────────────

// Deux métiers, deux vocabulaires. Une consultation d'orientation ne se
// résume pas en « concepts » et « points de blocage » : ce qui compte, ce sont
// les pistes de filières, les échéances et les démarches à engager.
const SYSTEME_PEDAGOGIQUE =
  "Tu es un assistant pédagogique qui rédige des fiches de séance " +
  "pour une plateforme éducative burkinabè. Tu écris en français " +
  "clair et sobre, sans emphase inutile. Tu n'inventes jamais de " +
  "contenu : si une information manque, tu laisses le champ vide " +
  "plutôt que de le combler. Tu réponds uniquement par du JSON valide.";

const SYSTEME_ORIENTATION =
  "Tu assistes un conseiller d'orientation burkinabè après un entretien " +
  "avec un élève. Tu rédiges le compte rendu de cet entretien en français " +
  "clair et sobre. Tu connais le système éducatif burkinabè et ouest-africain, " +
  "mais tu n'inventes JAMAIS un établissement, une date de concours ou un " +
  "dispositif de bourse qui n'aurait pas été évoqué pendant l'entretien : " +
  "une information fausse en orientation engage l'avenir d'un élève. " +
  "Si une rubrique n'a pas de matière, tu renvoies un tableau vide. " +
  "Tu ne portes aucun jugement sur l'élève. Tu réponds uniquement par du " +
  "JSON valide.";

async function callModel(
  prompt: string,
  systeme: string,
): Promise<{ text: string; model: string }> {
  const models = [OPENROUTER_MODEL, OPENROUTER_FALLBACK_MODEL].filter((m) => m);
  if (models.length === 0) throw new Error('Aucun modèle OpenRouter configuré.');

  const errors: string[] = [];
  for (const model of models) {
    try {
      const resp = await fetch(OPENROUTER_URL, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${OPENROUTER_API_KEY}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://academia.nexiomgroup.com',
          'X-Title': 'Academia — fiche de séance',
        },
        body: JSON.stringify({
          model,
          messages: [
            { role: 'system', content: systeme },
            { role: 'user', content: prompt },
          ],
          max_tokens: 2500,
          temperature: 0.3,
          response_format: { type: 'json_object' },
        }),
      });

      if (!resp.ok) {
        errors.push(`${model} (${resp.status})`);
        continue;
      }
      const data = await resp.json();
      const text = data?.choices?.[0]?.message?.content;
      if (typeof text === 'string' && text.trim().length > 0) {
        return { text, model };
      }
      errors.push(`${model} (réponse vide)`);
    } catch (e) {
      errors.push(`${model} (${String(e).slice(0, 80)})`);
    }
  }
  throw new Error(`Tous les modèles ont échoué : ${errors.join(' | ')}`);
}

function parseJson(raw: string): Record<string, unknown> {
  let text = raw.trim();
  // Certains modèles encadrent leur réponse d'un bloc de code malgré la
  // consigne. On le retire avant d'analyser.
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence) text = fence[1].trim();
  return JSON.parse(text);
}

// ── Fonction principale ──────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ success: false, error: 'Method not allowed' }, 405);

  if (!OPENROUTER_API_KEY) {
    return json({ success: false, error: 'Service de synthèse non configuré.' }, 500);
  }

  const jwt = (req.headers.get('authorization') ?? '').replace('Bearer ', '');
  if (!jwt) return json({ success: false, error: 'Non authentifié.' }, 401);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);
  if (authError || !user) return json({ success: false, error: 'Token invalide.' }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ success: false, error: 'Corps de requête invalide.' }, 400);
  }

  const sessionId = body.session_id as string;
  if (!sessionId) return json({ success: false, error: 'session_id requis.' }, 400);

  // ── 1. La séance, et le contrôle d'autorité ───────────────────────────
  const { data: session } = await supabase
    .schema('app')
    .from('academia_sessions')
    .select('id, title, description, subject, session_type, host_id, host_display_name, ' +
            'scheduled_start, actual_start, actual_end, course_id, status')
    .eq('id', sessionId)
    .maybeSingle();

  if (!session) return json({ success: false, error: 'Séance introuvable.' }, 404);
  if (session.host_id !== user.id) {
    return json({
      success: false,
      error: session.session_type === 'orientation'
        ? 'Seul le conseiller peut générer le compte rendu.'
        : 'Seul l\'enseignant peut générer la fiche.',
    }, 403);
  }

  // ── 2. La matière première ────────────────────────────────────────────
  const [messagesRes, participantsRes, eventsRes] = await Promise.all([
    supabase.schema('app').from('academia_session_messages')
      .select('sender_name, content, created_at')
      .eq('session_id', sessionId).order('created_at', { ascending: true }).limit(400),
    supabase.schema('app').from('academia_session_participants')
      .select('display_name, role, joined_at, left_at')
      .eq('session_id', sessionId),
    supabase.schema('app').from('academia_session_events')
      .select('kind, actor_name, payload, offset_ms')
      .eq('session_id', sessionId).order('created_at', { ascending: true }).limit(300),
  ]);

  const messages = messagesRes.data ?? [];
  const participants = participantsRes.data ?? [];
  const events = eventsRes.data ?? [];

  const estOrientation = session.session_type === 'orientation';

  // Notes déjà prises par le conseiller pendant l'entretien. Le modèle ne part
  // pas de rien : il structure et complète un travail humain, il ne le
  // remplace pas.
  let ficheConseiller: Record<string, unknown> | null = null;
  if (estOrientation) {
    const { data: booking } = await supabase
      .schema('app').from('orientation_bookings')
      .select('id, motif').eq('session_id', sessionId).maybeSingle();
    if (booking) {
      const { data: fiche } = await supabase
        .schema('app').from('orientation_records')
        .select('content').eq('booking_id', booking.id).maybeSingle();
      ficheConseiller = (fiche?.content as Record<string, unknown>) ?? null;
    }
  }

  // Un entretien d'orientation peut se dérouler sans un seul message écrit :
  // c'est une conversation. Les notes du conseiller suffisent alors à nourrir
  // le compte rendu. Exiger du chat aurait rendu la fonction inutilisable
  // précisément là où elle sert le plus.
  if (messages.length === 0 && events.length === 0 && !ficheConseiller) {
    return json({
      success: false,
      error: estOrientation
        ? 'Cet entretien ne contient ni notes ni échanges : il n\'y a rien à résumer.'
        : 'Cette séance ne contient ni message ni événement : il n\'y a rien à résumer.',
    }, 422);
  }

  // ── 3. Le prompt ──────────────────────────────────────────────────────
  const duree = session.actual_start && session.actual_end
    ? Math.round((new Date(session.actual_end as string).getTime() -
                  new Date(session.actual_start as string).getTime()) / 60000)
    : null;

  const enTete = [
    `Séance : ${session.title}`,
    estOrientation
      ? (session.subject ? `Thème d'orientation : ${session.subject}` : '')
      : (session.subject ? `Matière : ${session.subject}` : ''),
    session.description ? `Description : ${session.description}` : '',
    estOrientation
      ? `Conseiller : ${session.host_display_name ?? 'non renseigné'}`
      : `Enseignant : ${session.host_display_name ?? 'non renseigné'}`,
    duree ? `Durée : ${duree} minutes` : '',
    `Participants : ${participants.length}`,
  ];

  const matiere = [
    '',
    '--- ÉCHANGES DU CHAT ---',
    messages.length === 0
      ? '(aucun message)'
      : messages.map((m: Record<string, unknown>) =>
          `${m.sender_name} : ${m.content}`).join('\n'),
    '',
    '--- ÉVÉNEMENTS DE SÉANCE ---',
    events.length === 0
      ? '(aucun événement)'
      : events.map((e: Record<string, unknown>) =>
          `[${e.kind}] ${e.actor_name ?? ''} ${JSON.stringify(e.payload)}`).join('\n'),
  ];

  const consigne = estOrientation
    ? [
        ...(ficheConseiller
          ? [
              '',
              '--- NOTES PRISES PAR LE CONSEILLER PENDANT L\'ENTRETIEN ---',
              JSON.stringify(ficheConseiller, null, 2),
              '',
              'Ces notes font autorité. Structure-les et complète-les avec ce qui',
              'ressort des échanges ci-dessus, sans jamais les contredire.',
            ]
          : []),
        '',
        'Rédige le compte rendu de cet entretien d\'orientation.',
        'Réponds STRICTEMENT par un objet JSON avec ces clés :',
        '{',
        '  "synthese": "dix lignes maximum, la situation de l\'élève et ce qui s\'est dit",',
        '  "profil": "ce qui ressort de l\'élève : goûts, résultats, contraintes",',
        '  "pistes": [{"filiere": "...", "etablissement": "... ou vide", "pourquoi": "..."}],',
        '  "echeances": [{"quoi": "...", "quand": "... ou vide si non précisé"}],',
        '  "documents_a_reunir": ["pièces à rassembler"],',
        '  "prochaines_etapes": ["ce que l\'élève doit faire, dans l\'ordre"],',
        '  "points_de_vigilance": ["ce sur quoi l\'élève hésite ou risque de se tromper"],',
        '  "questions_sans_reponse": ["ce qui reste à éclaircir lors d\'un prochain entretien"]',
        '}',
        '',
        'Contraintes strictes :',
        '- n\'invente aucun établissement, aucune date de concours, aucune bourse',
        '  qui ne figurerait pas ci-dessus ;',
        '- si une échéance n\'a pas été datée, laisse "quand" vide ;',
        '- ne porte aucun jugement de valeur sur l\'élève ;',
        '- si une rubrique n\'a pas de matière, renvoie un tableau vide.',
      ]
    : [
        '',
        'Rédige la fiche de cette séance. Réponds STRICTEMENT par un objet JSON avec ces clés :',
        '{',
        '  "resume": "dix lignes maximum, ce qui a été couvert",',
        '  "plan": ["point 1", "point 2", ...],',
        '  "concepts": [{"terme": "...", "definition": "..."}],',
        '  "questions": [{"auteur": "...", "question": "...", "reponse": "... ou vide si sans réponse"}],',
        '  "points_de_blocage": ["ce qui a visiblement résisté aux participants"],',
        '  "a_retenir": ["3 à 5 affirmations essentielles"],',
        '  "pour_aller_plus_loin": ["suggestions de révision"]',
        '}',
        '',
        'Contraintes : n\'invente aucun contenu qui ne figure pas ci-dessus. Si une',
        'question est restée sans réponse dans le chat, laisse "reponse" vide plutôt',
        'que d\'en fabriquer une. Si une section n\'a pas de matière, renvoie un tableau vide.',
      ];

  const prompt = [...enTete, ...matiere, ...consigne]
    .filter((l) => l !== '').join('\n');

  // ── 4. Génération ─────────────────────────────────────────────────────
  let content: Record<string, unknown>;
  let modelUsed: string;
  try {
    const result = await callModel(
      prompt,
      estOrientation ? SYSTEME_ORIENTATION : SYSTEME_PEDAGOGIQUE,
    );
    modelUsed = result.model;
    content = parseJson(result.text);
  } catch (e) {
    const detail = String(e).slice(0, 400);
    await supabase.schema('app').from('academia_session_summaries').upsert({
      session_id: sessionId,
      audience: 'student',
      status: 'failed',
      error_detail: detail,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'session_id,audience' });
    return json({ success: false, error: 'La synthèse a échoué.', detail }, 502);
  }

  // ── 5. Les deux versions ──────────────────────────────────────────────
  const now = new Date().toISOString();

  // Version élève : le contenu, rien sur les autres participants.
  const studentContent = {
    type: estOrientation ? 'orientation' : 'pedagogique',
    seance: {
      titre: session.title,
      ...(estOrientation
        ? { theme: session.subject, conseiller: session.host_display_name }
        : { matiere: session.subject, enseignant: session.host_display_name }),
      date: session.actual_start ?? session.scheduled_start,
      duree_minutes: duree,
    },
    ...content,
  };

  // Version hôte : le même contenu, plus ce qui l'aide à assurer le suivi.
  // Les indicateurs diffèrent : un conseiller ne mesure pas des questions
  // sans réponse, il mesure des démarches engagées.
  const hostContent: Record<string, unknown> = estOrientation
    ? {
        ...studentContent,
        statistiques: {
          messages_echanges: messages.length,
          pistes_identifiees: Array.isArray(content.pistes)
            ? content.pistes.length : 0,
          echeances: Array.isArray(content.echeances)
            ? content.echeances.length : 0,
          etapes_a_suivre: Array.isArray(content.prochaines_etapes)
            ? content.prochaines_etapes.length : 0,
          evenements: events.length,
        },
        a_reprendre: content.questions_sans_reponse ?? [],
        // Rappel : ces notes ne partent jamais vers la version élève.
        notes_internes: (ficheConseiller?.notes as string) ?? '',
      }
    : {
        ...studentContent,
        statistiques: {
          participants: participants.length,
          messages_echanges: messages.length,
          questions_posees: Array.isArray(content.questions)
            ? content.questions.length : 0,
          questions_sans_reponse: Array.isArray(content.questions)
            ? (content.questions as Record<string, unknown>[])
                .filter((q) => !q.reponse || String(q.reponse).trim() === '').length
            : 0,
          evenements: events.length,
        },
        a_reprendre: content.points_de_blocage ?? [],
      };

  await supabase.schema('app').from('academia_session_summaries').upsert([
    {
      session_id: sessionId, audience: 'student', status: 'ready',
      content: studentContent, model_used: modelUsed,
      generated_at: now, updated_at: now, error_detail: null,
      // Non publiée : l'enseignant relit d'abord.
      is_published: false,
    },
    {
      session_id: sessionId, audience: 'host', status: 'ready',
      content: hostContent, model_used: modelUsed,
      generated_at: now, updated_at: now, error_detail: null,
      is_published: true,
    },
  ], { onConflict: 'session_id,audience' });

  return json({
    success: true,
    model_used: modelUsed,
    type: estOrientation ? 'orientation' : 'pedagogique',
    a_reprendre: Array.isArray(hostContent.a_reprendre)
      ? (hostContent.a_reprendre as unknown[]).length : 0,
    message: estOrientation
      ? 'Compte rendu généré. Relisez-le puis partagez-le avec l\'élève.'
      : 'Fiche générée. Relisez-la puis publiez-la pour vos étudiants.',
  });
});
