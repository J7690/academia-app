-- Hero Studio Télé : animations TV + rendus MP4
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251210_hero_studio.sql

-- 1) Table des animations TV pour overlays Hero Studio

CREATE TABLE IF NOT EXISTS app.hero_overlay_animations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    config JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.hero_overlay_animations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_hero_overlay_animations ON app.hero_overlay_animations;
CREATE POLICY public_select_hero_overlay_animations
ON app.hero_overlay_animations FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS admin_all_hero_overlay_animations ON app.hero_overlay_animations;
CREATE POLICY admin_all_hero_overlay_animations
ON app.hero_overlay_animations
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

GRANT SELECT ON app.hero_overlay_animations TO anon, authenticated;
GRANT ALL ON app.hero_overlay_animations TO service_role;

-- Seed d'animations TV de base (idempotent)

INSERT INTO app.hero_overlay_animations (code, name, config)
VALUES
  ('fade_in', 'Fade In', '{"type":"fade","direction":"in"}'::JSONB),
  ('fade_out', 'Fade Out', '{"type":"fade","direction":"out"}'::JSONB),
  ('slide_left', 'Slide From Left', '{"type":"slide","from":"left"}'::JSONB),
  ('slide_right', 'Slide From Right', '{"type":"slide","from":"right"}'::JSONB),
  ('slide_top', 'Slide From Top', '{"type":"slide","from":"top"}'::JSONB),
  ('slide_bottom', 'Slide From Bottom', '{"type":"slide","from":"bottom"}'::JSONB),
  ('zoom_in', 'Zoom In', '{"type":"zoom","direction":"in"}'::JSONB),
  ('zoom_out', 'Zoom Out', '{"type":"zoom","direction":"out"}'::JSONB),
  ('pop', 'Pop', '{"type":"pop"}'::JSONB),
  ('wipe_left', 'Wipe From Left', '{"type":"wipe","from":"left"}'::JSONB),
  ('ticker_crawl', 'Ticker Crawl', '{"type":"ticker","direction":"left_to_right"}'::JSONB),
  ('typewriter', 'Typewriter', '{"type":"typewriter"}'::JSONB)
ON CONFLICT (code) DO NOTHING;


-- 2) Table des rendus Hero Studio (MP4 final + vignette)

CREATE TABLE IF NOT EXISTS app.hero_renders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    playlist_item_id UUID NOT NULL REFERENCES app.hero_playlist (id),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'done', 'failed')),
    render_url TEXT,
    thumbnail_url TEXT,
    logs TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.hero_renders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_hero_renders ON app.hero_renders;
CREATE POLICY admin_all_hero_renders
ON app.hero_renders
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

GRANT SELECT ON app.hero_renders TO authenticated;
GRANT ALL ON app.hero_renders TO service_role;
