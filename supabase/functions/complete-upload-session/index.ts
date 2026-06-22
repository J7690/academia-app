// Edge Function: complete-upload-session
// Finalize a resumable upload session by assembling chunks
// Called after all chunks have been uploaded
// Body: { session_id }

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

  const sessionId = body.session_id as string;

  if (!sessionId) {
    return jsonResponse({ success: false, error: 'Missing session_id' }, 400);
  }

  try {
    // Fetch upload session
    const { data: session, error: sessionError } = await supabase
      .from('upload_sessions')
      .select('*')
      .eq('id', sessionId)
      .single();

    if (sessionError || !session) {
      console.error('[complete-upload-session] Session not found:', sessionError);
      return jsonResponse({ success: false, error: 'Upload session not found' }, 404);
    }

    // Check if session is expired
    if (new Date(session.expires_at) < new Date()) {
      await supabase.from('upload_sessions').update({ status: 'expired' }).eq('id', sessionId);
      return jsonResponse({ success: false, error: 'Upload session expired' }, 400);
    }

    // Check if session is already completed
    if (session.status === 'completed') {
      return jsonResponse({
        success: true,
        final_path: session.final_path,
        message: 'Session already completed',
      });
    }

    // Calculate total chunks
    const chunkSize = 8 * 1024 * 1024; // 8MB
    const totalChunks = Math.ceil(session.file_size / chunkSize);

    // Generate chunk paths
    const chunkPaths: string[] = [];
    for (let i = 0; i < totalChunks; i++) {
      chunkPaths.push(`${session.path}_chunks/part_${i.toString().padStart(4, '0')}`);
    }

    // Download all chunks
    const chunks: Uint8Array[] = [];
    for (const chunkPath of chunkPaths) {
      const { data, error } = await supabase.storage.from(session.bucket).download(chunkPath);
      if (error || !data) {
        console.error(`[complete-upload-session] Failed to download chunk ${chunkPath}:`, error);
        return jsonResponse({ success: false, error: `Failed to download chunk: ${chunkPath}` }, 500);
      }
      chunks.push(new Uint8Array(await data.arrayBuffer()));
    }

    // Calculate total size
    const totalSize = chunks.reduce((sum, chunk) => sum + chunk.length, 0);

    // Assemble chunks into single buffer
    const assembled = new Uint8Array(totalSize);
    let offset = 0;
    for (const chunk of chunks) {
      assembled.set(chunk, offset);
      offset += chunk.length;
    }

    // Upload assembled file
    const { error: uploadError } = await supabase.storage
      .from(session.bucket)
      .upload(session.path, assembled.buffer, {
        contentType: session.content_type,
        upsert: true,
      });

    if (uploadError) {
      console.error('[complete-upload-session] Upload failed:', uploadError);
      return jsonResponse({ success: false, error: 'Failed to upload assembled file' }, 500);
    }

    // Clean up chunks (best effort, don't fail if this fails)
    const cleanupPromises = chunkPaths.map(chunkPath =>
      supabase.storage.from(session.bucket).remove([chunkPath]).catch((e) => {
        console.warn(`[complete-upload-session] Failed to cleanup chunk ${chunkPath}:`, e);
      })
    );
    await Promise.all(cleanupPromises);

    // Get public URL
    const { data: urlData } = supabase.storage.from(session.bucket).getPublicUrl(session.path);
    const publicUrl = urlData?.publicUrl || '';

    // Update session status
    const { error: updateError } = await supabase
      .from('upload_sessions')
      .update({
        status: 'completed',
        final_path: session.path,
        uploaded_bytes: session.file_size,
      })
      .eq('id', sessionId);

    if (updateError) {
      console.error('[complete-upload-session] Update error:', updateError);
      // Non-fatal - continue
    }

    console.log(`[complete-upload-session] Session ${sessionId} completed: ${session.path}`);

    return jsonResponse({
      success: true,
      session_id: sessionId,
      final_path: session.path,
      public_url: publicUrl,
      size_mb: (totalSize / 1024 / 1024).toFixed(1),
      chunks_assembled: totalChunks,
    });

  } catch (error) {
    console.error('[complete-upload-session] Unexpected error:', error);
    return jsonResponse({
      success: false,
      error: error instanceof Error ? error.message : 'Assembly failed',
    }, 500);
  }
});
