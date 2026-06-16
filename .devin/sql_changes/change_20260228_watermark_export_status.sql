-- Phase 2 watermark: polling/status RPC for export_watermarked

CREATE OR REPLACE FUNCTION public.app_student_get_video_export_watermarked_status(
  p_video_asset_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_owner BOOLEAN := FALSE;
  v_allow_download BOOLEAN := FALSE;
  v_existing_url TEXT;
  v_job_status TEXT;
  v_job_error TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  IF p_video_asset_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_asset_id_required');
  END IF;

  -- Resolve permissions from challenge/free records (same logic as request RPC).
  SELECT TRUE, cp.allow_download
  INTO v_is_owner, v_allow_download
  FROM app.challenge_participations cp
  WHERE cp.video_asset_id = p_video_asset_id
    AND cp.is_active = TRUE
    AND cp.is_deleted = FALSE
    AND cp.user_id = v_user_id
  LIMIT 1;

  IF NOT v_is_owner THEN
    SELECT COALESCE(cp.allow_download, FALSE)
    INTO v_allow_download
    FROM app.challenge_participations cp
    WHERE cp.video_asset_id = p_video_asset_id
      AND cp.is_active = TRUE
      AND cp.is_deleted = FALSE
    LIMIT 1;
  END IF;

  IF NOT v_is_owner AND NOT v_allow_download THEN
    SELECT TRUE, fv.allow_download
    INTO v_is_owner, v_allow_download
    FROM app.free_videos fv
    WHERE fv.video_asset_id = p_video_asset_id
      AND fv.is_active = TRUE
      AND fv.is_deleted = FALSE
      AND fv.user_id = v_user_id
    LIMIT 1;

    IF NOT v_is_owner THEN
      SELECT COALESCE(fv.allow_download, FALSE)
      INTO v_allow_download
      FROM app.free_videos fv
      WHERE fv.video_asset_id = p_video_asset_id
        AND fv.is_active = TRUE
        AND fv.is_deleted = FALSE
      LIMIT 1;
    END IF;
  END IF;

  IF NOT v_is_owner AND NOT v_allow_download THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'download_not_allowed');
  END IF;

  -- If rendition already ready, return it.
  SELECT vr.public_url_hint
  INTO v_existing_url
  FROM app.video_renditions vr
  WHERE vr.video_asset_id = p_video_asset_id
    AND vr.rendition_key = 'export_watermarked'
    AND vr.kind = 'mp4'
    AND vr.status = 'ready'
  ORDER BY vr.created_at DESC
  LIMIT 1;

  IF v_existing_url IS NOT NULL AND LENGTH(TRIM(v_existing_url)) > 0 THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'status', 'ready',
      'url', v_existing_url
    );
  END IF;

  -- Look for latest job.
  SELECT j.status, j.error
  INTO v_job_status, v_job_error
  FROM app.video_processing_jobs j
  WHERE j.video_asset_id = p_video_asset_id
    AND j.job_type = 'export_watermarked'
  ORDER BY j.created_at DESC
  LIMIT 1;

  IF v_job_status IS NULL OR LENGTH(TRIM(v_job_status)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'status', 'not_requested');
  END IF;

  IF v_job_status = 'failed' THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'status', 'failed',
      'error', COALESCE(v_job_error, 'job_failed')
    );
  END IF;

  IF v_job_status IN ('queued', 'running') THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'status', v_job_status);
  END IF;

  IF v_job_status = 'done' THEN
    -- Job finished but rendition not visible as ready yet.
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'status', 'processing');
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'status', 'unknown');
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_get_video_export_watermarked_status(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_get_video_export_watermarked_status(UUID) TO service_role;
