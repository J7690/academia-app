-- ========================================
-- TABLE & TELEMETRY - ERREURS DE LECTURE VIDÉO
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE IF NOT EXISTS app.video_playback_errors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    device_model TEXT,
    platform TEXT,
    os_version TEXT,
    app_version TEXT,
    video_url TEXT NOT NULL,
    rendition_key TEXT,
    error_message TEXT NOT NULL,
    raw_error JSONB
);

ALTER TABLE app.video_playback_errors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_video_playback_errors ON app.video_playback_errors;
CREATE POLICY admin_all_video_playback_errors
ON app.video_playback_errors
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

GRANT SELECT ON app.video_playback_errors TO authenticated;
GRANT ALL ON app.video_playback_errors TO service_role;
