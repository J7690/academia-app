-- Fix A7: align VideoAsset register function with step8 worker
-- - Ensure new uploads enqueue a 'generate_mp4' job (not the deprecated 'generate_hls')
-- - Keep 'extract_metadata' and 'generate_thumbs' as before

CREATE OR REPLACE FUNCTION app_videoasset_register_uploaded_source(
  p_source_id UUID,
  p_checksum_sha256 TEXT DEFAULT NULL,
  p_width INTEGER DEFAULT NULL,
  p_height INTEGER DEFAULT NULL,
  p_duration_ms INTEGER DEFAULT NULL,
  p_has_audio BOOLEAN DEFAULT NULL,
  p_validation_report JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_asset_id UUID;
  v_owner UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT s.video_asset_id, a.owner_user_id
  INTO v_asset_id, v_owner
  FROM app.video_sources s
  JOIN app.video_assets a ON a.id = s.video_asset_id
  WHERE s.id = p_source_id;

  IF v_asset_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'source_not_found');
  END IF;

  IF v_owner IS DISTINCT FROM v_user_id THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  UPDATE app.video_sources
  SET ingested_at = NOW(),
      validation_report = COALESCE(p_validation_report, validation_report)
  WHERE id = p_source_id;

  UPDATE app.video_assets
  SET status = 'uploaded',
      checksum_sha256 = COALESCE(NULLIF(TRIM(p_checksum_sha256), ''), checksum_sha256),
      width = COALESCE(p_width, width),
      height = COALESCE(p_height, height),
      duration_ms = COALESCE(p_duration_ms, duration_ms),
      has_audio = COALESCE(p_has_audio, has_audio)
  WHERE id = v_asset_id;

  -- Enqueue default processing jobs compatible avec le worker step8
  INSERT INTO app.video_processing_jobs (video_asset_id, job_type, status, payload)
  VALUES
    (v_asset_id, 'extract_metadata', 'queued', '{}'::JSONB),
    (v_asset_id, 'generate_mp4',     'queued', '{}'::JSONB),
    (v_asset_id, 'generate_thumbs',  'queued', '{}'::JSONB);

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_asset_id', v_asset_id, 'status', 'uploaded');
END;
$$;

GRANT EXECUTE ON FUNCTION app_videoasset_register_uploaded_source(
  UUID, TEXT, INTEGER, INTEGER, INTEGER, BOOLEAN, JSONB
) TO authenticated;
GRANT EXECUTE ON FUNCTION app_videoasset_register_uploaded_source(
  UUID, TEXT, INTEGER, INTEGER, INTEGER, BOOLEAN, JSONB
) TO service_role;
