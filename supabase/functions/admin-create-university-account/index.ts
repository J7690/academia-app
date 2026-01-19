// Supabase Edge Function: admin-create-university-account
// Create a new university partner + associated auth user with role = 'university'.
// This function is restricted to admins (role stored in user_metadata.role).

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  // Important: allow x-client-info used by Supabase clients (supabase-dart / supabase-js)
  // so that Flutter Web calls via supabase.functions.invoke pass CORS preflight.
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY for admin-create-university-account Edge Function');
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
        JSON.stringify({ error: 'Authorization Bearer manquant' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const jwt = authHeader.split(' ', 2)[1]?.trim();
    if (!jwt) {
      return new Response(
        JSON.stringify({ error: 'JWT invalide' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    if (!apiKeyHeader) {
      return new Response(
        JSON.stringify({ error: 'apikey manquante' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(
        JSON.stringify({ error: 'Supabase backend non configuré' }),
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
        JSON.stringify({ error: 'Utilisateur non authentifié' }),
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
        JSON.stringify({ error: 'Payload JSON invalide' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const email = (body as any).email?.toString().trim() ?? '';
    const password = (body as any).password?.toString() ?? '';
    const universityName = (body as any).university_name?.toString().trim() ?? '';

    if (!email || !password || !universityName) {
      return new Response(
        JSON.stringify({ error: 'email_password_university_name_required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const slug = slugifyName(universityName);

    // On utilise un upsert sur le slug pour rendre l'opération idempotente.
    // Si l'université existe déjà avec le même slug, on met simplement à jour
    // quelques champs de base et on réutilise cette entrée.
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
      const raw = uniError as any;
      const errMsg =
        (raw && typeof raw.message === 'string' && raw.message) ||
        (typeof raw === 'string' ? raw : JSON.stringify(raw ?? {}));

      console.error('Error upserting university', errMsg);
      return new Response(
        JSON.stringify({ error: `university_insert_failed: ${errMsg}` }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const universityId = (uniRow as any).id as string;

    const { data: createdUser, error: createError } = await supabaseService.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        role: 'university',
        university_id: universityId,
        full_name: universityName,
      },
    });

    if (createError || !createdUser || !createdUser.user) {
      console.error('Error creating university auth user', createError?.message ?? createError);
      // On désactive l\'université créée pour éviter les entrées orphelines
      try {
        await supabaseService
          .from('app.universities')
          .update({ is_active: false })
          .eq('id', universityId);
      } catch (e) {
        console.error('Failed to rollback university after user creation error', e);
      }

      return new Response(
        JSON.stringify({ error: 'auth_user_creation_failed' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const userId = createdUser.user.id;

    // Clonage automatique du mini-site & des offres à partir de l'université modèle Arbilo.
    // Cette opération est idempotente et n'ajoute du contenu que si l'université cible
    // n'a encore aucun bloc/média/programme configuré. En cas d'erreur, on ne bloque pas
    // la création du compte, on se contente de logguer l'erreur pour audit.
    try {
      const { error: cloneError } = await supabaseService.rpc(
        'app_admin_clone_university_from_template',
        {
          p_template_slug: 'universite-arbilo',
          p_target_university_id: universityId,
        },
      );
      if (cloneError) {
        console.error(
          'Error cloning university mini-site & offers from template Arbilo',
          cloneError.message ?? cloneError,
        );
      }
    } catch (e) {
      console.error('Unexpected error while cloning university mini-site from template', e);
    }

    // Envoyer un email de réinitialisation de mot de passe via Supabase
    // afin que le partenaire définisse lui-même son mot de passe.
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
        console.error('Error sending password reset email to university user', resetError.message ?? resetError);
      }
    } catch (e) {
      console.error('Unexpected error while sending password reset email to university user', e);
    }

    return new Response(
      JSON.stringify({ success: true, university_id: universityId, user_id: userId }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  } catch (e) {
    console.error('Unexpected error in admin-create-university-account', e);
    return new Response(
      JSON.stringify({ error: 'internal_error' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }
});
