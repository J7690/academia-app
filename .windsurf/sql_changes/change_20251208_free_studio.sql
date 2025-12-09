-- Studio vidéos libres : overlays + jobs de rendu + RPC
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251208_free_studio.sql

-- 1) Table des overlays pour vidéos libres (miroir de app.challenge_video_overlays)

CREATE TABLE IF NOT EXISTS app.free_video_overlays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    free_video_id UUID NOT NULL REFERENCES app.free_videos (id) ON DELETE CASCADE,
    layers JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (free_video_id)
);

ALTER TABLE app.free_video_overlays ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_free_video_overlays ON app.free_video_overlays;
CREATE POLICY student_select_own_free_video_overlays
ON app.free_video_overlays FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.free_videos fv
    WHERE fv.id = app.free_video_overlays.free_video_id
      AND fv.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS student_upsert_own_free_video_overlays_ins ON app.free_video_overlays;
DROP POLICY IF EXISTS student_upsert_own_free_video_overlays_upd ON app.free_video_overlays;

CREATE POLICY student_upsert_own_free_video_overlays_ins
ON app.free_video_overlays FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.free_videos fv
    WHERE fv.id = app.free_video_overlays.free_video_id
      AND fv.user_id = auth.uid()
  )
);

CREATE POLICY student_upsert_own_free_video_overlays_upd
ON app.free_video_overlays FOR UPDATE
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.free_videos fv
    WHERE fv.id = app.free_video_overlays.free_video_id
      AND fv.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS admin_all_free_video_overlays ON app.free_video_overlays;
CREATE POLICY admin_all_free_video_overlays
ON app.free_video_overlays
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.free_video_overlays TO authenticated;
GRANT ALL ON app.free_video_overlays TO service_role;


-- 2) RPC étudiante : mise à jour des overlays pour une vidéo libre

CREATE OR REPLACE FUNCTION app_student_update_free_video_overlays(
    p_free_video_id UUID,
    p_layers JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_owner_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    -- Réutilise le bannissement challenges comme bannissement global vidéo
    SELECT EXISTS (
        SELECT 1
        FROM app.challenge_user_bans b
        WHERE b.user_id = v_user_id
          AND (b.banned_until IS NULL OR b.banned_until > NOW())
    ) INTO v_is_banned;

    IF v_is_banned THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
    END IF;

    SELECT user_id
    INTO v_owner_id
    FROM app.free_videos
    WHERE id = p_free_video_id
      AND is_active = TRUE;

    IF v_owner_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_found');
    END IF;

    IF v_owner_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    IF p_layers IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_layers');
    END IF;

    INSERT INTO app.free_video_overlays (free_video_id, layers)
    VALUES (p_free_video_id, p_layers)
    ON CONFLICT (free_video_id) DO UPDATE
    SET
        layers = EXCLUDED.layers,
        updated_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_update_free_video_overlays(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_update_free_video_overlays(UUID, JSONB) TO service_role;


-- 3) Table des jobs de rendu pour vidéos libres (miroir de app.challenge_video_render_jobs)

CREATE TABLE IF NOT EXISTS app.free_video_render_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    free_video_id UUID NOT NULL REFERENCES app.free_videos (id) ON DELETE CASCADE,
    job_type TEXT NOT NULL,
    status TEXT NOT NULL,
    source_video_url TEXT,
    result_video_url TEXT,
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

ALTER TABLE app.free_video_render_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_free_video_render_jobs ON app.free_video_render_jobs;
CREATE POLICY student_select_own_free_video_render_jobs
ON app.free_video_render_jobs FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.free_videos fv
    WHERE fv.id = app.free_video_render_jobs.free_video_id
      AND fv.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS admin_all_free_video_render_jobs ON app.free_video_render_jobs;
CREATE POLICY admin_all_free_video_render_jobs
ON app.free_video_render_jobs
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT ON app.free_video_render_jobs TO authenticated;
GRANT ALL ON app.free_video_render_jobs TO service_role;


-- 4) RPC étudiante : lister les jobs de rendu pour une vidéo libre

CREATE OR REPLACE FUNCTION app_student_list_free_video_render_jobs(
    p_free_video_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_owner_id UUID;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    -- Réutilise le bannissement challenges comme bannissement global vidéo
    SELECT EXISTS (
        SELECT 1
        FROM app.challenge_user_bans b
        WHERE b.user_id = v_user_id
          AND (b.banned_until IS NULL OR b.banned_until > NOW())
    ) INTO v_is_banned;

    IF v_is_banned THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
    END IF;

    SELECT user_id
    INTO v_owner_id
    FROM app.free_videos
    WHERE id = p_free_video_id
      AND is_active = TRUE;

    IF v_owner_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_found');
    END IF;

    IF v_owner_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', j.id,
                'free_video_id', j.free_video_id,
                'job_type', j.job_type,
                'status', j.status,
                'source_video_url', j.source_video_url,
                'result_video_url', j.result_video_url,
                'error_message', j.error_message,
                'metadata', j.metadata,
                'created_at', j.created_at,
                'started_at', j.started_at,
                'completed_at', j.completed_at
            )
            ORDER BY j.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.free_video_render_jobs j
    WHERE j.free_video_id = p_free_video_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'jobs', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_free_video_render_jobs(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_free_video_render_jobs(UUID) TO service_role;
