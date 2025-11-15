-- ========================================
-- ACADEMIA - MODULE ÉTUDIANT / COURS & EXERCICES
-- Tables app.courses, app.course_enrollments, app.exercises
-- + RPC pour l'étudiant : app_list_student_courses, app_list_course_exercises
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE COURS
-- ========================================

CREATE TABLE IF NOT EXISTS app.courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.courses ENABLE ROW LEVEL SECURITY;

-- Lecture publique des cours actifs (les détails d'accès fins pourront être affinés par rôle plus tard)
DROP POLICY IF EXISTS public_select_active_courses ON app.courses;
CREATE POLICY public_select_active_courses
ON app.courses FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.courses TO anon, authenticated;
GRANT ALL ON app.courses TO service_role;

-- ========================================
-- 2) TABLE INSCRIPTIONS AUX COURS
-- ========================================

CREATE TABLE IF NOT EXISTS app.course_enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES app.courses (id) ON DELETE CASCADE,
    enrolled_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE (student_id, course_id)
);

ALTER TABLE app.course_enrollments ENABLE ROW LEVEL SECURITY;

-- L'étudiant ne voit que ses propres inscriptions
DROP POLICY IF EXISTS student_select_own_enrollments ON app.course_enrollments;
CREATE POLICY student_select_own_enrollments
ON app.course_enrollments FOR SELECT
USING (student_id = auth.uid());

DROP POLICY IF EXISTS student_insert_own_enrollments ON app.course_enrollments;
CREATE POLICY student_insert_own_enrollments
ON app.course_enrollments FOR INSERT
WITH CHECK (student_id = auth.uid());

GRANT SELECT, INSERT ON app.course_enrollments TO authenticated;
GRANT ALL ON app.course_enrollments TO service_role;

-- ========================================
-- 3) TABLE EXERCICES
-- ========================================

CREATE TABLE IF NOT EXISTS app.exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES app.courses (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    resource_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.exercises ENABLE ROW LEVEL SECURITY;

-- Lecture des exercices des cours visibles (pour l'instant, on autorise authenticated)
DROP POLICY IF EXISTS student_select_course_exercises ON app.exercises;
CREATE POLICY student_select_course_exercises
ON app.exercises FOR SELECT
USING (TRUE);

GRANT SELECT ON app.exercises TO authenticated;
GRANT ALL ON app.exercises TO service_role;

-- ========================================
-- 4) RPC - LISTE DES COURS D'UN ÉTUDIANT
-- ========================================

CREATE OR REPLACE FUNCTION app_list_student_courses()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'course_id', c.id,
                'title', c.title,
                'description', c.description,
                'program_id', c.program_id,
                'enrolled_at', e.enrolled_at
            )
            ORDER BY e.enrolled_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.course_enrollments e
    JOIN app.courses c ON c.id = e.course_id
    WHERE e.student_id = auth.uid();

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_student_courses TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_student_courses TO service_role;

-- ========================================
-- 5) RPC - LISTE DES EXERCICES D'UN COURS
-- ========================================

CREATE OR REPLACE FUNCTION app_list_course_exercises(
    p_course_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'exercise_id', e.id,
                'title', e.title,
                'description', e.description,
                'resource_url', e.resource_url,
                'created_at', e.created_at
            )
            ORDER BY e.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.exercises e
    WHERE e.course_id = p_course_id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_course_exercises(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_course_exercises(UUID) TO service_role;

-- ========================================
-- 6) VALIDATION RAPIDE DU MODULE COURS/EXERCICES
-- ========================================

SELECT
  'courses_module_status' AS check_name,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'courses')) AS courses_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'course_enrollments')) AS course_enrollments_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'exercises')) AS exercises_table_exists;
