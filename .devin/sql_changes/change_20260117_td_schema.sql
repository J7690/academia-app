-- ========================================
-- ACADEMIA - MODULE TD (Travaux Dirigés)
-- Phase 2 - Socle Supabase : Schéma + RLS
-- Date: 2026-01-17
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) Types spécifiques TD
-- ========================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'td_modality') THEN
    CREATE TYPE td_modality AS ENUM ('online', 'onsite', 'hybrid');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'td_program_status') THEN
    CREATE TYPE td_program_status AS ENUM ('draft', 'published', 'inactive');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'td_enrollment_status') THEN
    CREATE TYPE td_enrollment_status AS ENUM (
      'pending_payment',
      'waiting_admin',
      'active',
      'completed',
      'cancelled'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'td_assignment_status') THEN
    CREATE TYPE td_assignment_status AS ENUM (
      'unassigned',
      'assigned',
      'closed'
    );
  END IF;
END$$;

-- Étendre le type payment_reason pour supporter les paiements TD
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'payment_reason'
      AND e.enumlabel = 'td_access'
  ) THEN
    ALTER TYPE payment_reason ADD VALUE 'td_access';
  END IF;
END$$;

-- ========================================
-- 2) Tables principales TD
-- ========================================

CREATE TABLE IF NOT EXISTS app.td_fields (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- active / inactive
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users (id)
);

CREATE TABLE IF NOT EXISTS app.td_programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id UUID NOT NULL REFERENCES app.td_fields (id) ON DELETE RESTRICT,
  level TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  modality td_modality NOT NULL DEFAULT 'online',
  price NUMERIC(12,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'XOF',
  status td_program_status NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users (id)
);

CREATE INDEX IF NOT EXISTS idx_td_programs_field_level
  ON app.td_programs (field_id, level);

CREATE TABLE IF NOT EXISTS app.td_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id UUID NOT NULL REFERENCES app.td_programs (id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  position INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_td_collections_program
  ON app.td_collections (program_id);

CREATE TABLE IF NOT EXISTS app.td_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  collection_id UUID NOT NULL REFERENCES app.td_collections (id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  document_url TEXT, -- contenu verrouillé
  is_preview BOOLEAN NOT NULL DEFAULT FALSE,
  position INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_td_sessions_collection
  ON app.td_sessions (collection_id);

CREATE TABLE IF NOT EXISTS app.td_teachers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  discipline TEXT,
  zone TEXT,
  levels TEXT[] DEFAULT ARRAY[]::TEXT[],
  availability TEXT,
  status TEXT NOT NULL DEFAULT 'active', -- active / suspended / removed
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_td_teachers_user UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS app.td_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  program_id UUID NOT NULL REFERENCES app.td_programs (id) ON DELETE RESTRICT,
  collection_id UUID REFERENCES app.td_collections (id) ON DELETE RESTRICT,
  access_scope TEXT NOT NULL DEFAULT 'program', -- program / collection / document / certification
  payment_id UUID UNIQUE REFERENCES app.application_payments (id) ON DELETE SET NULL,
  access_status td_enrollment_status NOT NULL DEFAULT 'pending_payment',
  assignment_status td_assignment_status NOT NULL DEFAULT 'unassigned',
  assigned_teacher_id UUID REFERENCES app.td_teachers (id) ON DELETE SET NULL,
  student_notes TEXT,
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  activated_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_td_enrollments_student
  ON app.td_enrollments (student_id);

CREATE INDEX IF NOT EXISTS idx_td_enrollments_teacher
  ON app.td_enrollments (assigned_teacher_id);

CREATE TABLE IF NOT EXISTS app.td_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  td_enrollment_id UUID REFERENCES app.td_enrollments (id) ON DELETE CASCADE,
  thread_type TEXT NOT NULL CHECK (thread_type IN ('student_admin', 'teacher_admin')),
  student_user_id UUID REFERENCES auth.users (id) ON DELETE CASCADE,
  teacher_user_id UUID REFERENCES auth.users (id) ON DELETE CASCADE,
  admin_user_id UUID REFERENCES auth.users (id) ON DELETE CASCADE,
  sender_role TEXT NOT NULL CHECK (sender_role IN ('admin', 'student', 'teacher')),
  sender_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  attachment_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_td_messages_enrollment
  ON app.td_messages (td_enrollment_id);

CREATE INDEX IF NOT EXISTS idx_td_messages_student
  ON app.td_messages (student_user_id);

CREATE INDEX IF NOT EXISTS idx_td_messages_teacher
  ON app.td_messages (teacher_user_id);

-- ========================================
-- 3) RLS - Gouvernance centralisée
-- ========================================

-- Helper expression:
-- current_setting('request.jwt.claims', true)::jsonb->>'role'

-- TD_FIELDS
ALTER TABLE app.td_fields ENABLE ROW LEVEL SECURITY;

CREATE POLICY td_fields_admin_all
  ON app.td_fields
  USING ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin')
  WITH CHECK ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin');

CREATE POLICY td_fields_public_select
  ON app.td_fields
  FOR SELECT
  USING (status = 'active');

-- TD_PROGRAMS
ALTER TABLE app.td_programs ENABLE ROW LEVEL SECURITY;

CREATE POLICY td_programs_admin_all
  ON app.td_programs
  USING ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin')
  WITH CHECK ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin');

CREATE POLICY td_programs_public_select
  ON app.td_programs
  FOR SELECT
  USING (status = 'published');

-- TD_COLLECTIONS
ALTER TABLE app.td_collections ENABLE ROW LEVEL SECURITY;

CREATE POLICY td_collections_admin_all
  ON app.td_collections
  USING ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin')
  WITH CHECK ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin');

CREATE POLICY td_collections_public_select
  ON app.td_collections
  FOR SELECT
  USING (TRUE);

-- TD_SESSIONS
ALTER TABLE app.td_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY td_sessions_admin_all
  ON app.td_sessions
  USING ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin')
  WITH CHECK ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin');

-- Contenu des documents toujours sélectionnable, le verrouillage est géré au niveau applicatif (UI)
CREATE POLICY td_sessions_public_select
  ON app.td_sessions
  FOR SELECT
  USING (TRUE);

-- TD_TEACHERS
ALTER TABLE app.td_teachers ENABLE ROW LEVEL SECURITY;

CREATE POLICY td_teachers_admin_all
  ON app.td_teachers
  USING ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin')
  WITH CHECK ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin');

CREATE POLICY td_teachers_self_select
  ON app.td_teachers
  FOR SELECT
  USING (user_id = auth.uid());

-- TD_ENROLLMENTS
ALTER TABLE app.td_enrollments ENABLE ROW LEVEL SECURITY;

CREATE POLICY td_enrollments_admin_all
  ON app.td_enrollments
  USING ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin')
  WITH CHECK ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin');

CREATE POLICY td_enrollments_student_select
  ON app.td_enrollments
  FOR SELECT
  USING (student_id = auth.uid());

CREATE POLICY td_enrollments_teacher_select
  ON app.td_enrollments
  FOR SELECT
  USING (
    assigned_teacher_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM app.td_teachers t
      WHERE t.id = assigned_teacher_id
        AND t.user_id = auth.uid()
    )
  );

-- TD_MESSAGES
ALTER TABLE app.td_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY td_messages_admin_all
  ON app.td_messages
  USING ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin')
  WITH CHECK ((current_setting('request.jwt.claims', true)::jsonb->>'role') = 'admin');

CREATE POLICY td_messages_participants_select
  ON app.td_messages
  FOR SELECT
  USING (
    sender_user_id = auth.uid()
    OR student_user_id = auth.uid()
    OR teacher_user_id = auth.uid()
  );

CREATE POLICY td_messages_participants_insert
  ON app.td_messages
  FOR INSERT
  WITH CHECK (sender_user_id = auth.uid());
