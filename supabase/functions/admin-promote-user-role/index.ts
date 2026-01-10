// Supabase Edge Function: admin-promote-user-role
// Promote an existing user (typically with role = 'student') to 'admin' or 'university'.
// For 'university', also ensure an app.universities row exists and link via university_id.

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
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY for admin-promote-user-role Edge Function');
}

function slugifyName(name: string): string {
  const base = name
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);
  return base || 'university';
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

    const targetUserId = (body as any).target_user_id?.toString().trim() ?? '';
    const targetRole = (body as any).target_role?.toString().trim() ?? '';
    const universityName = (body as any).university_name?.toString().trim() ?? '';

    if (!targetUserId) {
      return new Response(
        JSON.stringify({ error: 'target_user_id_required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    if (targetRole !== 'admin' && targetRole !== 'university') {
      return new Response(
        JSON.stringify({ error: 'invalid_target_role' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const { data: existingUserResult, error: getError } = await supabaseService.auth.admin.getUserById(targetUserId);
    if (getError || !existingUserResult || !existingUserResult.user) {
      console.error('Error fetching target user for promotion', getError?.message ?? getError);
      return new Response(
        JSON.stringify({ error: 'target_user_not_found' }),
        { status: 404, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const targetUser = existingUserResult.user;
    const email = targetUser.email ?? '';
    const currentMeta = (targetUser.user_metadata as any) ?? {};
    const currentRole = currentMeta.role ?? (targetUser.app_metadata as any)?.role ?? null;

    if (!email) {
      return new Response(
        JSON.stringify({ error: 'user_email_missing' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    if (targetRole === 'admin') {
      const newMeta: Record<string, unknown> = {
        ...currentMeta,
        role: 'admin',
      };

      const { data: updatedUser, error: updateError } = await supabaseService.auth.admin.updateUserById(
        targetUserId,
        {
          user_metadata: newMeta,
        },
      );

      if (updateError || !updatedUser || !updatedUser.user) {
        console.error('Error promoting user to admin', updateError?.message ?? updateError);
        return new Response(
          JSON.stringify({ error: 'promotion_failed' }),
          { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
        );
      }

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
          console.error('Error sending password reset email after admin promotion', resetError.message ?? resetError);
        }
      } catch (e) {
        console.error('Unexpected error while sending password reset email after admin promotion', e);
      }

      return new Response(
        JSON.stringify({ success: true, user_id: targetUserId, previous_role: currentRole, new_role: 'admin' }),
        { status: 200, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    // targetRole === 'university'
    if (!universityName) {
      return new Response(
        JSON.stringify({ error: 'university_name_required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const slug = slugifyName(universityName);

    const { data: uniRow, error: uniError } = await supabaseService
      .schema('app')
      .from('universities')
      .upsert(
        {
          name: universityName,
          slug,
          contact_email: email,
          is_active: true,
        },
        { onConflict: 'slug' },
      )
      .select()
      .single();

    if (uniError || !uniRow) {
      const raw: any = uniError;
      const errMsg =
        (raw && typeof raw.message === 'string' && raw.message) ||
        (typeof raw === 'string' ? raw : JSON.stringify(raw ?? {}));
      console.error('Error upserting university during promotion', errMsg);
      return new Response(
        JSON.stringify({ error: `university_insert_failed: ${errMsg}` }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const universityId = (uniRow as any).id as string;

    const newMeta: Record<string, unknown> = {
      ...currentMeta,
      role: 'university',
      university_id: universityId,
      full_name: universityName,
    };

    const { data: updatedUser2, error: updateError2 } = await supabaseService.auth.admin.updateUserById(
      targetUserId,
      {
        user_metadata: newMeta,
      },
    );

    if (updateError2 || !updatedUser2 || !updatedUser2.user) {
      console.error('Error promoting user to university', updateError2?.message ?? updateError2);
      return new Response(
        JSON.stringify({ error: 'promotion_failed' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    try {
      const redirectTo =
        Deno.env.get('AUTH_REDIRECT_URL') ??
        Deno.env.get('AUTH_PASSWORD_RESET_REDIRECT_URL') ??
        undefined;

      const { error: resetError2 } = await supabaseService.auth.resetPasswordForEmail(
        email,
        redirectTo ? { redirectTo } : undefined,
      );
      if (resetError2) {
        console.error('Error sending password reset email after university promotion', resetError2.message ?? resetError2);
      }
    } catch (e) {
      console.error('Unexpected error while sending password reset email after university promotion', e);
    }

    return new Response(
      JSON.stringify({
        success: true,
        user_id: targetUserId,
        previous_role: currentRole,
        new_role: 'university',
        university_id: universityId,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  } catch (e) {
    console.error('Unexpected error in admin-promote-user-role', e);
    return new Response(
      JSON.stringify({ error: 'internal_error' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }
});
