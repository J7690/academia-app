import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface MergeRequest {
  segment_paths: string[];
  bucket: string;
  output_path: string;
  transition?: 'none' | 'fade' | 'slide' | 'dissolve';
  transition_duration_ms?: number;
}

function jsonResp(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const {
      segment_paths,
      bucket,
      output_path,
      transition = 'none',
    } = (await req.json()) as MergeRequest;

    if (!segment_paths || segment_paths.length === 0) {
      return jsonResp({ success: false, error: 'No segments provided' }, 400);
    }

    if (transition !== 'none') {
      return jsonResp({
        success: false,
        error: 'Transitions are not supported server-side. Use client-side processing for transitions.',
      }, 400);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log(`[merge-video-segments] Downloading ${segment_paths.length} segments...`);

    // Download all segments as byte arrays
    const chunks: Uint8Array[] = [];

    for (let i = 0; i < segment_paths.length; i++) {
      const segmentPath = segment_paths[i];
      const { data, error } = await supabase.storage
        .from(bucket)
        .download(segmentPath);

      if (error || !data) {
        throw new Error(`Failed to download segment ${segmentPath}: ${error?.message}`);
      }

      chunks.push(new Uint8Array(await data.arrayBuffer()));
      console.log(`[merge-video-segments] Downloaded segment ${i + 1}/${segment_paths.length} (${chunks[i].length} bytes)`);
    }

    // Concatenate all chunks into a single buffer
    const totalSize = chunks.reduce((sum, c) => sum + c.length, 0);
    const merged = new Uint8Array(totalSize);
    let offset = 0;
    for (const chunk of chunks) {
      merged.set(chunk, offset);
      offset += chunk.length;
    }

    console.log(`[merge-video-segments] Merged ${chunks.length} segments into ${(totalSize / 1024 / 1024).toFixed(1)} MB`);

    // Upload merged file
    const { error: uploadError } = await supabase.storage
      .from(bucket)
      .upload(output_path, merged.buffer, {
        contentType: 'video/mp4',
        upsert: true,
      });

    if (uploadError) {
      throw new Error(`Failed to upload merged video: ${uploadError.message}`);
    }

    // Cleanup original segments (best effort)
    const cleanupPromises = segment_paths.map((p: string) =>
      supabase.storage.from(bucket).remove([p]).catch(() => {})
    );
    await Promise.all(cleanupPromises);

    // Get public URL
    const {
      data: { publicUrl },
    } = supabase.storage.from(bucket).getPublicUrl(output_path);

    return jsonResp({
      success: true,
      output_path,
      public_url: publicUrl,
      segments_count: segment_paths.length,
      size_mb: (totalSize / 1024 / 1024).toFixed(1),
      transition_used: transition,
    });
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error('[merge-video-segments] Error:', msg);
    return jsonResp({ success: false, error: msg }, 500);
  }
});
