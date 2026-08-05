// Supabase Edge Function : admin-promote-to-orientation-counselor
//
// Promeut un compte existant — typiquement un etudiant — en conseiller
// d'orientation. Reserve aux administrateurs.
//
// v3 — correctif du not_admin, identique a celui de la fonction de creation.
//   La RPC etait appelee avec le client service_role, sans JWT utilisateur :
//   auth.uid() valait NULL, app_is_admin_user() renvoyait false, et la RPC
//   refusait sa propre Edge Function. Elle est desormais appelee avec le
//   client portant le JWT de l'administrateur.

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

    const supabaseForUser = createClient(SUPABASE_URL, apiKeyHeader, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
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

    const targetUserId = String(body.user_id ?? '').trim();
    if (!targetUserId) return json({ error: 'user_id_required' }, 400);

    const { data: targetData, error: targetError } =
      await supabaseService.auth.admin.getUserById(targetUserId);
    if (targetError || !targetData?.user) return json({ error: 'user_not_found' }, 404);

    const target = targetData.user;
    const targetMeta = (target.user_metadata as Record<string, unknown>) ?? {};
    const previousRole = (targetMeta.role as string)
      ?? ((target.app_metadata as Record<string, unknown>)?.role as string)
      ?? null;

    if (previousRole === 'admin' || previousRole === 'super_admin') {
      return json({ error: 'cannot_demote_admin' }, 409);
    }

    let fullName = String(body.full_name ?? '').trim();
    if (!fullName) fullName = String(targetMeta.full_name ?? '').trim();
    if (!fullName) fullName = (target.email ?? 'Conseiller').split('@')[0];

    const kind = String(body.kind ?? 'orientation');
    const allowedKinds = ['orientation', 'career', 'etudes_etranger', 'reconversion', 'psychologue'];
    if (!allowedKinds.includes(kind)) return json({ error: 'invalid_kind' }, 400);

    const specialites = Array.isArray(body.specialites) ? body.specialites.map(String) : [];
    const niveaux = Array.isArray(body.niveaux) ? body.niveaux.map(String) : [];
    const langues = Array.isArray(body.langues) && body.langues.length > 0
      ? body.langues.map(String) : ['fr'];
    const duree = Number(body.duree_minutes ?? 45);
    const tarif = Number(body.tarif_fcfa ?? 0);

    // 1. Le profil metier d'abord, via RPC portant le JWT de l'administrateur.
    //    S'il echoue, le role n'a pas bouge et le compte reste intact.
    const { data: rpcResult, error: rpcError } = await supabaseForUser.rpc(
      'app_admin_upsert_orientation_counselor',
      {
        p_user_id: targetUserId,
        p_full_name: fullName,
        p_kind: kind,
        p_specialites: specialites,
        p_niveaux: niveaux,
        p_langues: langues,
        p_bio: body.bio ? String(body.bio) : null,
        p_tarif_fcfa: Number.isFinite(tarif) ? tarif : 0,
        p_duree_minutes: Number.isFinite(duree) && duree > 0 ? duree : 45,
        p_is_active: true,
      },
    );

    const rpcOk = !rpcError && rpcResult && (rpcResult as Record<string, unknown>).success === true;
    if (!rpcOk) {
      const detail = rpcError?.message
        ?? (rpcResult as Record<string, unknown>)?.error
        ?? 'rpc_failed';
      return json({ error: 'profile_creation_failed', detail: String(detail) }, 500);
    }

    // 2. Le role — necessite la cle de service.
    const { error: updateError } = await supabaseService.auth.admin.updateUserById(
      targetUserId,
      {
        user_metadata: { ...targetMeta, role: 'orientation_counselor', full_name: fullName },
        app_metadata: {
          ...((target.app_metadata as Record<string, unknown>) ?? {}),
          role: 'orientation_counselor',
        },
      },
    );

    if (updateError) {
      await supabaseForUser.rpc('app_admin_set_orientation_counselor_active', {
        p_user_id: targetUserId,
        p_is_active: false,
      });
      return json({ error: 'role_update_failed', detail: updateError.message }, 500);
    }

    await supabaseService.schema('app').from('admin_audit_log').insert({
      admin_id: caller.id,
      action_type: 'promote_orientation_counselor',
      target_type: 'user',
      target_id: targetUserId,
      target_user_id: targetUserId,
      details: { previous_role: previousRole, full_name: fullName, kind },
    });

    return json({
      success: true,
      user_id: targetUserId,
      previous_role: previousRole,
      new_role: 'orientation_counselor',
      full_name: fullName,
    });
  } catch (e) {
    return json({ error: 'unexpected_error', detail: String(e).slice(0, 300) }, 500);
  }
});
