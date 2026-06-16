-- VideoAsset canonical model (schema + RLS + RPC)
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_videoasset_schema.sql

-- 1) TABLES

CREATE TABLE IF NOT EXISTS app.video_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    origin TEXT NOT NULL DEFAULT 'unknown',
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'uploaded', 'processing', 'ready', 'failed', 'deleted')),
    canonical_type TEXT NOT NULL DEFAULT 'video',
    duration_ms INTEGER,
    width INTEGER,
    height INTEGER,
    rotation INTEGER,
    has_audio BOOLEAN NOT NULL DEFAULT TRUE,
    checksum_sha256 TEXT,
    content_warning_flags JSONB,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_video_assets_owner ON app.video_assets(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_video_assets_status ON app.video_assets(status);
CREATE INDEX IF NOT EXISTS idx_video_assets_origin ON app.video_assets(origin);


CREATE TABLE IF NOT EXISTS app.video_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_asset_id UUID NOT NULL REFERENCES app.video_assets(id) ON DELETE CASCADE,
    storage_bucket TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    mime_type TEXT,
    file_size_bytes BIGINT,
    ingest_profile TEXT NOT NULL DEFAULT 'unknown',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ingested_at TIMESTAMPTZ,
    validation_report JSONB
);

CREATE INDEX IF NOT EXISTS idx_video_sources_asset ON app.video_sources(video_asset_id);


CREATE TABLE IF NOT EXISTS app.video_renditions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_asset_id UUID NOT NULL REFERENCES app.video_assets(id) ON DELETE CASCADE,
    rendition_key TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('hls', 'mp4', 'thumbnail', 'poster')),
    width INTEGER,
    height INTEGER,
    bitrate_kbps INTEGER,
    fps INTEGER,
    codec TEXT,
    storage_bucket TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    public_url_hint TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'ready', 'failed')),
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT video_renditions_unique_key UNIQUE (video_asset_id, rendition_key)
);

CREATE INDEX IF NOT EXISTS idx_video_renditions_asset ON app.video_renditions(video_asset_id);
CREATE INDEX IF NOT EXISTS idx_video_renditions_kind ON app.video_renditions(kind);
CREATE INDEX IF NOT EXISTS idx_video_renditions_status ON app.video_renditions(status);


CREATE TABLE IF NOT EXISTS app.video_asset_contexts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_asset_id UUID NOT NULL REFERENCES app.video_assets(id) ON DELETE CASCADE,
    context_type TEXT NOT NULL,
    context_id UUID NOT NULL,
    role TEXT NOT NULL DEFAULT 'primary',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT video_asset_contexts_unique UNIQUE (context_type, context_id, role)
);

CREATE INDEX IF NOT EXISTS idx_video_asset_contexts_asset ON app.video_asset_contexts(video_asset_id);
CREATE INDEX IF NOT EXISTS idx_video_asset_contexts_context ON app.video_asset_contexts(context_type, context_id);


CREATE TABLE IF NOT EXISTS app.video_processing_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_asset_id UUID NOT NULL REFERENCES app.video_assets(id) ON DELETE CASCADE,
    job_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'done', 'failed')),
    attempts INTEGER NOT NULL DEFAULT 0,
    locked_at TIMESTAMPTZ,
    locked_by TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_video_processing_jobs_asset ON app.video_processing_jobs(video_asset_id);
CREATE INDEX IF NOT EXISTS idx_video_processing_jobs_status ON app.video_processing_jobs(status);


-- 2) updated_at triggers

CREATE OR REPLACE FUNCTION app.tg_video_assets_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_video_assets_set_updated_at ON app.video_assets;
CREATE TRIGGER trg_video_assets_set_updated_at
BEFORE UPDATE ON app.video_assets
FOR EACH ROW
EXECUTE FUNCTION app.tg_video_assets_set_updated_at();


CREATE OR REPLACE FUNCTION app.tg_video_processing_jobs_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_video_processing_jobs_set_updated_at ON app.video_processing_jobs;
CREATE TRIGGER trg_video_processing_jobs_set_updated_at
BEFORE UPDATE ON app.video_processing_jobs
FOR EACH ROW
EXECUTE FUNCTION app.tg_video_processing_jobs_set_updated_at();


-- 3) RLS + POLICIES

ALTER TABLE app.video_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.video_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.video_renditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.video_asset_contexts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.video_processing_jobs ENABLE ROW LEVEL SECURITY;

-- video_assets
DROP POLICY IF EXISTS owner_select_video_assets ON app.video_assets;
CREATE POLICY owner_select_video_assets
ON app.video_assets FOR SELECT
USING (owner_user_id = auth.uid());

DROP POLICY IF EXISTS owner_insert_video_assets ON app.video_assets;
CREATE POLICY owner_insert_video_assets
ON app.video_assets FOR INSERT
WITH CHECK (owner_user_id = auth.uid());

DROP POLICY IF EXISTS owner_update_video_assets ON app.video_assets;
CREATE POLICY owner_update_video_assets
ON app.video_assets FOR UPDATE
USING (owner_user_id = auth.uid())
WITH CHECK (owner_user_id = auth.uid());

DROP POLICY IF EXISTS public_select_ready_video_assets ON app.video_assets;
CREATE POLICY public_select_ready_video_assets
ON app.video_assets FOR SELECT
USING (status = 'ready' AND deleted_at IS NULL);

DROP POLICY IF EXISTS service_role_all_video_assets ON app.video_assets;
CREATE POLICY service_role_all_video_assets
ON app.video_assets FOR ALL
TO service_role
USING (TRUE)
WITH CHECK (TRUE);

-- video_sources
DROP POLICY IF EXISTS owner_select_video_sources ON app.video_sources;
CREATE POLICY owner_select_video_sources
ON app.video_sources FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM app.video_assets a
    WHERE a.id = video_sources.video_asset_id
      AND a.owner_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS owner_insert_video_sources ON app.video_sources;
CREATE POLICY owner_insert_video_sources
ON app.video_sources FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM app.video_assets a
    WHERE a.id = video_sources.video_asset_id
      AND a.owner_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS service_role_all_video_sources ON app.video_sources;
CREATE POLICY service_role_all_video_sources
ON app.video_sources FOR ALL
TO service_role
USING (TRUE)
WITH CHECK (TRUE);

-- video_renditions (lecture publique seulement si asset ready)
DROP POLICY IF EXISTS public_select_ready_video_renditions ON app.video_renditions;
CREATE POLICY public_select_ready_video_renditions
ON app.video_renditions FOR SELECT
USING (
  status = 'ready'
  AND EXISTS (
    SELECT 1
    FROM app.video_assets a
    WHERE a.id = video_renditions.video_asset_id
      AND a.status = 'ready'
      AND a.deleted_at IS NULL
  )
);

DROP POLICY IF EXISTS owner_select_video_renditions ON app.video_renditions;
CREATE POLICY owner_select_video_renditions
ON app.video_renditions FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM app.video_assets a
    WHERE a.id = video_renditions.video_asset_id
      AND a.owner_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS service_role_all_video_renditions ON app.video_renditions;
CREATE POLICY service_role_all_video_renditions
ON app.video_renditions FOR ALL
TO service_role
USING (TRUE)
WITH CHECK (TRUE);

-- contexts (owner/admin read; service role all)
DROP POLICY IF EXISTS owner_select_video_asset_contexts ON app.video_asset_contexts;
CREATE POLICY owner_select_video_asset_contexts
ON app.video_asset_contexts FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM app.video_assets a
    WHERE a.id = video_asset_contexts.video_asset_id
      AND a.owner_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS service_role_all_video_asset_contexts ON app.video_asset_contexts;
CREATE POLICY service_role_all_video_asset_contexts
ON app.video_asset_contexts FOR ALL
TO service_role
USING (TRUE)
WITH CHECK (TRUE);

-- processing jobs (service role only)
DROP POLICY IF EXISTS service_role_all_video_processing_jobs ON app.video_processing_jobs;
CREATE POLICY service_role_all_video_processing_jobs
ON app.video_processing_jobs FOR ALL
TO service_role
USING (TRUE)
WITH CHECK (TRUE);


-- 4) GRANTS

GRANT SELECT, INSERT, UPDATE ON app.video_assets TO authenticated;
GRANT SELECT ON app.video_assets TO anon;
GRANT ALL ON app.video_assets TO service_role;

GRANT SELECT, INSERT ON app.video_sources TO authenticated;
GRANT ALL ON app.video_sources TO service_role;

GRANT SELECT ON app.video_renditions TO anon, authenticated;
GRANT ALL ON app.video_renditions TO service_role;

GRANT SELECT ON app.video_asset_contexts TO authenticated;
GRANT ALL ON app.video_asset_contexts TO service_role;

GRANT ALL ON app.video_processing_jobs TO service_role;


-- 5) RPC

CREATE OR REPLACE FUNCTION app_videoasset_create_upload_intent(
  p_origin TEXT,
  p_context_type TEXT,
  p_context_id UUID,
  p_role TEXT DEFAULT 'primary',
  p_mime_type TEXT DEFAULT NULL,
  p_expected_size BIGINT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_asset_id UUID;
  v_source_id UUID;
  v_bucket TEXT := 'video-assets';
  v_path TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  INSERT INTO app.video_assets (owner_user_id, origin, status)
  VALUES (v_user_id, COALESCE(NULLIF(TRIM(p_origin), ''), 'unknown'), 'draft')
  RETURNING id INTO v_asset_id;

  IF p_context_type IS NOT NULL AND p_context_id IS NOT NULL THEN
    INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
    VALUES (
      v_asset_id,
      TRIM(p_context_type),
      p_context_id,
      COALESCE(NULLIF(TRIM(p_role), ''), 'primary')
    )
    ON CONFLICT (context_type, context_id, role) DO UPDATE
      SET video_asset_id = EXCLUDED.video_asset_id;
  END IF;

  v_path := 'raw/' || v_asset_id::TEXT || '/' || gen_random_uuid()::TEXT;

  INSERT INTO app.video_sources (
    video_asset_id,
    storage_bucket,
    storage_path,
    mime_type,
    file_size_bytes,
    ingest_profile
  ) VALUES (
    v_asset_id,
    v_bucket,
    v_path,
    p_mime_type,
    p_expected_size,
    'mobile_capture'
  )
  RETURNING id INTO v_source_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'video_asset_id', v_asset_id,
    'source_id', v_source_id,
    'storage_bucket', v_bucket,
    'storage_path', v_path
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_videoasset_create_upload_intent(TEXT, TEXT, UUID, TEXT, TEXT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_videoasset_create_upload_intent(TEXT, TEXT, UUID, TEXT, TEXT, BIGINT) TO service_role;


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

  INSERT INTO app.video_processing_jobs (video_asset_id, job_type, status, payload)
  VALUES
    (v_asset_id, 'extract_metadata', 'queued', '{}'::JSONB),
    (v_asset_id, 'generate_hls', 'queued', '{}'::JSONB),
    (v_asset_id, 'generate_thumbs', 'queued', '{}'::JSONB);


  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_asset_id', v_asset_id, 'status', 'uploaded');
END;
$$;

GRANT EXECUTE ON FUNCTION app_videoasset_register_uploaded_source(UUID, TEXT, INTEGER, INTEGER, INTEGER, BOOLEAN, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION app_videoasset_register_uploaded_source(UUID, TEXT, INTEGER, INTEGER, INTEGER, BOOLEAN, JSONB) TO service_role;


CREATE OR REPLACE FUNCTION app_videoasset_get_playback_manifest(
  p_video_asset_id UUID,
  p_client_capabilities JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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

GRANT EXECUTE ON FUNCTION app_videoasset_get_playback_manifest(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_videoasset_get_playback_manifest(UUID, JSONB) TO service_role;
