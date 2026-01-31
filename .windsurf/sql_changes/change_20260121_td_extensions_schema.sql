-- ========================================
-- ACADEMIA - MODULE TD (Travaux Dirigés)
-- Extension schema TD : ressources, séances, présence, dispo enseignants
-- Date: 2026-01-21
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- 1) Types complémentaires TD

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'td_resource_kind') THEN
    CREATE TYPE td_resource_kind AS ENUM ('pdf', 'doc', 'video', 'link', 'quiz', 'worksheet', 'other');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'td_session_occurrence_status') THEN
    CREATE TYPE td_session_occurrence_status AS ENUM (
      'planned',
      'confirmed',
      'completed',
      'cancelled'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'td_attendance_status') THEN
    CREATE TYPE td_attendance_status AS ENUM ('present', 'late', 'absent', 'excused');
  END IF;
END$$;

-- 2) Table app.td_resources

CREATE TABLE IF NOT EXISTS app.td_resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id    UUID REFERENCES app.td_programs (id) ON DELETE CASCADE,
  collection_id UUID REFERENCES app.td_collections (id) ON DELETE CASCADE,
  session_id    UUID REFERENCES app.td_sessions (id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  description   TEXT,
  kind          td_resource_kind NOT NULL,
  url           TEXT NOT NULL,
  is_required   BOOLEAN NOT NULL DEFAULT FALSE,
  position      INTEGER,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    UUID REFERENCES auth.users (id)
);

CREATE INDEX IF NOT EXISTS idx_td_resources_program
  ON app.td_resources (program_id);

CREATE INDEX IF NOT EXISTS idx_td_resources_collection
  ON app.td_resources (collection_id);

CREATE INDEX IF NOT EXISTS idx_td_resources_session
  ON app.td_resources (session_id);

ALTER TABLE app.td_resources ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS td_resources_admin_all ON app.td_resources;
CREATE POLICY td_resources_admin_all
  ON app.td_resources
  FOR ALL
  USING (app.app_td_get_current_role() = 'admin')
  WITH CHECK (app.app_td_get_current_role() = 'admin');

GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_resources TO authenticated;
GRANT ALL ON app.td_resources TO service_role;

-- 3) Table app.td_session_occurrences

CREATE TABLE IF NOT EXISTS app.td_session_occurrences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id     UUID NOT NULL REFERENCES app.td_sessions (id) ON DELETE CASCADE,
  enrollment_id  UUID NOT NULL REFERENCES app.td_enrollments (id) ON DELETE CASCADE,
  teacher_id     UUID REFERENCES app.td_teachers (id) ON DELETE SET NULL,
  scheduled_at   TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER NOT NULL,
  status         td_session_occurrence_status NOT NULL DEFAULT 'planned',
  location       TEXT,
  meeting_url    TEXT,
  student_notes  TEXT,
  teacher_notes  TEXT,
  admin_notes    TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by     UUID REFERENCES auth.users (id)
);

CREATE INDEX IF NOT EXISTS idx_td_session_occurrences_enrollment
  ON app.td_session_occurrences (enrollment_id);

CREATE INDEX IF NOT EXISTS idx_td_session_occurrences_teacher
  ON app.td_session_occurrences (teacher_id);

CREATE INDEX IF NOT EXISTS idx_td_session_occurrences_schedule
  ON app.td_session_occurrences (scheduled_at);

ALTER TABLE app.td_session_occurrences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS td_session_occurrences_admin_all ON app.td_session_occurrences;
CREATE POLICY td_session_occurrences_admin_all
  ON app.td_session_occurrences
  FOR ALL
  USING (app.app_td_get_current_role() = 'admin')
  WITH CHECK (app.app_td_get_current_role() = 'admin');

DROP POLICY IF EXISTS td_session_occurrences_student_select ON app.td_session_occurrences;
CREATE POLICY td_session_occurrences_student_select
  ON app.td_session_occurrences
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM app.td_enrollments e
      WHERE e.id = enrollment_id
        AND e.student_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS td_session_occurrences_teacher_select ON app.td_session_occurrences;
CREATE POLICY td_session_occurrences_teacher_select
  ON app.td_session_occurrences
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM app.td_teachers t
      WHERE t.id = teacher_id
        AND t.user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_session_occurrences TO authenticated;
GRANT ALL ON app.td_session_occurrences TO service_role;

-- 4) Table app.td_attendance

CREATE TABLE IF NOT EXISTS app.td_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  occurrence_id UUID NOT NULL REFERENCES app.td_session_occurrences (id) ON DELETE CASCADE,
  student_id    UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  status        td_attendance_status NOT NULL,
  joined_at     TIMESTAMPTZ,
  left_at       TIMESTAMPTZ,
  comment       TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    UUID REFERENCES auth.users (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_td_attendance_occurrence_student
  ON app.td_attendance (occurrence_id, student_id);

ALTER TABLE app.td_attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS td_attendance_admin_all ON app.td_attendance;
CREATE POLICY td_attendance_admin_all
  ON app.td_attendance
  FOR ALL
  USING (app.app_td_get_current_role() = 'admin')
  WITH CHECK (app.app_td_get_current_role() = 'admin');

DROP POLICY IF EXISTS td_attendance_student_select ON app.td_attendance;
CREATE POLICY td_attendance_student_select
  ON app.td_attendance
  FOR SELECT
  USING (student_id = auth.uid());

DROP POLICY IF EXISTS td_attendance_teacher_select ON app.td_attendance;
CREATE POLICY td_attendance_teacher_select
  ON app.td_attendance
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM app.td_session_occurrences o
      JOIN app.td_teachers t ON t.id = o.teacher_id
      WHERE o.id = occurrence_id
        AND t.user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_attendance TO authenticated;
GRANT ALL ON app.td_attendance TO service_role;

-- 5) Table app.td_teacher_availability

CREATE TABLE IF NOT EXISTS app.td_teacher_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES app.td_teachers (id) ON DELETE CASCADE,
  weekday    SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time   TIME NOT NULL,
  timezone   TEXT NOT NULL DEFAULT 'Africa/Abidjan',
  is_recurring BOOLEAN NOT NULL DEFAULT TRUE,
  valid_from  DATE,
  valid_until DATE,
  notes      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_td_teacher_availability_teacher
  ON app.td_teacher_availability (teacher_id, weekday);

ALTER TABLE app.td_teacher_availability ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS td_teacher_availability_admin_all ON app.td_teacher_availability;
CREATE POLICY td_teacher_availability_admin_all
  ON app.td_teacher_availability
  FOR ALL
  USING (app.app_td_get_current_role() = 'admin')
  WITH CHECK (app.app_td_get_current_role() = 'admin');

DROP POLICY IF EXISTS td_teacher_availability_teacher_select ON app.td_teacher_availability;
CREATE POLICY td_teacher_availability_teacher_select
  ON app.td_teacher_availability
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM app.td_teachers t
      WHERE t.id = teacher_id AND t.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS td_teacher_availability_teacher_insert ON app.td_teacher_availability;
CREATE POLICY td_teacher_availability_teacher_insert
  ON app.td_teacher_availability
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM app.td_teachers t
      WHERE t.id = teacher_id AND t.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS td_teacher_availability_teacher_update ON app.td_teacher_availability;
CREATE POLICY td_teacher_availability_teacher_update
  ON app.td_teacher_availability
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM app.td_teachers t
      WHERE t.id = teacher_id AND t.user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON app.td_teacher_availability TO authenticated;
GRANT ALL ON app.td_teacher_availability TO service_role;
