-- VideoAsset backfill phase 1: add video_asset_id + map legacy URLs into app.video_assets
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_videoasset_backfill_phase1.sql

-- 0) Mapping table to make backfill idempotent (no orphan video_assets on re-run)

CREATE TABLE IF NOT EXISTS app.video_asset_legacy_map (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    context_type TEXT NOT NULL,
    context_id UUID NOT NULL,
    role TEXT NOT NULL DEFAULT 'primary',
    video_asset_id UUID NOT NULL REFERENCES app.video_assets(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT video_asset_legacy_map_unique UNIQUE (context_type, context_id, role)
);

CREATE INDEX IF NOT EXISTS idx_video_asset_legacy_map_asset ON app.video_asset_legacy_map(video_asset_id);
CREATE INDEX IF NOT EXISTS idx_video_asset_legacy_map_ctx ON app.video_asset_legacy_map(context_type, context_id);

ALTER TABLE app.video_asset_legacy_map ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS service_role_all_video_asset_legacy_map ON app.video_asset_legacy_map;
CREATE POLICY service_role_all_video_asset_legacy_map
ON app.video_asset_legacy_map
FOR ALL
TO service_role
USING (TRUE)
WITH CHECK (TRUE);

GRANT ALL ON app.video_asset_legacy_map TO service_role;


-- 1) Add video_asset_id columns to legacy tables (nullable for now)

ALTER TABLE app.challenge_participations
  ADD COLUMN IF NOT EXISTS video_asset_id UUID REFERENCES app.video_assets(id);
CREATE INDEX IF NOT EXISTS idx_challenge_participations_video_asset_id
  ON app.challenge_participations(video_asset_id);

ALTER TABLE app.challenge_participation_videos
  ADD COLUMN IF NOT EXISTS video_asset_id UUID REFERENCES app.video_assets(id);
CREATE INDEX IF NOT EXISTS idx_challenge_participation_videos_video_asset_id
  ON app.challenge_participation_videos(video_asset_id);

ALTER TABLE app.free_videos
  ADD COLUMN IF NOT EXISTS video_asset_id UUID REFERENCES app.video_assets(id);
CREATE INDEX IF NOT EXISTS idx_free_videos_video_asset_id
  ON app.free_videos(video_asset_id);

ALTER TABLE app.landing_videos
  ADD COLUMN IF NOT EXISTS video_asset_id UUID REFERENCES app.video_assets(id);
CREATE INDEX IF NOT EXISTS idx_landing_videos_video_asset_id
  ON app.landing_videos(video_asset_id);

ALTER TABLE app.landing_config
  ADD COLUMN IF NOT EXISTS video_asset_id UUID REFERENCES app.video_assets(id);
CREATE INDEX IF NOT EXISTS idx_landing_config_video_asset_id
  ON app.landing_config(video_asset_id);

ALTER TABLE app.student_home_videos
  ADD COLUMN IF NOT EXISTS video_asset_id UUID REFERENCES app.video_assets(id);
CREATE INDEX IF NOT EXISTS idx_student_home_videos_video_asset_id
  ON app.student_home_videos(video_asset_id);

ALTER TABLE app.hero_playlist
  ADD COLUMN IF NOT EXISTS video_asset_id UUID REFERENCES app.video_assets(id);
CREATE INDEX IF NOT EXISTS idx_hero_playlist_video_asset_id
  ON app.hero_playlist(video_asset_id);

ALTER TABLE app.university_media
  ADD COLUMN IF NOT EXISTS video_asset_id UUID REFERENCES app.video_assets(id);
CREATE INDEX IF NOT EXISTS idx_university_media_video_asset_id
  ON app.university_media(video_asset_id);

ALTER TABLE app.online_course_live_sessions
  ADD COLUMN IF NOT EXISTS replay_video_asset_id UUID REFERENCES app.video_assets(id);
CREATE INDEX IF NOT EXISTS idx_online_course_live_sessions_replay_video_asset_id
  ON app.online_course_live_sessions(replay_video_asset_id);


-- 2) Backfill mappings + assets + contexts + renditions

-- 2.1 challenge_participations (video_url / submission_url)
WITH candidates AS (
  SELECT
    cp.id AS context_id,
    'challenge_participation'::text AS context_type,
    'primary'::text AS role,
    cp.user_id AS owner_user_id,
    COALESCE(NULLIF(TRIM(cp.video_url),''), NULLIF(TRIM(cp.submission_url),'')) AS url,
    NULLIF(TRIM(cp.thumbnail_url), '') AS thumb_url
  FROM app.challenge_participations cp
  WHERE cp.video_asset_id IS NULL
    AND COALESCE(NULLIF(TRIM(cp.video_url),''), NULLIF(TRIM(cp.submission_url),'')) IS NOT NULL
),
existing_map AS (
  SELECT m.context_type, m.context_id, m.role, m.video_asset_id
  FROM app.video_asset_legacy_map m
  JOIN candidates c
    ON c.context_type = m.context_type AND c.context_id = m.context_id AND c.role = m.role
),
new_ids AS (
  SELECT c.context_type, c.context_id, c.role, gen_random_uuid() AS video_asset_id
  FROM candidates c
  LEFT JOIN app.video_asset_legacy_map m
    ON m.context_type = c.context_type AND m.context_id = c.context_id AND m.role = c.role
  WHERE m.video_asset_id IS NULL
),
ins_assets AS (
  INSERT INTO app.video_assets (id, owner_user_id, origin, status)
  SELECT n.video_asset_id, c.owner_user_id, 'challenge_submission', 'ready'
  FROM new_ids n
  JOIN candidates c ON c.context_id = n.context_id
  WHERE NOT EXISTS (SELECT 1 FROM app.video_assets a WHERE a.id = n.video_asset_id)
),
ins_map AS (
  INSERT INTO app.video_asset_legacy_map (context_type, context_id, role, video_asset_id)
  SELECT n.context_type, n.context_id, n.role, n.video_asset_id
  FROM new_ids n
  ON CONFLICT (context_type, context_id, role) DO NOTHING
),
all_map AS (
  SELECT * FROM existing_map
  UNION ALL
  SELECT * FROM new_ids
),
ins_ctx AS (
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  SELECT am.video_asset_id, am.context_type, am.context_id, am.role
  FROM all_map am
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id
),
ins_rend AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_primary',
    'mp4',
    'legacy',
    'legacy/external',
    c.url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
),
ins_thumb AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_poster',
    'poster',
    'legacy',
    'legacy/external',
    c.thumb_url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  WHERE c.thumb_url IS NOT NULL
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
)
UPDATE app.challenge_participations cp
SET video_asset_id = am.video_asset_id
FROM all_map am
WHERE cp.id = am.context_id
  AND cp.video_asset_id IS NULL;


-- 2.2 challenge_participation_videos (always video_url)
WITH candidates AS (
  SELECT
    pv.id AS context_id,
    'challenge_participation_video'::text AS context_type,
    'primary'::text AS role,
    NULL::uuid AS owner_user_id,
    COALESCE(NULLIF(TRIM(pv.video_url),''), NULL) AS url,
    NULLIF(TRIM(pv.thumbnail_url), '') AS thumb_url
  FROM app.challenge_participation_videos pv
  WHERE pv.video_asset_id IS NULL
    AND COALESCE(NULLIF(TRIM(pv.video_url),''), NULL) IS NOT NULL
),
existing_map AS (
  SELECT m.context_type, m.context_id, m.role, m.video_asset_id
  FROM app.video_asset_legacy_map m
  JOIN candidates c
    ON c.context_type = m.context_type AND c.context_id = m.context_id AND c.role = m.role
),
new_ids AS (
  SELECT c.context_type, c.context_id, c.role, gen_random_uuid() AS video_asset_id
  FROM candidates c
  LEFT JOIN app.video_asset_legacy_map m
    ON m.context_type = c.context_type AND m.context_id = c.context_id AND m.role = c.role
  WHERE m.video_asset_id IS NULL
),
ins_assets AS (
  INSERT INTO app.video_assets (id, owner_user_id, origin, status)
  SELECT n.video_asset_id, NULL, 'challenge_submission', 'ready'
  FROM new_ids n
  WHERE NOT EXISTS (SELECT 1 FROM app.video_assets a WHERE a.id = n.video_asset_id)
),
ins_map AS (
  INSERT INTO app.video_asset_legacy_map (context_type, context_id, role, video_asset_id)
  SELECT n.context_type, n.context_id, n.role, n.video_asset_id
  FROM new_ids n
  ON CONFLICT (context_type, context_id, role) DO NOTHING
),
all_map AS (
  SELECT * FROM existing_map
  UNION ALL
  SELECT * FROM new_ids
),
ins_ctx AS (
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  SELECT am.video_asset_id, am.context_type, am.context_id, am.role
  FROM all_map am
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id
),
ins_rend AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_primary',
    'mp4',
    'legacy',
    'legacy/external',
    c.url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
),
ins_thumb AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_poster',
    'poster',
    'legacy',
    'legacy/external',
    c.thumb_url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  WHERE c.thumb_url IS NOT NULL
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
)
UPDATE app.challenge_participation_videos pv
SET video_asset_id = am.video_asset_id
FROM all_map am
WHERE pv.id = am.context_id
  AND pv.video_asset_id IS NULL;


-- 2.3 free_videos
WITH candidates AS (
  SELECT
    fv.id AS context_id,
    'free_video'::text AS context_type,
    'primary'::text AS role,
    fv.user_id AS owner_user_id,
    COALESCE(NULLIF(TRIM(fv.video_url),''), NULL) AS url,
    NULLIF(TRIM(fv.thumbnail_url), '') AS thumb_url
  FROM app.free_videos fv
  WHERE fv.video_asset_id IS NULL
    AND COALESCE(NULLIF(TRIM(fv.video_url),''), NULL) IS NOT NULL
),
existing_map AS (
  SELECT m.context_type, m.context_id, m.role, m.video_asset_id
  FROM app.video_asset_legacy_map m
  JOIN candidates c
    ON c.context_type = m.context_type AND c.context_id = m.context_id AND c.role = m.role
),
new_ids AS (
  SELECT c.context_type, c.context_id, c.role, gen_random_uuid() AS video_asset_id
  FROM candidates c
  LEFT JOIN app.video_asset_legacy_map m
    ON m.context_type = c.context_type AND m.context_id = c.context_id AND m.role = c.role
  WHERE m.video_asset_id IS NULL
),
ins_assets AS (
  INSERT INTO app.video_assets (id, owner_user_id, origin, status)
  SELECT n.video_asset_id, c.owner_user_id, 'student_home', 'ready'
  FROM new_ids n
  JOIN candidates c ON c.context_id = n.context_id
  WHERE NOT EXISTS (SELECT 1 FROM app.video_assets a WHERE a.id = n.video_asset_id)
),
ins_map AS (
  INSERT INTO app.video_asset_legacy_map (context_type, context_id, role, video_asset_id)
  SELECT n.context_type, n.context_id, n.role, n.video_asset_id
  FROM new_ids n
  ON CONFLICT (context_type, context_id, role) DO NOTHING
),
all_map AS (
  SELECT * FROM existing_map
  UNION ALL
  SELECT * FROM new_ids
),
ins_ctx AS (
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  SELECT am.video_asset_id, am.context_type, am.context_id, am.role
  FROM all_map am
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id
),
ins_rend AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_primary',
    'mp4',
    'legacy',
    'legacy/external',
    c.url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
),
ins_thumb AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_poster',
    'poster',
    'legacy',
    'legacy/external',
    c.thumb_url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  WHERE c.thumb_url IS NOT NULL
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
)
UPDATE app.free_videos fv
SET video_asset_id = am.video_asset_id
FROM all_map am
WHERE fv.id = am.context_id
  AND fv.video_asset_id IS NULL;


-- 2.4 landing_videos
WITH candidates AS (
  SELECT
    lv.id AS context_id,
    'landing_video'::text AS context_type,
    'primary'::text AS role,
    NULL::uuid AS owner_user_id,
    COALESCE(NULLIF(TRIM(lv.video_url),''), NULL) AS url
  FROM app.landing_videos lv
  WHERE lv.video_asset_id IS NULL
    AND COALESCE(NULLIF(TRIM(lv.video_url),''), NULL) IS NOT NULL
),
existing_map AS (
  SELECT m.context_type, m.context_id, m.role, m.video_asset_id
  FROM app.video_asset_legacy_map m
  JOIN candidates c
    ON c.context_type = m.context_type AND c.context_id = m.context_id AND c.role = m.role
),
new_ids AS (
  SELECT c.context_type, c.context_id, c.role, gen_random_uuid() AS video_asset_id
  FROM candidates c
  LEFT JOIN app.video_asset_legacy_map m
    ON m.context_type = c.context_type AND m.context_id = c.context_id AND m.role = c.role
  WHERE m.video_asset_id IS NULL
),
ins_assets AS (
  INSERT INTO app.video_assets (id, owner_user_id, origin, status)
  SELECT n.video_asset_id, NULL, 'landing', 'ready'
  FROM new_ids n
  WHERE NOT EXISTS (SELECT 1 FROM app.video_assets a WHERE a.id = n.video_asset_id)
),
ins_map AS (
  INSERT INTO app.video_asset_legacy_map (context_type, context_id, role, video_asset_id)
  SELECT n.context_type, n.context_id, n.role, n.video_asset_id
  FROM new_ids n
  ON CONFLICT (context_type, context_id, role) DO NOTHING
),
all_map AS (
  SELECT * FROM existing_map
  UNION ALL
  SELECT * FROM new_ids
),
ins_ctx AS (
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  SELECT am.video_asset_id, am.context_type, am.context_id, am.role
  FROM all_map am
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id
),
ins_rend AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_primary',
    'mp4',
    'legacy',
    'legacy/external',
    c.url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
)
UPDATE app.landing_videos lv
SET video_asset_id = am.video_asset_id
FROM all_map am
WHERE lv.id = am.context_id
  AND lv.video_asset_id IS NULL;


-- 2.5 landing_config (single row)
WITH candidates AS (
  SELECT
    lc.id AS context_id,
    'landing_config'::text AS context_type,
    'hero'::text AS role,
    NULL::uuid AS owner_user_id,
    COALESCE(NULLIF(TRIM(lc.video_url),''), NULL) AS url
  FROM app.landing_config lc
  WHERE lc.video_asset_id IS NULL
    AND COALESCE(NULLIF(TRIM(lc.video_url),''), NULL) IS NOT NULL
),
existing_map AS (
  SELECT m.context_type, m.context_id, m.role, m.video_asset_id
  FROM app.video_asset_legacy_map m
  JOIN candidates c
    ON c.context_type = m.context_type AND c.context_id = m.context_id AND c.role = m.role
),
new_ids AS (
  SELECT c.context_type, c.context_id, c.role, gen_random_uuid() AS video_asset_id
  FROM candidates c
  LEFT JOIN app.video_asset_legacy_map m
    ON m.context_type = c.context_type AND m.context_id = c.context_id AND m.role = c.role
  WHERE m.video_asset_id IS NULL
),
ins_assets AS (
  INSERT INTO app.video_assets (id, owner_user_id, origin, status)
  SELECT n.video_asset_id, NULL, 'landing', 'ready'
  FROM new_ids n
  WHERE NOT EXISTS (SELECT 1 FROM app.video_assets a WHERE a.id = n.video_asset_id)
),
ins_map AS (
  INSERT INTO app.video_asset_legacy_map (context_type, context_id, role, video_asset_id)
  SELECT n.context_type, n.context_id, n.role, n.video_asset_id
  FROM new_ids n
  ON CONFLICT (context_type, context_id, role) DO NOTHING
),
all_map AS (
  SELECT * FROM existing_map
  UNION ALL
  SELECT * FROM new_ids
),
ins_ctx AS (
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  SELECT am.video_asset_id, am.context_type, am.context_id, am.role
  FROM all_map am
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id
),
ins_rend AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_primary',
    'mp4',
    'legacy',
    'legacy/external',
    c.url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
)
UPDATE app.landing_config lc
SET video_asset_id = am.video_asset_id
FROM all_map am
WHERE lc.id = am.context_id
  AND lc.video_asset_id IS NULL;


-- 2.6 student_home_videos
WITH candidates AS (
  SELECT
    shv.id AS context_id,
    'student_home_video'::text AS context_type,
    'primary'::text AS role,
    NULL::uuid AS owner_user_id,
    COALESCE(NULLIF(TRIM(shv.video_url),''), NULL) AS url
  FROM app.student_home_videos shv
  WHERE shv.video_asset_id IS NULL
    AND COALESCE(NULLIF(TRIM(shv.video_url),''), NULL) IS NOT NULL
),
existing_map AS (
  SELECT m.context_type, m.context_id, m.role, m.video_asset_id
  FROM app.video_asset_legacy_map m
  JOIN candidates c
    ON c.context_type = m.context_type AND c.context_id = m.context_id AND c.role = m.role
),
new_ids AS (
  SELECT c.context_type, c.context_id, c.role, gen_random_uuid() AS video_asset_id
  FROM candidates c
  LEFT JOIN app.video_asset_legacy_map m
    ON m.context_type = c.context_type AND m.context_id = c.context_id AND m.role = c.role
  WHERE m.video_asset_id IS NULL
),
ins_assets AS (
  INSERT INTO app.video_assets (id, owner_user_id, origin, status)
  SELECT n.video_asset_id, NULL, 'student_home', 'ready'
  FROM new_ids n
  WHERE NOT EXISTS (SELECT 1 FROM app.video_assets a WHERE a.id = n.video_asset_id)
),
ins_map AS (
  INSERT INTO app.video_asset_legacy_map (context_type, context_id, role, video_asset_id)
  SELECT n.context_type, n.context_id, n.role, n.video_asset_id
  FROM new_ids n
  ON CONFLICT (context_type, context_id, role) DO NOTHING
),
all_map AS (
  SELECT * FROM existing_map
  UNION ALL
  SELECT * FROM new_ids
),
ins_ctx AS (
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  SELECT am.video_asset_id, am.context_type, am.context_id, am.role
  FROM all_map am
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id
),
ins_rend AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_primary',
    'mp4',
    'legacy',
    'legacy/external',
    c.url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
)
UPDATE app.student_home_videos shv
SET video_asset_id = am.video_asset_id
FROM all_map am
WHERE shv.id = am.context_id
  AND shv.video_asset_id IS NULL;


-- 2.7 hero_playlist (base_video_url)
WITH candidates AS (
  SELECT
    hp.id AS context_id,
    'hero_playlist'::text AS context_type,
    'primary'::text AS role,
    NULL::uuid AS owner_user_id,
    COALESCE(NULLIF(TRIM(hp.base_video_url),''), NULL) AS url
  FROM app.hero_playlist hp
  WHERE hp.video_asset_id IS NULL
    AND COALESCE(NULLIF(TRIM(hp.base_video_url),''), NULL) IS NOT NULL
),
existing_map AS (
  SELECT m.context_type, m.context_id, m.role, m.video_asset_id
  FROM app.video_asset_legacy_map m
  JOIN candidates c
    ON c.context_type = m.context_type AND c.context_id = m.context_id AND c.role = m.role
),
new_ids AS (
  SELECT c.context_type, c.context_id, c.role, gen_random_uuid() AS video_asset_id
  FROM candidates c
  LEFT JOIN app.video_asset_legacy_map m
    ON m.context_type = c.context_type AND m.context_id = c.context_id AND m.role = c.role
  WHERE m.video_asset_id IS NULL
),
ins_assets AS (
  INSERT INTO app.video_assets (id, owner_user_id, origin, status)
  SELECT n.video_asset_id, NULL, 'landing', 'ready'
  FROM new_ids n
  WHERE NOT EXISTS (SELECT 1 FROM app.video_assets a WHERE a.id = n.video_asset_id)
),
ins_map AS (
  INSERT INTO app.video_asset_legacy_map (context_type, context_id, role, video_asset_id)
  SELECT n.context_type, n.context_id, n.role, n.video_asset_id
  FROM new_ids n
  ON CONFLICT (context_type, context_id, role) DO NOTHING
),
all_map AS (
  SELECT * FROM existing_map
  UNION ALL
  SELECT * FROM new_ids
),
ins_ctx AS (
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  SELECT am.video_asset_id, am.context_type, am.context_id, am.role
  FROM all_map am
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id
),
ins_rend AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_primary',
    'mp4',
    'legacy',
    'legacy/external',
    c.url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
)
UPDATE app.hero_playlist hp
SET video_asset_id = am.video_asset_id
FROM all_map am
WHERE hp.id = am.context_id
  AND hp.video_asset_id IS NULL;


-- 2.8 university_media (url where media_type='video')
WITH candidates AS (
  SELECT
    um.id AS context_id,
    'university_media'::text AS context_type,
    'primary'::text AS role,
    NULL::uuid AS owner_user_id,
    COALESCE(NULLIF(TRIM(um.url),''), NULLIF(TRIM(um.storage_path),'')) AS url,
    NULLIF(TRIM(um.thumbnail_url), '') AS thumb_url
  FROM app.university_media um
  WHERE um.video_asset_id IS NULL
    AND LOWER(COALESCE(um.media_type,'')) = 'video'
    AND COALESCE(NULLIF(TRIM(um.url),''), NULLIF(TRIM(um.storage_path),'')) IS NOT NULL
),
existing_map AS (
  SELECT m.context_type, m.context_id, m.role, m.video_asset_id
  FROM app.video_asset_legacy_map m
  JOIN candidates c
    ON c.context_type = m.context_type AND c.context_id = m.context_id AND c.role = m.role
),
new_ids AS (
  SELECT c.context_type, c.context_id, c.role, gen_random_uuid() AS video_asset_id
  FROM candidates c
  LEFT JOIN app.video_asset_legacy_map m
    ON m.context_type = c.context_type AND m.context_id = c.context_id AND m.role = c.role
  WHERE m.video_asset_id IS NULL
),
ins_assets AS (
  INSERT INTO app.video_assets (id, owner_user_id, origin, status)
  SELECT n.video_asset_id, NULL, 'university_media', 'ready'
  FROM new_ids n
  WHERE NOT EXISTS (SELECT 1 FROM app.video_assets a WHERE a.id = n.video_asset_id)
),
ins_map AS (
  INSERT INTO app.video_asset_legacy_map (context_type, context_id, role, video_asset_id)
  SELECT n.context_type, n.context_id, n.role, n.video_asset_id
  FROM new_ids n
  ON CONFLICT (context_type, context_id, role) DO NOTHING
),
all_map AS (
  SELECT * FROM existing_map
  UNION ALL
  SELECT * FROM new_ids
),
ins_ctx AS (
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  SELECT am.video_asset_id, am.context_type, am.context_id, am.role
  FROM all_map am
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id
),
ins_rend AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_primary',
    'mp4',
    'legacy',
    'legacy/external',
    c.url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
),
ins_thumb AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_poster',
    'poster',
    'legacy',
    'legacy/external',
    c.thumb_url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  WHERE c.thumb_url IS NOT NULL
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
)
UPDATE app.university_media um
SET video_asset_id = am.video_asset_id
FROM all_map am
WHERE um.id = am.context_id
  AND um.video_asset_id IS NULL;


-- 2.9 online_course_live_sessions (replay_video_url)
WITH candidates AS (
  SELECT
    ls.id AS context_id,
    'online_course_live_session'::text AS context_type,
    'replay'::text AS role,
    NULL::uuid AS owner_user_id,
    COALESCE(NULLIF(TRIM(ls.replay_video_url),''), NULL) AS url
  FROM app.online_course_live_sessions ls
  WHERE ls.replay_video_asset_id IS NULL
    AND COALESCE(NULLIF(TRIM(ls.replay_video_url),''), NULL) IS NOT NULL
),
existing_map AS (
  SELECT m.context_type, m.context_id, m.role, m.video_asset_id
  FROM app.video_asset_legacy_map m
  JOIN candidates c
    ON c.context_type = m.context_type AND c.context_id = m.context_id AND c.role = m.role
),
new_ids AS (
  SELECT c.context_type, c.context_id, c.role, gen_random_uuid() AS video_asset_id
  FROM candidates c
  LEFT JOIN app.video_asset_legacy_map m
    ON m.context_type = c.context_type AND m.context_id = c.context_id AND m.role = c.role
  WHERE m.video_asset_id IS NULL
),
ins_assets AS (
  INSERT INTO app.video_assets (id, owner_user_id, origin, status)
  SELECT n.video_asset_id, NULL, 'course_resource', 'ready'
  FROM new_ids n
  WHERE NOT EXISTS (SELECT 1 FROM app.video_assets a WHERE a.id = n.video_asset_id)
),
ins_map AS (
  INSERT INTO app.video_asset_legacy_map (context_type, context_id, role, video_asset_id)
  SELECT n.context_type, n.context_id, n.role, n.video_asset_id
  FROM new_ids n
  ON CONFLICT (context_type, context_id, role) DO NOTHING
),
all_map AS (
  SELECT * FROM existing_map
  UNION ALL
  SELECT * FROM new_ids
),
ins_ctx AS (
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  SELECT am.video_asset_id, am.context_type, am.context_id, am.role
  FROM all_map am
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id
),
ins_rend AS (
  INSERT INTO app.video_renditions (
    video_asset_id, rendition_key, kind, storage_bucket, storage_path, public_url_hint, status
  )
  SELECT
    am.video_asset_id,
    'legacy_primary',
    'mp4',
    'legacy',
    'legacy/external',
    c.url,
    'ready'
  FROM all_map am
  JOIN candidates c ON c.context_id = am.context_id
  ON CONFLICT (video_asset_id, rendition_key) DO UPDATE
    SET public_url_hint = EXCLUDED.public_url_hint,
        status = 'ready'
)
UPDATE app.online_course_live_sessions ls
SET replay_video_asset_id = am.video_asset_id
FROM all_map am
WHERE ls.id = am.context_id
  AND ls.replay_video_asset_id IS NULL;
