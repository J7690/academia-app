-- VideoAsset helper: resolve playback manifest from a direct public URL
-- This RPC is used by the mobile client (StudentChallengesProvider.fetchPlaybackForDirectUrl)
-- to turn a storage / CDN URL into a canonical playback manifest based on VideoAssets.

CREATE OR REPLACE FUNCTION public.app_videoasset_get_playback_for_direct_url(
  p_direct_url TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_url            TEXT;
  v_video_asset_id UUID;
  v_manifest       JSONB;
BEGIN
  -- Require an authenticated user (student context)
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  v_url := TRIM(COALESCE(p_direct_url, ''));
  IF v_url = '' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_direct_url');
  END IF;

  -- Resolve the VideoAsset behind this direct URL via the rendition public_url_hint
  SELECT r.video_asset_id
  INTO v_video_asset_id
  FROM app.video_renditions r
  WHERE r.public_url_hint = v_url
    AND r.status = 'ready'
  ORDER BY COALESCE(r.width, 0) DESC
  LIMIT 1;

  IF v_video_asset_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'rendition_not_found');
  END IF;

  -- Delegate to the canonical manifest builder
  v_manifest := app_videoasset_get_playback_manifest(v_video_asset_id, '{}'::JSONB);

  IF COALESCE(v_manifest->>'success', 'false') <> 'true' THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'error', COALESCE(v_manifest->>'error', 'playback_manifest_failed')
    );
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'manifest', JSONB_BUILD_OBJECT(
      'video_asset_id', v_video_asset_id,
      'playback', JSONB_BUILD_OBJECT(
        'best_url',   v_manifest->>'best_url',
        'poster_url', v_manifest->>'poster_url',
        'renditions', v_manifest->'renditions'
      )
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_videoasset_get_playback_for_direct_url(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_videoasset_get_playback_for_direct_url(TEXT) TO service_role;
