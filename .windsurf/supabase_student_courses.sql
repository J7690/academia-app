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
    credits INTEGER,
    prerequisites TEXT,
    instructor TEXT,
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

ALTER TABLE app.courses
    ADD COLUMN IF NOT EXISTS credits INTEGER,
    ADD COLUMN IF NOT EXISTS prerequisites TEXT,
    ADD COLUMN IF NOT EXISTS instructor TEXT;

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

CREATE OR REPLACE FUNCTION app_list_university_courses_for_management()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'program_id', c.program_id,
                'title', c.title,
                'description', c.description,
                'credits', c.credits,
                'prerequisites', c.prerequisites,
                'instructor', c.instructor,
                'is_active', c.is_active,
                'created_at', c.created_at,
                'updated_at', c.updated_at
            )
            ORDER BY c.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.courses c
    JOIN app.programs p ON p.id = c.program_id
    WHERE p.university_id = v_university_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'courses', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_university_courses_for_management() TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_university_courses_for_management() TO service_role;

CREATE OR REPLACE FUNCTION app_upsert_university_course(
    p_course_id UUID,
    p_program_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_credits INTEGER,
    p_prerequisites TEXT,
    p_instructor TEXT,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_course_id UUID;
    v_program_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF p_course_id IS NULL AND p_program_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'program_required');
    END IF;

    IF p_program_id IS NOT NULL THEN
        SELECT id
        INTO v_program_id
        FROM app.programs
        WHERE id = p_program_id
          AND university_id = v_university_id;

        IF v_program_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'program_not_found');
        END IF;
    END IF;

    IF p_course_id IS NULL THEN
        INSERT INTO app.courses (
            program_id,
            title,
            description,
            credits,
            prerequisites,
            instructor,
            is_active
        )
        VALUES (
            COALESCE(v_program_id, p_program_id),
            p_title,
            p_description,
            p_credits,
            p_prerequisites,
            p_instructor,
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_course_id;
    ELSE
        UPDATE app.courses c
        SET
            program_id = COALESCE(v_program_id, c.program_id),
            title = p_title,
            description = p_description,
            credits = p_credits,
            prerequisites = p_prerequisites,
            instructor = p_instructor,
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        FROM app.programs p
        WHERE c.id = p_course_id
          AND c.program_id = p.id
          AND p.university_id = v_university_id
        RETURNING c.id INTO v_course_id;
    END IF;

    IF v_course_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'course_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'course_id', v_course_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_upsert_university_course(UUID, UUID, TEXT, TEXT, INTEGER, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_upsert_university_course(UUID, UUID, TEXT, TEXT, INTEGER, TEXT, TEXT, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_list_all_courses()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'program_id', p.id,
                'program_title', p.title,
                'university_id', u.id,
                'university_name', u.name,
                'university_slug', u.slug,
                'title', c.title,
                'description', c.description,
                'credits', c.credits,
                'prerequisites', c.prerequisites,
                'instructor', c.instructor,
                'is_active', c.is_active,
                'created_at', c.created_at,
                'updated_at', c.updated_at
            )
            ORDER BY u.name ASC, p.title ASC, c.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.courses c
    JOIN app.programs p ON p.id = c.program_id
    JOIN app.universities u ON u.id = p.university_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'courses', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_all_courses() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_all_courses() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_update_course_status(
    p_course_id UUID,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_course_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    UPDATE app.courses
    SET
        is_active = COALESCE(p_is_active, is_active),
        updated_at = NOW()
    WHERE id = p_course_id
    RETURNING id INTO v_course_id;

    IF v_course_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'course_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'course_id', v_course_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_update_course_status(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_update_course_status(UUID, BOOLEAN) TO service_role;

-- ========================================
-- 6) VALIDATION RAPIDE DU MODULE COURS/EXERCICES
-- ========================================

SELECT
  'courses_module_status' AS check_name,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'courses')) AS courses_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'course_enrollments')) AS course_enrollments_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'exercises')) AS exercises_table_exists;
