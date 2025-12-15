-- Étape 8 : Worker + processing pipeline VideoAsset (idempotent)
-- AUCUN drop legacy, aucun nettoyage storage, aucune réécriture destructive de policies.
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_step8_videoasset_worker.sql

-- 1) Bucket storage dédié VideoAsset (raw + renditions)
INSERT INTO storage.buckets (id, name, public)
VALUES ('video-assets', 'video-assets', TRUE)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;


-- 2) Helpers SQL (service_role) : enqueue / claim / complete

CREATE OR REPLACE FUNCTION app_videoasset_enqueue_processing(
  p_video_asset_id UUID,
  p_job_types TEXT[] DEFAULT ARRAY['extract_metadata','generate_mp4','generate_thumbs']
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inserted INTEGER := 0;
  v_jt TEXT;
BEGIN
  IF p_video_asset_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_video_asset_id');
  END IF;

  FOREACH v_jt IN ARRAY COALESCE(p_job_types, ARRAY[]::TEXT[]) LOOP
    v_jt := NULLIF(TRIM(v_jt), '');
    IF v_jt IS NULL THEN
      CONTINUE;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM app.video_processing_jobs j
      WHERE j.video_asset_id = p_video_asset_id
        AND j.job_type = v_jt
        AND j.status IN ('queued','running')
    ) THEN
      INSERT INTO app.video_processing_jobs (video_asset_id, job_type, status, payload)
      VALUES (p_video_asset_id, v_jt, 'queued', '{}'::JSONB);
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'inserted', v_inserted);
END;
$$;

GRANT EXECUTE ON FUNCTION app_videoasset_enqueue_processing(UUID, TEXT[]) TO service_role;


CREATE OR REPLACE FUNCTION app_videoasset_claim_next_job(
  p_locked_by TEXT,
  p_job_types TEXT[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job app.video_processing_jobs%ROWTYPE;
  v_asset app.video_assets%ROWTYPE;
  v_source app.video_sources%ROWTYPE;
  v_input_url TEXT;
  v_source_bucket TEXT;
  v_source_path TEXT;
BEGIN
  -- Claim one queued job, concurrency-safe
  SELECT * INTO v_job
  FROM app.video_processing_jobs j
  WHERE j.status = 'queued'
    AND (p_job_types IS NULL OR j.job_type = ANY(p_job_types))
  ORDER BY j.created_at ASC
  FOR UPDATE SKIP LOCKED
  LIMIT 1;

  IF v_job.id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'job', NULL);
  END IF;

  UPDATE app.video_processing_jobs
  SET status = 'running',
      attempts = attempts + 1,
      locked_at = NOW(),
      locked_by = NULLIF(TRIM(COALESCE(p_locked_by, '')), ''),
      error = NULL
  WHERE id = v_job.id
  RETURNING * INTO v_job;

  SELECT * INTO v_asset
  FROM app.video_assets a
  WHERE a.id = v_job.video_asset_id;

  -- Choose a source (latest ingested)
  SELECT * INTO v_source
  FROM app.video_sources s
  WHERE s.video_asset_id = v_job.video_asset_id
  ORDER BY COALESCE(s.ingested_at, s.created_at) DESC
  LIMIT 1;

  IF v_source.id IS NOT NULL THEN
    v_source_bucket := v_source.storage_bucket;
    v_source_path := v_source.storage_path;
  END IF;

  -- Fallback: best ready mp4 rendition
  IF v_input_url IS NULL THEN
    SELECT r.public_url_hint
    INTO v_input_url
    FROM app.video_renditions r
    WHERE r.video_asset_id = v_job.video_asset_id
      AND r.status = 'ready'
      AND r.kind = 'mp4'
    ORDER BY COALESCE(r.width, 0) DESC
    LIMIT 1;
  END IF;

  -- We can proceed if we have either a source bucket/path OR a fallback URL.
  IF (v_input_url IS NULL)
     AND (v_source_bucket IS NULL OR v_source_path IS NULL) THEN
    UPDATE app.video_processing_jobs
    SET status = 'failed',
        error = 'no_source_url'
    WHERE id = v_job.id;

    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_source_url');
  END IF;

  UPDATE app.video_assets
  SET status = CASE WHEN status IN ('draft','uploaded') THEN 'processing' ELSE status END
  WHERE id = v_job.video_asset_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'job', JSONB_BUILD_OBJECT(
      'id', v_job.id,
      'video_asset_id', v_job.video_asset_id,
      'job_type', v_job.job_type,
      'attempts', v_job.attempts,
      'locked_at', v_job.locked_at,
      'locked_by', v_job.locked_by,
      'payload', v_job.payload
    ),
    'input_url', v_input_url,
    'source', JSONB_BUILD_OBJECT(
      'storage_bucket', v_source_bucket,
      'storage_path', v_source_path
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_videoasset_claim_next_job(TEXT, TEXT[]) TO service_role;


CREATE OR REPLACE FUNCTION app_videoasset_complete_job(
  p_job_id UUID,
  p_status TEXT,
  p_error TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job app.video_processing_jobs%ROWTYPE;
  v_has_ready BOOLEAN;
  v_has_pending BOOLEAN;
BEGIN
  IF p_job_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_job_id');
  END IF;

  SELECT * INTO v_job
  FROM app.video_processing_jobs j
  WHERE j.id = p_job_id;

  IF v_job.id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'job_not_found');
  END IF;

  UPDATE app.video_processing_jobs
  SET status = CASE WHEN LOWER(p_status) IN ('done','failed') THEN LOWER(p_status) ELSE status END,
      error = CASE WHEN LOWER(p_status) = 'failed' THEN NULLIF(TRIM(COALESCE(p_error, '')), '') ELSE NULL END
  WHERE id = p_job_id
  RETURNING * INTO v_job;

  -- Mark asset ready if no more queued/running jobs and at least one ready mp4 exists
  SELECT EXISTS (
    SELECT 1
    FROM app.video_renditions r
    WHERE r.video_asset_id = v_job.video_asset_id
      AND r.status = 'ready'
      AND r.kind = 'mp4'
  ) INTO v_has_ready;

  SELECT EXISTS (
    SELECT 1
    FROM app.video_processing_jobs j
    WHERE j.video_asset_id = v_job.video_asset_id
      AND j.status IN ('queued','running')
  ) INTO v_has_pending;

  IF v_has_ready AND (NOT v_has_pending) THEN
    UPDATE app.video_assets
    SET status = 'ready'
    WHERE id = v_job.video_asset_id;
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_videoasset_complete_job(UUID, TEXT, TEXT) TO service_role;
