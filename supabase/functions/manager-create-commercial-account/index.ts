// Academia — manager-create-commercial-account
// Cree un compte commercial (role=commercial). Autorise pour admin OU manager.
// Si l'appelant est manager, le commercial est rattache a son equipe et les
// admins sont notifies (attribution du manager) via app_manager_create_commercial.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function j(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return j({ error: 'method_not_allowed' }, 405);
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return j({ error: 'server_misconfigured' }, 500);

  const authHeader = req.headers.get('authorization') ?? req.headers.get('Authorization');
  const apiKeyHeader = req.headers.get('apikey');
  if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) return j({ error: 'authorization_bearer_missing' }, 401);
  const jwt = authHeader.split(' ', 2)[1]?.trim();
  if (!jwt) return j({ error: 'invalid_jwt' }, 401);
  if (!apiKeyHeader) return j({ error: 'apikey_missing' }, 401);

  const supabaseForUser = createClient(SUPABASE_URL, apiKeyHeader, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const supabaseService = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: userData, error: userError } = await supabaseForUser.auth.getUser();
  if (userError || !userData?.user) return j({ error: 'not_authenticated' }, 401);

  const caller = userData.user;
  const callerRole = (caller.app_metadata as any)?.role ?? (caller.user_metadata as any)?.role;
  if (callerRole !== 'admin' && callerRole !== 'manager') return j({ error: 'forbidden' }, 403);

  const body = await req.json().catch(() => null);
  if (!body || typeof body !== 'object') return j({ error: 'invalid_json_payload' }, 400);

  const email = (body as any).email?.toString().trim() ?? '';
  const password = (body as any).password?.toString() ?? '';
  const fullName = (body as any).full_name?.toString().trim() ?? '';
  const commissionRateRaw = (body as any).commission_rate;
  if (!email || !password) return j({ error: 'email_password_required' }, 400);

  const baseMetadata: Record<string, unknown> = { role: 'commercial' };
  if (fullName) baseMetadata.full_name = fullName;

  const { data: createdUser, error: createError } = await supabaseService.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: baseMetadata,
    app_metadata: { role: 'commercial' },
  });
  if (createError || !createdUser?.user) {
    console.error('createUser failed', createError?.message ?? createError);
    return j({ error: 'auth_user_creation_failed', detail: String(createError?.message ?? '') }, 500);
  }
  const userId = createdUser.user.id;

  // Finalisation (profil + rattachement manager + notif admin attribuee),
  // executee AU NOM de l'appelant (auth.uid = manager/admin).
  const rate = typeof commissionRateRaw === 'number' ? commissionRateRaw : 5.0;
  const { data: rpcData, error: rpcError } = await supabaseForUser.rpc('app_manager_create_commercial', {
    p_user_id: userId,
    p_rate: rate,
  });
  if (rpcError) {
    console.error('app_manager_create_commercial failed', rpcError.message ?? rpcError);
    return j({ error: 'profile_init_failed', detail: String(rpcError.message ?? '') }, 500);
  }

  // Email de definition du mot de passe.
  try {
    const redirectTo = Deno.env.get('AUTH_REDIRECT_URL') ?? Deno.env.get('AUTH_PASSWORD_RESET_REDIRECT_URL') ?? undefined;
    await supabaseService.auth.resetPasswordForEmail(email, redirectTo ? { redirectTo } : undefined);
  } catch (e) {
    console.error('reset email failed', e);
  }

  return j({ success: true, user_id: userId, result: rpcData });
});
