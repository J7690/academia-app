// Supabase Edge Function : admin-create-orientation-counselor
//
// Cree un compte conseiller d'orientation. Reserve aux administrateurs.
//
// v3 — correctif du not_admin.
//   La v2 appelait la RPC avec le client service_role. Dans ce contexte il n'y
//   a aucun JWT utilisateur : auth.uid() vaut NULL a l'interieur de la
//   fonction, app_is_admin_user() renvoie false, et la RPC refusait sa propre
//   Edge Function avec l'erreur not_admin.
//   La RPC est desormais appelee avec supabaseForUser, qui porte le JWT de
//   l'administrateur. auth.uid() est alors renseigne, le controle passe, et
//   l'action est attribuee a la bonne personne.
//
//   Les operations auth.admin (creation et suppression de compte) restent sur
//   le client service_role : elles exigent la cle de service.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const authHeader = req.headers.get('authorization') ?? req.headers.get('Authorization');
    const apiKeyHeader = req.headers.get('apikey');

    if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
      return json({ error: 'authorization_bearer_missing' }, 401);
    }
    const jwt = authHeader.split(' ', 2)[1]?.trim();
    if (!jwt) return json({ error: 'invalid_jwt' }, 401);
    if (!apiKeyHeader) return json({ error: 'apikey_missing' }, 401);
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return json({ error: 'supabase_backend_not_configured' }, 500);
    }

    // Client portant le JWT de l'administrateur : auth.uid() y est renseigne.
    const supabaseForUser = createClient(SUPABASE_URL, apiKeyHeader, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    // Client de service : reserve aux operations auth.admin.
    const supabaseService = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: userData, error: userError } = await supabaseForUser.auth.getUser();
    if (userError || !userData?.user) return json({ error: 'not_authenticated' }, 401);

    const caller = userData.user;
    const callerRole = (caller.user_metadata as Record<string, unknown>)?.role
      ?? (caller.app_metadata as Record<string, unknown>)?.role;
    if (callerRole !== 'admin' && callerRole !== 'super_admin') {
      return json({ error: 'not_admin' }, 403);
    }

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return json({ error: 'invalid_body' }, 400);
    }

    const email = String(body.email ?? '').trim().toLowerCase();
    const password = String(body.password ?? '');
    const fullName = String(body.full_name ?? '').trim();
    const kind = String(body.kind ?? 'orientation');
    const specialites = Array.isArray(body.specialites) ? body.specialites.map(String) : [];
    const niveaux = Array.isArray(body.niveaux) ? body.niveaux.map(String) : [];
    const langues = Array.isArray(body.langues) && body.langues.length > 0
      ? body.langues.map(String) : ['fr'];
    const bio = body.bio ? String(body.bio) : null;
    const tarif = Number(body.tarif_fcfa ?? 0);
    const duree = Number(body.duree_minutes ?? 45);

    if (!email || !email.includes('@')) return json({ error: 'invalid_email' }, 400);
    if (password.length < 8) return json({ error: 'password_too_short' }, 400);
    if (!fullName) return json({ error: 'full_name_required' }, 400);

    const allowedKinds = ['orientation', 'career', 'etudes_etranger', 'reconversion', 'psychologue'];
    if (!allowedKinds.includes(kind)) return json({ error: 'invalid_kind' }, 400);

    // 1. Le compte — necessite la cle de service.
    const { data: created, error: createError } = await supabaseService.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { role: 'orientation_counselor', full_name: fullName },
      app_metadata: { role: 'orientation_counselor' },
    });

    if (createError || !created?.user) {
      const message = createError?.message ?? 'create_user_failed';
      const already = message.toLowerCase().includes('already');
      return json({ error: already ? 'email_already_exists' : 'create_user_failed', detail: message },
                  already ? 409 : 400);
    }

    const newUserId = created.user.id;

    // 2. Le profil metier, via RPC appelee AVEC LE JWT DE L'ADMINISTRATEUR.
    const { data: rpcResult, error: rpcError } = await supabaseForUser.rpc(
      'app_admin_upsert_orientation_counselor',
      {
        p_user_id: newUserId,
        p_full_name: fullName,
        p_kind: kind,
        p_specialites: specialites,
        p_niveaux: niveaux,
        p_langues: langues,
        p_bio: bio,
        p_tarif_fcfa: Number.isFinite(tarif) ? tarif : 0,
        p_duree_minutes: Number.isFinite(duree) && duree > 0 ? duree : 45,
        p_is_active: true,
      },
    );

    const rpcOk = !rpcError && rpcResult && (rpcResult as Record<string, unknown>).success === true;
    if (!rpcOk) {
      // On ne laisse pas un compte orphelin derriere nous.
      await supabaseService.auth.admin.deleteUser(newUserId);
      const detail = rpcError?.message
        ?? (rpcResult as Record<string, unknown>)?.error
        ?? 'rpc_failed';
      return json({ error: 'profile_creation_failed', detail: String(detail) }, 500);
    }

    await supabaseService.schema('app').from('admin_audit_log').insert({
      admin_id: caller.id,
      action_type: 'create_orientation_counselor',
      target_type: 'user',
      target_id: newUserId,
      target_user_id: newUserId,
      details: { email, full_name: fullName, kind },
    });

    return json({
      success: true,
      user_id: newUserId,
      email,
      role: 'orientation_counselor',
      message: 'Conseiller cree. Il completera son profil et posera ses creneaux depuis son compte.',
    });
  } catch (e) {
    return json({ error: 'unexpected_error', detail: String(e).slice(0, 300) }, 500);
  }
});
