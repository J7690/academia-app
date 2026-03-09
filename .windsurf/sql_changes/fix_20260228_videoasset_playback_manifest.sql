-- Fix: VideoAsset playback manifest RPC points to non-existent public tables.
-- This replaces the broken public.app_videoasset_get_playback_manifest(uuid)
-- with an implementation backed by app.video_assets + app.video_renditions.
-- Also adds a compatibility overload (uuid, jsonb) expected by app_videoasset_get_playback_for_direct_url.

CREATE OR REPLACE FUNCTION public.app_videoasset_get_playback_manifest(
  p_video_asset_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public
AS $$
DECLARE
  v_asset app.video_assets%ROWTYPE;
  v_best_hls JSONB;
  v_best_mp4 JSONB;
  v_poster JSONB;
  v_renditions JSONB;
  v_best_url TEXT;
  v_poster_url TEXT;
BEGIN
  SELECT * INTO v_asset
  FROM app.video_assets a
  WHERE a.id = p_video_asset_id
    AND a.deleted_at IS NULL;

  IF v_asset.id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_found');
  END IF;

  -- Prefer HLS, then MP4
  SELECT TO_JSONB(r) INTO v_best_hls
  FROM app.video_renditions r
  WHERE r.video_asset_id = p_video_asset_id
    AND r.status = 'ready'
    AND r.kind = 'hls'
  ORDER BY COALESCE(r.width, 0) DESC
  LIMIT 1;

  SELECT TO_JSONB(r) INTO v_best_mp4
  FROM app.video_renditions r
  WHERE r.video_asset_id = p_video_asset_id
    AND r.status = 'ready'
    AND r.kind = 'mp4'
  ORDER BY COALESCE(r.width, 0) DESC
  LIMIT 1;

  SELECT TO_JSONB(r) INTO v_poster
  FROM app.video_renditions r
  WHERE r.video_asset_id = p_video_asset_id
    AND r.status = 'ready'
    AND r.kind IN ('poster', 'thumbnail')
  ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
  LIMIT 1;

  v_best_url := COALESCE(
    (v_best_hls->>'public_url_hint'),
    (v_best_mp4->>'public_url_hint')
  );

  v_poster_url := COALESCE(v_poster->>'public_url_hint', NULL);

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', r.id,
        'rendition_key', r.rendition_key,
        'kind', r.kind,
        'width', r.width,
        'height', r.height,
        'bitrate_kbps', r.bitrate_kbps,
        'fps', r.fps,
        'codec', r.codec,
        'url', r.public_url_hint,
        'status', r.status
      )
      ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
    ),
    '[]'::JSONB
  ) INTO v_renditions
  FROM app.video_renditions r
  WHERE r.video_asset_id = p_video_asset_id
    AND r.status = 'ready';

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'video_asset', JSONB_BUILD_OBJECT(
      'id', v_asset.id,
      'origin', v_asset.origin,
      'status', v_asset.status,
      'duration_ms', v_asset.duration_ms,
      'width', v_asset.width,
      'height', v_asset.height,
      'has_audio', v_asset.has_audio
    ),
    'best_url', v_best_url,
    'poster_url', v_poster_url,
    'renditions', v_renditions
  );
END;
$$;

-- Compatibility overload used by app_videoasset_get_playback_for_direct_url
CREATE OR REPLACE FUNCTION public.app_videoasset_get_playback_manifest(
  p_video_asset_id UUID,
  p_client_capabilities JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public
AS $$
BEGIN
  RETURN public.app_videoasset_get_playback_manifest(p_video_asset_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_videoasset_get_playback_manifest(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_videoasset_get_playback_manifest(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.app_videoasset_get_playback_manifest(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_videoasset_get_playback_manifest(UUID, JSONB) TO service_role;
