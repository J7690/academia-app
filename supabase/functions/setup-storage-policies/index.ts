// Edge Function: setup-storage-policies
// Proxy d'upload pour community-media qui bypass RLS via service_role.
// Utilisé tant que les policies RLS ne sont pas configurées sur storage.objects.
//
// POST /setup-storage-policies
//   Body: binary file data
//   Headers: x-file-path (storage path), x-content-type (MIME), Authorization (user JWT)

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-file-path, x-content-type',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    // 1. Vérifier que l'utilisateur est authentifié
    const authHeader = req.headers.get('authorization') ?? '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!jwt) {
      return new Response(
        JSON.stringify({ error: 'auth_required' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const apiKey = req.headers.get('apikey') ?? SUPABASE_ANON_KEY;
    const supabaseUser = createClient(SUPABASE_URL, apiKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });

    const { data: userData, error: userErr } = await supabaseUser.auth.getUser();
    if (userErr || !userData?.user) {
      return new Response(
        JSON.stringify({ error: 'not_authenticated' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const userId = userData.user.id;

    // 2. Récupérer le chemin et le type MIME
    const filePath = req.headers.get('x-file-path') ?? '';
    const contentType = req.headers.get('x-content-type') ?? 'application/octet-stream';

    if (!filePath) {
      return new Response(
        JSON.stringify({ error: 'x-file-path header required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    // 3. Vérifier que le chemin commence par le user_id (sécurité)
    if (!filePath.startsWith(userId + '/')) {
      return new Response(
        JSON.stringify({ error: 'path_must_start_with_user_id' }),
        { status: 403, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    // 4. Lire le body binaire
    const fileBytes = new Uint8Array(await req.arrayBuffer());
    if (fileBytes.length === 0) {
      return new Response(
        JSON.stringify({ error: 'empty_body' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    // 5. Upload via service_role (bypass RLS)
    const supabaseService = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { error: uploadErr } = await supabaseService.storage
      .from('community-media')
      .upload(filePath, fileBytes, {
        contentType,
        upsert: true,
      });

    if (uploadErr) {
      console.error('[setup-storage-policies] upload error:', uploadErr);
      return new Response(
        JSON.stringify({ error: uploadErr.message }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    // 6. Retourner l'URL publique
    const publicUrl = `${SUPABASE_URL}/storage/v1/object/public/community-media/${filePath}`;

    return new Response(
      JSON.stringify({ success: true, url: publicUrl }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  } catch (e) {
    console.error('[setup-storage-policies] unexpected error:', e);
    return new Response(
      JSON.stringify({ error: (e as Error).message }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }
});
