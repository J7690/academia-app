-- Hero Video Studio – bucket, tables et RPC dédiés
-- A appliquer via :
--   python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251230_hero_video_studio.sql

-- 1) Bucket de stockage dédié pour les vidéos Hero

INSERT INTO storage.buckets (id, name, public)
VALUES ('hero_videos', 'hero_videos', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Lecture publique des objets du bucket hero_videos (segments Hero)
DROP POLICY IF EXISTS public_read_hero_videos ON storage.objects;
CREATE POLICY public_read_hero_videos
ON storage.objects
AS PERMISSIVE
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'hero_videos'
);

-- 2) Table app.hero_video_jobs : suivi des traitements backend (admin-only)

CREATE TABLE IF NOT EXISTS app.hero_video_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  context TEXT NOT NULL CHECK (context IN ('landing', 'student_home', 'minisite')),
  source_filename TEXT,
  source_size_bytes BIGINT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'success', 'error')),
  log TEXT,
  hero_video_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.hero_video_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_hero_video_jobs ON app.hero_video_jobs;
CREATE POLICY admin_all_hero_video_jobs
ON app.hero_video_jobs
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

GRANT SELECT, INSERT, UPDATE, DELETE ON app.hero_video_jobs TO service_role;

-- 3) Table app.hero_videos : métadonnées des vidéos Hero prêtes à consommer

CREATE TABLE IF NOT EXISTS app.hero_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  context TEXT NOT NULL CHECK (context IN ('landing', 'student_home', 'minisite')),
  duration NUMERIC,
  resolution TEXT,
  fps INT,
  codec TEXT,
  audio_codec TEXT,
  parts_count INT NOT NULL,
  parts_urls TEXT[] NOT NULL,
  total_size_bytes BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.hero_videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_hero_videos ON app.hero_videos;
CREATE POLICY admin_all_hero_videos
ON app.hero_videos
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

GRANT SELECT ON app.hero_videos TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON app.hero_videos TO service_role;

-- 4) RPC de lecture read-only pour les HERO

CREATE OR REPLACE FUNCTION app.hero_list_videos(p_context TEXT)
RETURNS TABLE (
  id UUID,
  context TEXT,
  duration NUMERIC,
  resolution TEXT,
  fps INT,
  codec TEXT,
  audio_codec TEXT,
  parts_count INT,
  parts_urls TEXT[],
  total_size_bytes BIGINT,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    hv.id,
    hv.context,
    hv.duration,
    hv.resolution,
    hv.fps,
    hv.codec,
    hv.audio_codec,
    hv.parts_count,
    hv.parts_urls,
    hv.total_size_bytes,
    hv.created_at
  FROM app.hero_videos hv
  WHERE (p_context IS NULL OR hv.context = p_context)
  ORDER BY hv.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION app.hero_list_videos(TEXT) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION app.hero_get_video(p_id UUID)
RETURNS app.hero_videos
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM app.hero_videos WHERE id = p_id;
$$;

GRANT EXECUTE ON FUNCTION app.hero_get_video(UUID) TO anon, authenticated, service_role;
