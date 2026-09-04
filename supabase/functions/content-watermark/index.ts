// Academia — content-watermark
// Applique un filigrane « Nexiom Group · <code ref> » sur les images de la
// mediatheque, cote serveur (non contournable). Fail-closed : si le filigrane
// ne peut pas etre applique, on refuse (protege les visuels partenaires).
//
// Videos : le burn-in ffmpeg est delegue au worker externe (non traite ici).

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { Image } from 'https://deno.land/x/imagescript@1.2.17/mod.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const FONT_URL = 'https://cdn.jsdelivr.net/gh/google/fonts/apache/roboto/static/Roboto-Bold.ttf';

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept,x-client-info',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

let fontCache: Uint8Array | null = null;
async function getFont(): Promise<Uint8Array> {
  if (fontCache) return fontCache;
  const r = await fetch(FONT_URL);
  if (!r.ok) throw new Error('font_fetch_failed');
  fontCache = new Uint8Array(await r.arrayBuffer());
  return fontCache;
}

function j(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return j({ error: 'method_not_allowed' }, 405);
  if (!SUPABASE_URL || !SERVICE_ROLE) return j({ error: 'server_misconfigured' }, 500);

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return j({ error: 'unauthorized' }, 401);

  let assetId: string; let action = 'download';
  try {
    const b = await req.json();
    assetId = b.asset_id;
    if (b.action) action = String(b.action);
    if (!assetId) return j({ error: 'asset_id_required' }, 400);
  } catch {
    return j({ error: 'invalid_json' }, 400);
  }

  // 1) Verifier les droits AU NOM DE L'UTILISATEUR (RPC SECURITY DEFINER).
  const asUser = createClient(SUPABASE_URL, SERVICE_ROLE, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: ent, error: entErr } = await asUser
    .schema('app')
    .rpc('app_prepare_watermarked_asset', { p_asset: assetId, p_action: action });
  if (entErr) return j({ error: 'entitlement_failed', detail: String(entErr) }, 500);
  if (!ent || ent.allowed !== true) return j({ error: ent?.error ?? 'forbidden' }, 403);

  const assetType = String(ent.asset_type ?? 'image');
  const watermark = String(ent.watermark ?? 'Nexiom Group');
  const storagePath = ent.storage_path as string | null;

  // 2) Video : non traite ici (delegue au worker ffmpeg externe).
  if (assetType === 'video') {
    return j({ error: 'video_watermark_delegated', message: 'Le filigrane video est traite par le worker externe.' }, 501);
  }

  if (!storagePath) return j({ error: 'no_storage_path' }, 422);

  // 3) Telecharger l'original depuis le bucket prive (service role).
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);
  const dl = await admin.storage.from('partner-media').download(storagePath);
  if (dl.error || !dl.data) return j({ error: 'download_failed', detail: String(dl.error) }, 404);
  const srcBytes = new Uint8Array(await dl.data.arrayBuffer());

  // 4) Appliquer le filigrane (fail-closed).
  try {
    const img = await Image.decode(srcBytes);
    const font = await getFont();
    const scale = Math.max(14, Math.round(img.width / 28));
    const label = await Image.renderText(font, scale, watermark, 0xffffffcc);
    const shadow = await Image.renderText(font, scale, watermark, 0x00000099);
    const x = Math.max(6, img.width - label.width - 16);
    const y = Math.max(6, img.height - label.height - 14);
    img.composite(shadow, x + 1, y + 1);
    img.composite(label, x, y);
    // Bandeau diagonal discret repete pour dissuader le recadrage.
    const tile = await Image.renderText(font, Math.round(scale * 0.9), watermark, 0xffffff22);
    for (let ty = 0; ty < img.height; ty += tile.height * 3) {
      for (let tx = 0; tx < img.width; tx += tile.width + 40) {
        img.composite(tile, tx, ty);
      }
    }
    const out = await img.encodeJPEG(85);
    return new Response(out, {
      status: 200,
      headers: { ...CORS, 'Content-Type': 'image/jpeg', 'Cache-Control': 'private, max-age=60' },
    });
  } catch (e) {
    // Fail-closed : pas de filigrane => pas de fichier.
    return j({ error: 'watermark_failed', detail: String(e) }, 500);
  }
});
