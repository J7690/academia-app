-- ============================================================
-- RPC: app_videoasset_get_playback_manifest
-- Returns a playback manifest for a given video_asset_id.
-- Looks up the video_asset and its renditions, returning
-- the best URL (preferring 'original' label) and all renditions.
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_videoasset_get_playback_manifest(
  p_video_asset_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_asset RECORD;
  v_renditions JSONB;
  v_best_url TEXT;
  v_poster_url TEXT;
BEGIN
  -- 1. Fetch the video_asset
  SELECT id, status, poster_url
    INTO v_asset
    FROM video_assets
   WHERE id = p_video_asset_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'video_asset not found'
    );
  END IF;

  v_poster_url := v_asset.poster_url;

  -- 2. Fetch all ready renditions
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'label', r.label,
      'url', r.public_url_hint,
      'mime_type', r.mime_type,
      'width', r.width,
      'height', r.height,
      'bitrate_kbps', r.bitrate_kbps
    ) ORDER BY
      CASE WHEN r.label = 'original' THEN 0 ELSE 1 END,
      r.created_at ASC
  ), '[]'::jsonb)
    INTO v_renditions
    FROM video_renditions r
   WHERE r.video_asset_id = p_video_asset_id
     AND r.is_ready = true;

  -- 3. Pick best URL (first rendition)
  IF jsonb_array_length(v_renditions) > 0 THEN
    v_best_url := v_renditions->0->>'url';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'manifest', jsonb_build_object(
      'video_asset_id', p_video_asset_id,
      'status', v_asset.status,
      'best_url', COALESCE(v_best_url, ''),
      'poster_url', v_poster_url,
      'renditions', v_renditions
    )
  );
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.app_videoasset_get_playback_manifest(UUID) TO authenticated;
