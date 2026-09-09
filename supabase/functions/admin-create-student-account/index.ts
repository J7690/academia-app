// Supabase Edge Function: admin-create-student-account
//
// Cree un compte etudiant depuis le tableau de bord administrateur.
// Reserve aux appelants dont le role vaut 'admin'.
//
// POURQUOI CETTE FONCTION EXISTE (09/09/2026).
// Sur les sept formulaires de creation de comptes de l'ecran Comptes, SIX
// appelaient une Edge Function dediee. Le septieme -- l'etudiant -- passait par
// la RPC `app_admin_create_user_invitation`, dont la liste blanche est :
//     ('admin', 'university', 'instructor', 'merchant')
// `student` n'y figure pas. Toute tentative repondait donc `unsupported_role`,
// systematiquement, et depuis toujours : la table `app.user_invitations` est
// VIDE -- ce mecanisme n'a jamais rien cree, pour personne.
//
// Le formulaire demandait par ailleurs un mot de passe temporaire qu'il ne
// transmettait pas : `createInvitation` n'a aucun parametre pour lui. Il etait
// saisi, exige, puis efface.
//
// LA FICHE `app.students` N'EST PAS CREEE ICI, ET C'EST VOULU. Le trigger
// `on_auth_user_created` (fonction `app_handle_new_auth_user`) l'insere deja a
// la creation du compte Auth. La dupliquer ici ferait deux ecritures pour un
// seul etudiant, et la seconde masquerait un eventuel defaut de la premiere.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY for admin-create-student-account Edge Function');
}

/**
 * Traduit l'echec d'Auth en un code que l'application sait expliquer.
 *
 * Les autres fonctions de creation renvoient toutes `auth_user_creation_failed`,
 * un code unique qui MASQUE la cause. Mesure du 09/09 : trois tentatives de
 * Jocelyn ont echoue, et les journaux montraient trois causes distinctes --
 *     400: Unable to validate email address: invalid format
 *     422: User already registered
 * -- que l'ecran resumait de la meme facon. Un administrateur ne peut pas
 * corriger ce qu'on ne lui nomme pas.
 */
function codeDeLErreur(message: string): string {
  const m = (message ?? '').toLowerCase();
  if (m.includes('already registered') || m.includes('already been registered')) {
    return 'email_deja_utilise';
  }
  if (m.includes('validate email') || m.includes('invalid format')) {
    return 'email_invalide';
  }
  if (m.includes('password')) {
    return 'mot_de_passe_trop_court';
  }
  return 'auth_user_creation_failed';
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }

  try {
    const authHeader = req.headers.get('authorization') ?? req.headers.get('Authorization');
    const apiKeyHeader = req.headers.get('apikey');

    if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
      return new Response(
        JSON.stringify({ error: 'authorization_bearer_missing' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const jwt = authHeader.split(' ', 2)[1]?.trim();
    if (!jwt) {
      return new Response(
        JSON.stringify({ error: 'invalid_jwt' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    if (!apiKeyHeader) {
      return new Response(
        JSON.stringify({ error: 'apikey_missing' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(
        JSON.stringify({ error: 'supabase_backend_not_configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const supabaseForUser = createClient(SUPABASE_URL, apiKeyHeader, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const supabaseService = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // LE JETON EST VERIFIE PAR AUTH, PAS DECODE ICI. Un jeton simplement decode
    // se forge ; `getUser()` le fait valider par le serveur.
    const { data: userData, error: userError } = await supabaseForUser.auth.getUser();
    if (userError || !userData || !userData.user) {
      return new Response(
        JSON.stringify({ error: 'not_authenticated' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const caller = userData.user;
    const callerRole = (caller.user_metadata as any)?.role ?? (caller.app_metadata as any)?.role;
    if (callerRole !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'not_admin' }),
        { status: 403, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== 'object') {
      return new Response(
        JSON.stringify({ error: 'invalid_json_payload' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const email = (body as any).email?.toString().trim() ?? '';
    const password = (body as any).password?.toString() ?? '';
    const fullName = (body as any).full_name?.toString().trim() ?? '';

    if (!email || !password) {
      return new Response(
        JSON.stringify({ error: 'email_password_required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const baseMetadata: Record<string, unknown> = { role: 'student' };
    if (fullName) {
      baseMetadata.full_name = fullName;
    }

    const { data: createdUser, error: createError } = await supabaseService.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: baseMetadata,
      // Source de confiance : `app_metadata` n'est pas modifiable par le client.
      app_metadata: { role: 'student' },
    });

    if (createError || !createdUser || !createdUser.user) {
      const brut = createError?.message ?? String(createError ?? '');
      const code = codeDeLErreur(brut);
      console.error('Error creating student auth user', brut);
      return new Response(
        // `detail` porte le message d'origine : l'ecran affiche `error`, mais
        // un diagnostic reste possible sans rouvrir les journaux.
        JSON.stringify({ error: code, detail: brut }),
        {
          status: code === 'auth_user_creation_failed' ? 500 : 400,
          headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
        },
      );
    }

    const userId = createdUser.user.id;

    // La fiche `app.students` est posee par le trigger. On la RELIT plutot que
    // de la supposer : si le trigger venait a changer, l'ecran afficherait un
    // succes pour un etudiant qui n'existe qu'a moitie.
    const { data: fiche } = await supabaseService
      .schema('app')
      .from('students')
      .select('id, full_name')
      .eq('id', userId)
      .maybeSingle();

    return new Response(
      JSON.stringify({
        success: true,
        user_id: userId,
        email,
        fiche_etudiant_creee: !!fiche,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  } catch (e) {
    console.error('Unexpected error in admin-create-student-account', e);
    return new Response(
      JSON.stringify({ error: 'unexpected_error' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }
});
