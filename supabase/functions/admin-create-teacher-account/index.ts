// Supabase Edge Function: admin-create-teacher-account
// Create a new teacher auth user with role = 'instructor'.
// Restricted to callers with user_metadata.role = 'admin'.

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
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY for admin-create-teacher-account Edge Function');
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
      global: {
        headers: {
          Authorization: `Bearer ${jwt}`,
        },
      },
    });

    const supabaseService = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

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

    const baseMetadata: Record<string, unknown> = {
      role: 'instructor',
    };
    if (fullName) {
      baseMetadata.full_name = fullName;
    }

    const { data: createdUser, error: createError } = await supabaseService.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: baseMetadata,
      app_metadata: { role: 'instructor' }, // source de confiance (non modifiable par le client)
    });

    if (createError || !createdUser || !createdUser.user) {
      console.error('Error creating teacher auth user', createError?.message ?? createError);
      return new Response(
        JSON.stringify({ error: 'auth_user_creation_failed' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const userId = createdUser.user.id;

    // Créer / mettre à jour le profil enseignant global (app.instructors)
    try {
      const { error: upsertError } = await supabaseService
        .schema('app')
        .from('instructors')
        .upsert(
          {
            id: userId,
            full_name: fullName || null,
          },
          { onConflict: 'id' },
        );
      if (upsertError) {
        console.error('Error upserting app.instructors for teacher', upsertError.message ?? upsertError);
      }
    } catch (e) {
      console.error('Unexpected error while upserting app.instructors for teacher', e);
    }

    // Envoyer un email de réinitialisation de mot de passe pour que l'enseignant définisse son mot de passe.
    try {
      const redirectTo =
        Deno.env.get('AUTH_REDIRECT_URL') ??
        Deno.env.get('AUTH_PASSWORD_RESET_REDIRECT_URL') ??
        undefined;

      const { error: resetError } = await supabaseService.auth.resetPasswordForEmail(
        email,
        redirectTo ? { redirectTo } : undefined,
      );
      if (resetError) {
        console.error('Error sending password reset email to teacher user', resetError.message ?? resetError);
      }
    } catch (e) {
      console.error('Unexpected error while sending password reset email to teacher user', e);
    }

    return new Response(
      JSON.stringify({ success: true, user_id: userId }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  } catch (e) {
    console.error('Unexpected error in admin-create-teacher-account', e);
    return new Response(
      JSON.stringify({ error: 'internal_error' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }
});
