// Supabase Edge Function: compress-video
// Compresses and watermarks a video on Kamatera Cloud.
// Called after user finishes editing and clicks "Next" button.
// Responsibilities:
//   1. Download the raw video from Storage
//   2. Compress using FFmpeg on Kamatera (185.167.97.144)
//   3. Add Academia watermark
//   4. Upload compressed+watermarked video back to Storage
//   5. Return the public URL of the processed video
//
// Body: { 
//   bucket: string, 
//   path: string, 
//   user_id: string,
//   quality?: 'low' | 'medium' | 'high' 
// }

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const KAMATERA_IP = '185.167.97.144';
const KAMATERA_FFMPEG_URL = `http://${KAMATERA_IP}:8001/compress`;

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
    console.error('[compress-video] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return jsonResponse({ success: false, error: 'Server misconfigured' }, 500);
  }

  let bucket: string;
  let path: string;
  let userId: string;
  let quality: string = 'medium';

  try {
    const body = await req.json();
    bucket = body.bucket;
    path = body.path;
    userId = body.user_id;
    quality = body.quality ?? 'medium';

    if (!bucket || !path || !userId) {
      return jsonResponse({ 
        success: false, 
        error: 'bucket, path, and user_id are required' 
      }, 400);
    }
  } catch {
    return jsonResponse({ success: false, error: 'Invalid JSON body' }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    console.log(`[compress-video] Processing: bucket=${bucket}, path=${path}, quality=${quality}`);

    // 1. Get public URL of the raw video
    const { data: urlData } = supabase.storage.from(bucket).getPublicUrl(path);
    const sourceUrl = urlData?.publicUrl;

    if (!sourceUrl) {
      return jsonResponse({ success: false, error: 'Cannot resolve source URL' }, 500);
    }

    console.log(`[compress-video] Source URL: ${sourceUrl}`);

    // 2. Call Kamatera FFmpeg service for compression + watermark
    const kamateraPayload = {
      source_url: sourceUrl,
      output_bucket: bucket,
      output_path: path.replace(/\.mp4$/i, '_compressed.mp4'),
      quality: quality,
      watermark: true,
      watermark_text: 'Academia',
    };

    console.log(`[compress-video] Calling Kamatera: ${KAMATERA_FFMPEG_URL}`);
    const kamateraResponse = await fetch(KAMATERA_FFMPEG_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(kamateraPayload),
    });

    if (!kamateraResponse.ok) {
      const errorText = await kamateraResponse.text();
      console.error(`[compress-video] Kamatera error: ${errorText}`);
      return jsonResponse({ 
        success: false, 
        error: `Kamatera processing failed: ${errorText}` 
      }, 500);
    }

    const kamateraResult = await kamateraResponse.json();
    console.log(`[compress-video] Kamatera result:`, kamateraResult);

    if (!kamateraResult.success) {
      return jsonResponse({ 
        success: false, 
        error: kamateraResult.error || 'Kamatera processing failed' 
      }, 500);
    }

    // 3. Get public URL of the compressed video
    const outputPath = kamateraResult.output_path;
    const { data: outputUrlData } = supabase.storage.from(bucket).getPublicUrl(outputPath);
    const outputUrl = outputUrlData?.publicUrl;

    if (!outputUrl) {
      return jsonResponse({ success: false, error: 'Cannot resolve output URL' }, 500);
    }

    console.log(`[compress-video] Output URL: ${outputUrl}`);

    return jsonResponse({
      success: true,
      output_url: outputUrl,
      output_path: outputPath,
      original_size: kamateraResult.original_size,
      compressed_size: kamateraResult.compressed_size,
      compression_ratio: kamateraResult.compression_ratio,
      processing_time: kamateraResult.processing_time,
    });
  } catch (e) {
    console.error('[compress-video] Unexpected error:', e);
    return jsonResponse({ success: false, error: String(e) }, 500);
  }
});
