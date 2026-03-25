// Supabase Edge Function: transcode-multi-resolution
// Downloads the original video source, calls FFmpeg on VPS to generate
// multiple resolution MP4s (720p, 480p, 240p), uploads them to Storage,
// and inserts video_renditions entries.
//
// Called after transcode-video marks the asset as ready.
// Body: { video_asset_id: string }

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const LIVEKIT_URL = Deno.env.get('LIVEKIT_URL') ?? ''; // reuse VPS IP
const VPS_IP = LIVEKIT_URL.replace('ws://', '').replace('wss://', '').replace(':7880', '').trim() || '185.220.204.214';

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

interface ResolutionProfile {
  key: string;
  height: number;
  bitrate: string;
  bitrateKbps: number;
}

const PROFILES: ResolutionProfile[] = [
  { key: 'mp4_720p', height: 720, bitrate: '1500k', bitrateKbps: 1500 },
  { key: 'mp4_480p', height: 480, bitrate: '800k', bitrateKbps: 800 },
  { key: 'mp4_240p', height: 240, bitrate: '400k', bitrateKbps: 400 },
];

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ success: false, error: 'Method not allowed' }, 405);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return jsonResponse({ success: false, error: 'Invalid body' }, 400); }

  const videoAssetId = body.video_asset_id as string;
  if (!videoAssetId) return jsonResponse({ success: false, error: 'video_asset_id required' }, 400);

  // Get the source file
  const { data: source, error: srcErr } = await supabase
    .from('video_sources')
    .select('*')
    .eq('video_asset_id', videoAssetId)
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  if (srcErr || !source) {
    return jsonResponse({ success: false, error: 'Source not found' }, 404);
  }

  const bucket = source.storage_bucket;
  const path = source.storage_path;

  // Get public URL of source
  const { data: urlData } = supabase.storage.from(bucket).getPublicUrl(path);
  const sourceUrl = urlData?.publicUrl;

  if (!sourceUrl) {
    return jsonResponse({ success: false, error: 'Cannot resolve source URL' }, 500);
  }

  // Check which renditions already exist
  const { data: existing } = await supabase
    .from('video_renditions')
    .select('rendition_key')
    .eq('video_asset_id', videoAssetId)
    .in('rendition_key', PROFILES.map(p => p.key));

  const existingKeys = new Set((existing ?? []).map((r: Record<string, string>) => r.rendition_key));
  const toProcess = PROFILES.filter(p => !existingKeys.has(p.key));

  if (toProcess.length === 0) {
    return jsonResponse({ success: true, message: 'All renditions already exist', renditions: [] });
  }

  // For each missing resolution, create a processing job entry
  // The actual FFmpeg processing will be done by a worker on the VPS
  // that polls video_processing_jobs
  const jobs: Record<string, unknown>[] = [];

  for (const profile of toProcess) {
    const outputPath = `renditions/${videoAssetId}/${profile.key}.mp4`;

    // Insert rendition entry as 'pending'
    const { data: rendition, error: rendErr } = await supabase
      .from('video_renditions')
      .insert({
        video_asset_id: videoAssetId,
        rendition_key: profile.key,
        kind: 'mp4',
        height: profile.height,
        width: null, // will be set after processing
        bitrate_kbps: profile.bitrateKbps,
        codec: 'h264',
        storage_bucket: 'video-assets',
        storage_path: outputPath,
        public_url_hint: null,
        status: 'pending',
      })
      .select()
      .single();

    if (rendErr) {
      console.error(`Failed to insert rendition ${profile.key}:`, rendErr);
      continue;
    }

    // Insert processing job
    const { error: jobErr } = await supabase
      .from('video_processing_jobs')
      .insert({
        video_asset_id: videoAssetId,
        job_type: 'transcode_resolution',
        status: 'queued',
        payload: {
          source_url: sourceUrl,
          source_bucket: bucket,
          source_path: path,
          output_bucket: 'video-assets',
          output_path: outputPath,
          rendition_id: rendition?.id,
          rendition_key: profile.key,
          target_height: profile.height,
          target_bitrate: profile.bitrate,
          ffmpeg_args: `-vf "scale=-2:${profile.height}" -c:v libx264 -preset fast -b:v ${profile.bitrate} -c:a aac -b:a 128k -movflags +faststart`,
        },
      });

    if (jobErr) {
      console.error(`Failed to insert job for ${profile.key}:`, jobErr);
      continue;
    }

    jobs.push({
      rendition_key: profile.key,
      rendition_id: rendition?.id,
      status: 'queued',
    });
  }

  return jsonResponse({
    success: true,
    video_asset_id: videoAssetId,
    jobs_created: jobs.length,
    jobs,
  });
});
