-- ═══════════════════════════════════════════════════════════════════
-- TD Gamification Schema — Tables + Seeds + RLS
-- Extends existing app.td_* tables with gamification, XP logging,
-- streaks, leaderboard, resource progress, and discipline colors.
-- ═══════════════════════════════════════════════════════════════════

-- ─── 1. td_xp_log — Journal XP (chaque gain/perte) ──────────────
CREATE TABLE IF NOT EXISTS app.td_xp_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id  uuid NOT NULL,
  amount      integer NOT NULL,        -- positif = gain, négatif = perte
  reason      text NOT NULL,           -- 'session_attended','quiz_completed','resource_viewed','streak_bonus','badge_earned','admin_grant'
  ref_type    text,                    -- 'enrollment','session','quiz','resource','badge'
  ref_id      uuid,                    -- ID de l'objet référencé
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE app.td_xp_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all" ON app.td_xp_log;
CREATE POLICY "service_role_all" ON app.td_xp_log FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "td_xp_log_student_select" ON app.td_xp_log;
CREATE POLICY "td_xp_log_student_select" ON app.td_xp_log FOR SELECT TO public USING (student_id = auth.uid());

-- Index pour requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_td_xp_log_student ON app.td_xp_log(student_id, created_at DESC);

-- ─── 2. td_streaks — Streaks quotidiens ──────────────────────────
CREATE TABLE IF NOT EXISTS app.td_streaks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id      uuid NOT NULL UNIQUE,
  current_streak  integer NOT NULL DEFAULT 0,
  longest_streak  integer NOT NULL DEFAULT 0,
  last_active_date date,
  streak_frozen_until date,            -- streak freeze (optionnel)
  total_active_days integer NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE app.td_streaks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all" ON app.td_streaks;
CREATE POLICY "service_role_all" ON app.td_streaks FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "td_streaks_student_select" ON app.td_streaks;
CREATE POLICY "td_streaks_student_select" ON app.td_streaks FOR SELECT TO public USING (student_id = auth.uid());

-- ─── 3. td_resource_progress — Suivi consultation ressources ─────
CREATE TABLE IF NOT EXISTS app.td_resource_progress (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id   uuid NOT NULL,
  resource_id  uuid NOT NULL REFERENCES app.td_resources(id) ON DELETE CASCADE,
  status       text NOT NULL DEFAULT 'not_started', -- 'not_started','in_progress','completed'
  progress_pct integer NOT NULL DEFAULT 0,          -- 0-100
  last_position text,                               -- bookmark (page, timestamp vidéo, etc.)
  started_at   timestamptz,
  completed_at timestamptz,
  time_spent_seconds integer NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(student_id, resource_id)
);

ALTER TABLE app.td_resource_progress ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all" ON app.td_resource_progress;
CREATE POLICY "service_role_all" ON app.td_resource_progress FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "td_resource_progress_student_select" ON app.td_resource_progress;
CREATE POLICY "td_resource_progress_student_select" ON app.td_resource_progress FOR SELECT TO public USING (student_id = auth.uid());

-- ─── 4. td_leaderboard_cache — Cache leaderboard hebdo ──────────
CREATE TABLE IF NOT EXISTS app.td_leaderboard_cache (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id   uuid NOT NULL,
  program_id   uuid,                   -- NULL = global
  period_start date NOT NULL,          -- lundi de la semaine
  period_end   date NOT NULL,          -- dimanche
  xp_earned    integer NOT NULL DEFAULT 0,
  rank         integer,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(student_id, program_id, period_start)
);

ALTER TABLE app.td_leaderboard_cache ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all" ON app.td_leaderboard_cache;
CREATE POLICY "service_role_all" ON app.td_leaderboard_cache FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "td_leaderboard_cache_public_select" ON app.td_leaderboard_cache;
CREATE POLICY "td_leaderboard_cache_public_select" ON app.td_leaderboard_cache FOR SELECT TO public USING (true);

-- ─── 5. td_discipline_colors — Couleurs par discipline ───────────
CREATE TABLE IF NOT EXISTS app.td_discipline_colors (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id   uuid REFERENCES app.td_fields(id) ON DELETE CASCADE,
  field_name text NOT NULL,
  color_hex  text NOT NULL DEFAULT '#4F46E5',  -- couleur principale
  gradient_start text NOT NULL DEFAULT '#4F46E5',
  gradient_end   text NOT NULL DEFAULT '#6366F1',
  icon_name  text NOT NULL DEFAULT 'school',   -- nom icône Material
  position   integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE app.td_discipline_colors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all" ON app.td_discipline_colors;
CREATE POLICY "service_role_all" ON app.td_discipline_colors FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "td_discipline_colors_public_select" ON app.td_discipline_colors;
CREATE POLICY "td_discipline_colors_public_select" ON app.td_discipline_colors FOR SELECT TO public USING (true);

-- ─── 6. td_daily_goals — Objectifs quotidiens ───────────────────
CREATE TABLE IF NOT EXISTS app.td_daily_goals (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id  uuid NOT NULL,
  goal_date   date NOT NULL DEFAULT CURRENT_DATE,
  target_xp   integer NOT NULL DEFAULT 50,
  earned_xp   integer NOT NULL DEFAULT 0,
  completed   boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(student_id, goal_date)
);

ALTER TABLE app.td_daily_goals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_role_all" ON app.td_daily_goals;
CREATE POLICY "service_role_all" ON app.td_daily_goals FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "td_daily_goals_student_select" ON app.td_daily_goals;
CREATE POLICY "td_daily_goals_student_select" ON app.td_daily_goals FOR SELECT TO public USING (student_id = auth.uid());

-- ─── 7. Add missing columns to existing tables ──────────────────

-- td_programs: add cover_image_url, enrollment_count, avg_rating, tags
DO $$ BEGIN
  ALTER TABLE app.td_programs ADD COLUMN IF NOT EXISTS cover_image_url text;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE app.td_programs ADD COLUMN IF NOT EXISTS enrollment_count integer DEFAULT 0;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE app.td_programs ADD COLUMN IF NOT EXISTS avg_rating numeric DEFAULT 0;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE app.td_programs ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}';
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE app.td_programs ADD COLUMN IF NOT EXISTS is_featured boolean DEFAULT false;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- td_fields: add color_hex, icon_name, description
DO $$ BEGIN
  ALTER TABLE app.td_fields ADD COLUMN IF NOT EXISTS color_hex text DEFAULT '#4F46E5';
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE app.td_fields ADD COLUMN IF NOT EXISTS icon_name text DEFAULT 'school';
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE app.td_fields ADD COLUMN IF NOT EXISTS description text;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- td_enrollments: add progress_pct, completed_sessions, total_sessions
DO $$ BEGIN
  ALTER TABLE app.td_enrollments ADD COLUMN IF NOT EXISTS progress_pct integer DEFAULT 0;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE app.td_enrollments ADD COLUMN IF NOT EXISTS completed_sessions integer DEFAULT 0;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE app.td_enrollments ADD COLUMN IF NOT EXISTS total_sessions integer DEFAULT 0;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- td_resources: add thumbnail_url, duration_seconds, file_size_bytes, download_count
DO $$ BEGIN
  ALTER TABLE app.td_resources ADD COLUMN IF NOT EXISTS thumbnail_url text;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE app.td_resources ADD COLUMN IF NOT EXISTS duration_seconds integer;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE app.td_resources ADD COLUMN IF NOT EXISTS file_size_bytes bigint;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE app.td_resources ADD COLUMN IF NOT EXISTS download_count integer DEFAULT 0;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- ─── 8. Seed discipline colors ──────────────────────────────────
INSERT INTO app.td_discipline_colors (field_name, color_hex, gradient_start, gradient_end, icon_name, position)
VALUES
  ('Mathématiques',  '#4F46E5', '#4F46E5', '#6366F1', 'calculate',      1),
  ('Physique',       '#EA580C', '#EA580C', '#F97316', 'science',        2),
  ('Chimie',         '#059669', '#059669', '#10B981', 'biotech',        3),
  ('Français',       '#DC2626', '#DC2626', '#EF4444', 'menu_book',     4),
  ('Anglais',        '#7C3AED', '#7C3AED', '#8B5CF6', 'translate',     5),
  ('Histoire-Géo',   '#D97706', '#D97706', '#F59E0B', 'public',        6),
  ('Informatique',   '#0891B2', '#0891B2', '#06B6D4', 'computer',      7),
  ('SVT',            '#16A34A', '#16A34A', '#22C55E', 'eco',           8),
  ('Philosophie',    '#9333EA', '#9333EA', '#A855F7', 'psychology',    9),
  ('Économie',       '#0D9488', '#0D9488', '#14B8A6', 'trending_up',  10),
  ('Droit',          '#1D4ED8', '#1D4ED8', '#3B82F6', 'gavel',        11),
  ('Autre',          '#6B7280', '#6B7280', '#9CA3AF', 'school',       12)
ON CONFLICT DO NOTHING;

-- ─── 9. GRANTS ──────────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_xp_log TO postgres, service_role;
GRANT SELECT ON app.td_xp_log TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_streaks TO postgres, service_role;
GRANT SELECT ON app.td_streaks TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_resource_progress TO postgres, service_role;
GRANT SELECT ON app.td_resource_progress TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_leaderboard_cache TO postgres, service_role;
GRANT SELECT ON app.td_leaderboard_cache TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_discipline_colors TO postgres, service_role;
GRANT SELECT ON app.td_discipline_colors TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_daily_goals TO postgres, service_role;
GRANT SELECT ON app.td_daily_goals TO anon, authenticated;
