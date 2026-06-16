-- ═══════════════════════════════════════════════════════════════════════════
-- Migration: Ajouter colonnes filière/année/semestre sur td_questions
-- + Créer table td_generated_assignments pour devoirs type
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Colonnes supplémentaires sur td_questions
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS study_year TEXT;
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS semester TEXT;
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS field TEXT;
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS points INTEGER DEFAULT 10;
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS time_limit_seconds INTEGER DEFAULT 60;
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS generation_mode TEXT;
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS generated_by UUID;

-- 2. Table devoirs type générés
CREATE TABLE IF NOT EXISTS app.td_generated_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID,
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  field TEXT,
  study_year TEXT,
  semester TEXT,
  mode TEXT DEFAULT 'exam',
  question_count INTEGER DEFAULT 10,
  total_points INTEGER DEFAULT 20,
  duration_minutes INTEGER DEFAULT 60,
  questions_json JSONB,
  status TEXT DEFAULT 'generated',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Index pour filtrage rapide
CREATE INDEX IF NOT EXISTS idx_td_questions_field ON app.td_questions (field);
CREATE INDEX IF NOT EXISTS idx_td_questions_study_year ON app.td_questions (study_year);
CREATE INDEX IF NOT EXISTS idx_td_questions_semester ON app.td_questions (semester);
CREATE INDEX IF NOT EXISTS idx_td_questions_gen_mode ON app.td_questions (generation_mode);
CREATE INDEX IF NOT EXISTS idx_td_gen_assign_student ON app.td_generated_assignments (student_id);
CREATE INDEX IF NOT EXISTS idx_td_gen_assign_subject ON app.td_generated_assignments (subject);
CREATE INDEX IF NOT EXISTS idx_td_gen_assign_field ON app.td_generated_assignments (field);

-- 4. RLS sur td_generated_assignments
ALTER TABLE app.td_generated_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY td_gen_assign_select_own ON app.td_generated_assignments
  FOR SELECT TO authenticated
  USING (student_id = auth.uid() OR student_id IS NULL);

CREATE POLICY td_gen_assign_insert_own ON app.td_generated_assignments
  FOR INSERT TO authenticated
  WITH CHECK (student_id = auth.uid());

CREATE POLICY td_gen_assign_admin_all ON app.td_generated_assignments
  FOR ALL TO service_role
  USING (true);

-- 5. RPC : lister les exercices/questions TD filtrés par matière/filière/année/semestre
CREATE OR REPLACE FUNCTION public.app_td_student_list_filtered_questions(
  p_subject TEXT DEFAULT NULL,
  p_field TEXT DEFAULT NULL,
  p_study_year TEXT DEFAULT NULL,
  p_semester TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'success', true,
    'questions', COALESCE(jsonb_agg(row_to_json(q)::jsonb), '[]'::jsonb)
  )
  INTO v_result
  FROM (
    SELECT id, content, options, correct_index, explanation, difficulty,
           subject, field, study_year, semester, points, time_limit_seconds,
           generation_mode
    FROM app.td_questions
    WHERE is_active = true
      AND (p_subject IS NULL OR subject ILIKE '%' || p_subject || '%')
      AND (p_field IS NULL OR field ILIKE '%' || p_field || '%')
      AND (p_study_year IS NULL OR study_year = p_study_year)
      AND (p_semester IS NULL OR semester = p_semester)
    ORDER BY random()
    LIMIT p_limit
  ) q;

  RETURN v_result;
END;
$$;

-- 6. RPC : lister les devoirs type générés
CREATE OR REPLACE FUNCTION public.app_td_student_list_generated_assignments(
  p_subject TEXT DEFAULT NULL,
  p_field TEXT DEFAULT NULL,
  p_study_year TEXT DEFAULT NULL,
  p_semester TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'success', true,
    'assignments', COALESCE(jsonb_agg(row_to_json(a)::jsonb ORDER BY a.created_at DESC), '[]'::jsonb)
  )
  INTO v_result
  FROM (
    SELECT id, title, subject, field, study_year, semester, mode,
           question_count, total_points, duration_minutes, status, created_at
    FROM app.td_generated_assignments
    WHERE (student_id = v_uid OR student_id IS NULL)
      AND (p_subject IS NULL OR subject ILIKE '%' || p_subject || '%')
      AND (p_field IS NULL OR field ILIKE '%' || p_field || '%')
      AND (p_study_year IS NULL OR study_year = p_study_year)
      AND (p_semester IS NULL OR semester = p_semester)
    ORDER BY created_at DESC
    LIMIT p_limit
  ) a;

  RETURN v_result;
END;
$$;

-- 7. RPC : récupérer un devoir type avec ses questions
CREATE OR REPLACE FUNCTION public.app_td_student_get_generated_assignment(
  p_assignment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  SELECT row_to_json(a)::jsonb
  INTO v_result
  FROM app.td_generated_assignments a
  WHERE a.id = p_assignment_id
    AND (a.student_id = v_uid OR a.student_id IS NULL);

  IF v_result IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Devoir non trouvé');
  END IF;

  RETURN jsonb_build_object('success', true, 'assignment', v_result);
END;
$$;
