-- Runtime audit: execute playback manifest RPC on a real ready asset

-- 1) Pick a ready asset id
WITH picked AS (
  SELECT id
  FROM app.video_assets
  WHERE status = 'ready'
    AND deleted_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1
)
SELECT id AS picked_video_asset_id FROM picked;

-- 2) Call the deployed RPC (public schema) with the picked id
WITH picked AS (
  SELECT id
  FROM app.video_assets
  WHERE status = 'ready'
    AND deleted_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1
)
SELECT public.app_videoasset_get_playback_manifest((SELECT id FROM picked)) AS manifest;

-- 3) Also test app_videoasset_get_playback_for_direct_url using an existing rendition public_url_hint
WITH picked_url AS (
  SELECT r.public_url_hint
  FROM app.video_renditions r
  JOIN app.video_assets a ON a.id = r.video_asset_id
  WHERE a.status = 'ready'
    AND a.deleted_at IS NULL
    AND r.status = 'ready'
    AND NULLIF(TRIM(COALESCE(r.public_url_hint,'')), '') IS NOT NULL
  ORDER BY r.created_at DESC
  LIMIT 1
)
SELECT public.app_videoasset_get_playback_for_direct_url((SELECT public_url_hint FROM picked_url)) AS manifest;
