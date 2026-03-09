// Supabase Edge Function: admin-hard-delete-user-account
// Hard delete for any account type (admin, university, commercial, instructor, student),
// while keeping a soft-delete + audit trail and inserting an archive row.

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
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY for admin-hard-delete-user-account Edge Function');
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
    const reasonRaw = (body as any).reason;
    const reason = typeof reasonRaw === 'string' && reasonRaw.trim().length > 0 ? reasonRaw.trim() : null;

    if (!targetUserId) {
      return new Response(
        JSON.stringify({ error: 'target_user_id_required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    if (targetUserId === caller.id) {
      return new Response(
        JSON.stringify({ error: 'cannot_delete_self' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const { data: existingUserResult, error: getError } =
      await supabaseService.auth.admin.getUserById(targetUserId);

    if (getError || !existingUserResult || !existingUserResult.user) {
      console.error('Error fetching target user for hard delete', getError?.message ?? getError);
      return new Response(
        JSON.stringify({ error: 'target_user_not_found' }),
        { status: 404, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const targetUser = existingUserResult.user;
    const email = targetUser.email ?? '';
    const userMetadata = (targetUser.user_metadata as any) ?? {};
    const appMetadata = (targetUser.app_metadata as any) ?? {};
    const targetRole = userMetadata.role ?? appMetadata.role ?? null;
    const fullName = userMetadata.full_name ?? appMetadata.full_name ?? null;
    const originalUniversityId = userMetadata.university_id ?? appMetadata.university_id ?? null;
    const originalCreatedAt = targetUser.created_at ?? null;
    const originalLastSignInAt = (targetUser as any).last_sign_in_at ?? null;

    if (!email) {
      return new Response(
        JSON.stringify({ error: 'user_email_missing' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    // 1) Soft delete via existing RPC for audit + status logic.
    const { data: deleteResult, error: deleteRpcError } = await supabaseForUser.rpc(
      'app_admin_delete_user_account',
      {
        p_target_user_id: targetUserId,
        p_reason: reason ?? 'hard_delete',
      },
    );

    if (deleteRpcError) {
      console.error('Error during soft delete in hard delete flow', deleteRpcError.message ?? deleteRpcError);
      return new Response(
        JSON.stringify({ success: false, error: 'soft_delete_failed' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    if (!deleteResult || (deleteResult as any).success !== true) {
      const errMsg = (deleteResult as any)?.error ?? 'soft_delete_failed';
      console.error('Soft delete RPC reported failure in hard delete flow', errMsg);
      return new Response(
        JSON.stringify({ success: false, error: errMsg }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    // 2) Archive the user before physical deletion.
    const archivePayload = {
      user_id: targetUserId,
      email,
      role: targetRole,
      full_name: typeof fullName === 'string' && fullName.trim().length > 0 ? fullName.trim() : null,
      original_university_id: originalUniversityId,
      original_metadata: userMetadata,
      original_created_at: originalCreatedAt,
      original_last_sign_in_at: originalLastSignInAt,
      deleted_reason: reason,
      deleted_by: caller.id,
    };

    const { error: archiveError } = await supabaseService
      .schema('app')
      .from('admin_deleted_users_archive')
      .insert(archivePayload);

    if (archiveError) {
      console.error('Error inserting admin_deleted_users_archive row', archiveError.message ?? archiveError);
      return new Response(
        JSON.stringify({ success: false, error: 'archive_failed' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    // 3) Hard delete from auth.users so that the email can be reused.
    const { error: hardDeleteError } = await supabaseService.auth.admin.deleteUser(targetUserId);
    if (hardDeleteError) {
      console.error('Error during auth.admin.deleteUser in hard delete flow', hardDeleteError.message ?? hardDeleteError);
      return new Response(
        JSON.stringify({ success: false, error: 'hard_delete_failed' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    return new Response(
      JSON.stringify({ success: true, hard_deleted: true, role: targetRole, email }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  } catch (e) {
    console.error('Unexpected error in admin-hard-delete-user-account', e);
    return new Response(
      JSON.stringify({ error: 'internal_error' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }
});
