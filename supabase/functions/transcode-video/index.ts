// Supabase Edge Function: transcode-video
// Lightweight video pipeline orchestrator.
// Called after a video source is registered via app_videoasset_register_uploaded_source.
// Responsibilities:
//   1. Create an "original" rendition entry for the uploaded source.
//   2. Build a public playback URL from the Storage path.
//   3. Update the video_asset status to 'ready'.
//   4. Optionally set a poster_url (thumbnail) if provided.
//
// For heavy transcoding (HLS, multi-bitrate), delegate to Railway worker (Phase 7).

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
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ success: false, error: 'Method not allowed' }, 405);
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error('[transcode-video] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return jsonResponse({ success: false, error: 'Server misconfigured' }, 500);
  }

  let videoAssetId: string;
  let posterUrl: string | null = null;

  try {
    const body = await req.json();
    videoAssetId = body.video_asset_id;
    posterUrl = body.poster_url ?? null;

    if (!videoAssetId) {
      return jsonResponse({ success: false, error: 'video_asset_id is required' }, 400);
    }
  } catch {
    return jsonResponse({ success: false, error: 'Invalid JSON body' }, 400);
  }

  // Use service role to bypass RLS
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const appDb = supabase.schema('app');

    // ── 1. Fetch the video_asset and its primary source ──
    const { data: asset, error: assetErr } = await appDb
      .from('video_assets')
      .select('id, status, owner_id')
      .eq('id', videoAssetId)
      .single();

    if (assetErr || !asset) {
      console.error('[transcode-video] video_asset not found:', assetErr);
      return jsonResponse({ success: false, error: 'video_asset not found' }, 404);
    }

    // Fetch the latest source (schema does not have a 'role' column)
    const { data: source, error: srcErr } = await appDb
      .from('video_sources')
      .select('id, storage_bucket, storage_path, mime_type, file_size_bytes')
      .eq('video_asset_id', videoAssetId)
      .order('created_at', { ascending: false })
      .limit(1)
      .single();

    if (srcErr || !source) {
      console.error('[transcode-video] primary source not found:', srcErr);
      return jsonResponse({ success: false, error: 'Primary source not found' }, 404);
    }

    // ── 2. Build public URL for the source ──
    const { data: urlData } = supabase.storage
      .from(source.storage_bucket)
      .getPublicUrl(source.storage_path);

    const publicUrl = urlData?.publicUrl ?? '';
    if (!publicUrl) {
      return jsonResponse({ success: false, error: 'Could not resolve public URL' }, 500);
    }

    console.log(`[transcode-video] Public URL: ${publicUrl}`);

    // ── 3. Upsert an "original" rendition ──
    // app.video_renditions schema uses rendition_key/kind/status.
    const { error: rendErr } = await appDb
      .from('video_renditions')
      .upsert(
        {
          video_asset_id: videoAssetId,
          rendition_key: 'original',
          kind: 'mp4',
          width: null,
          height: null,
          bitrate_kbps: null,
          fps: null,
          codec: null,
          file_size_bytes: source.file_size_bytes,
          storage_bucket: source.storage_bucket,
          storage_path: source.storage_path,
          public_url_hint: publicUrl,
          status: 'ready',
          error: null,
        },
        { onConflict: 'video_asset_id,rendition_key' }
      );

    if (rendErr) {
      console.error('[transcode-video] rendition upsert error:', rendErr);
      // Non-fatal — continue
    }

    // ── 4. Update video_asset status to ready ──
    const updatePayload: Record<string, unknown> = {
      status: 'ready',
      updated_at: new Date().toISOString(),
    };

    if (posterUrl) {
      updatePayload.poster_url = posterUrl;
    }

    const { error: updateErr } = await appDb
      .from('video_assets')
      .update(updatePayload)
      .eq('id', videoAssetId);

    if (updateErr) {
      console.error('[transcode-video] status update error:', updateErr);
      return jsonResponse({ success: false, error: 'Failed to update video_asset status' }, 500);
    }

    console.log(`[transcode-video] video_asset ${videoAssetId} marked as ready`);

    return jsonResponse({
      success: true,
      video_asset_id: videoAssetId,
      playback: {
        best_url: publicUrl,
        poster_url: posterUrl,
        renditions: [
          { label: 'original', url: publicUrl, mime_type: source.mime_type ?? 'video/mp4' },
        ],
      },
    });
  } catch (e) {
    console.error('[transcode-video] Unexpected error:', e);
    return jsonResponse({ success: false, error: String(e) }, 500);
  }
});
