// Edge Function: create-upload-session
// Initialize a resumable upload session following YouTube/TikTok protocol
// Returns session ID, upload URL, and expiration time
// Body: { bucket, path, file_size, content_type }

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ success: false, error: 'Method not allowed' }, 405);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return jsonResponse({ success: false, error: 'Invalid body' }, 400); }

  const bucket = body.bucket as string;
  const path = body.path as string;
  const fileSize = body.file_size as number;
  const contentType = body.content_type as string || 'video/mp4';

  if (!bucket || !path || !fileSize) {
    return jsonResponse({ success: false, error: 'Missing required fields: bucket, path, file_size' }, 400);
  }

  try {
    // Get authenticated user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return jsonResponse({ success: false, error: 'Unauthorized' }, 401);
    }

    // Generate unique session ID
    const sessionId = crypto.randomUUID();

    // Calculate expiration (1 hour from now)
    const expiresAt = new Date(Date.now() + 3600000).toISOString();

    // Insert upload session
    const { error: insertError } = await supabase
      .from('upload_sessions')
      .insert({
        id: sessionId,
        bucket,
        path,
        file_size: fileSize,
        content_type: contentType,
        uploaded_bytes: 0,
        status: 'initialized',
        expires_at: expiresAt,
        user_id: user.id,
        metadata: {
          chunk_size: 8 * 1024 * 1024, // 8MB chunks
          total_chunks: Math.ceil(fileSize / (8 * 1024 * 1024)),
        },
      });

    if (insertError) {
      console.error('[create-upload-session] Insert error:', insertError);
      return jsonResponse({ success: false, error: 'Failed to create upload session' }, 500);
    }

    console.log(`[create-upload-session] Session created: ${sessionId} for user ${user.id}`);

    return jsonResponse({
      success: true,
      session_id: sessionId,
      bucket,
      path,
      file_size: fileSize,
      content_type: contentType,
      chunk_size: 8 * 1024 * 1024,
      total_chunks: Math.ceil(fileSize / (8 * 1024 * 1024)),
      expires_at: expiresAt,
    });

  } catch (error) {
    console.error('[create-upload-session] Unexpected error:', error);
    return jsonResponse({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    }, 500);
  }
});
