// Edge Function: assemble-video-chunks
// Concatenates uploaded video chunks into a single file on the server.
// Called after all chunks have been uploaded to Storage.
// Body: { bucket, chunk_paths[], output_path, content_type, total_chunks }

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
  const chunkPaths = body.chunk_paths as string[];
  const outputPath = body.output_path as string;
  const contentType = body.content_type as string || 'video/mp4';
  const totalChunks = body.total_chunks as number;

  if (!bucket || !chunkPaths || !outputPath) {
    return jsonResponse({ success: false, error: 'Missing required fields' }, 400);
  }

  if (chunkPaths.length !== totalChunks) {
    return jsonResponse({ success: false, error: 'Chunk count mismatch' }, 400);
  }

  try {
    // Download all chunks
    const chunks: Uint8Array[] = [];
    
    for (const chunkPath of chunkPaths) {
      const { data, error } = await supabase.storage.from(bucket).download(chunkPath);
      if (error || !data) {
        throw new Error(`Failed to download chunk ${chunkPath}: ${error?.message}`);
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
      .from(bucket)
      .upload(outputPath, assembled.buffer, {
        contentType,
        upsert: true,
      });

    if (uploadError) {
      throw new Error(`Upload failed: ${uploadError.message}`);
    }

    // Clean up chunks (best effort, don't fail if this fails)
    const cleanupPromises = chunkPaths.map(chunkPath => 
      supabase.storage.from(bucket).remove([chunkPath]).catch(() => {})
    );
    await Promise.all(cleanupPromises);

    // Get public URL
    const { data: urlData } = supabase.storage.from(bucket).getPublicUrl(outputPath);
    const publicUrl = urlData?.publicUrl || '';

    return jsonResponse({
      success: true,
      public_url: publicUrl,
      size_mb: (totalSize / 1024 / 1024).toFixed(1),
      chunks_assembled: totalChunks,
    });

  } catch (error) {
    return jsonResponse({
      success: false,
      error: error instanceof Error ? error.message : 'Assembly failed',
    }, 500);
  }
});
