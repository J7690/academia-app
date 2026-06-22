// Supabase Edge Function: cleanup-expired-upload-sessions
// Automatically marks expired upload sessions as 'expired'
// Can be called via cron job or manually

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
    console.error('[cleanup-expired-upload-sessions] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return jsonResponse({ success: false, error: 'Server misconfigured' }, 500);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    console.log('[cleanup-expired-upload-sessions] Starting cleanup...');

    // Mark expired sessions as 'expired'
    const { data, error } = await supabase
      .from('upload_sessions')
      .update({ status: 'expired' })
      .in('status', ['initialized', 'uploading'])
      .lt('expires_at', new Date().toISOString())
      .select();

    if (error) {
      console.error('[cleanup-expired-upload-sessions] Update error:', error);
      return jsonResponse({ success: false, error: error.message }, 500);
    }

    const expiredCount = data?.length ?? 0;
    console.log(`[cleanup-expired-upload-sessions] Expired ${expiredCount} sessions`);

    return jsonResponse({
      success: true,
      expired_count: expiredCount,
      message: `Successfully expired ${expiredCount} upload sessions`,
    });
  } catch (e) {
    console.error('[cleanup-expired-upload-sessions] Unexpected error:', e);
    return jsonResponse({ success: false, error: String(e) }, 500);
  }
});
