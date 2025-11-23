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
-- 7) MODULE BIBLIOTHÈQUE DE COURS (DOMAINES / UNITÉS / RESSOURCES)
-- ========================================

CREATE TABLE IF NOT EXISTS app.course_domains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    sort_order INTEGER DEFAULT 0 NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.course_domains ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_active_course_domains ON app.course_domains;
CREATE POLICY student_select_active_course_domains
ON app.course_domains FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.course_domains TO anon, authenticated;
GRANT ALL ON app.course_domains TO service_role;

CREATE TABLE IF NOT EXISTS app.course_units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain_id UUID NOT NULL REFERENCES app.course_domains (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    sort_order INTEGER DEFAULT 0 NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.course_units ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_active_course_units ON app.course_units;
CREATE POLICY student_select_active_course_units
ON app.course_units FOR SELECT
USING (
    is_active = TRUE
    AND EXISTS (
        SELECT 1
        FROM app.course_domains d
        WHERE d.id = domain_id
          AND d.is_active = TRUE
    )
);

GRANT SELECT ON app.course_units TO anon, authenticated;
GRANT ALL ON app.course_units TO service_role;

CREATE TABLE IF NOT EXISTS app.course_resources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_id UUID NOT NULL REFERENCES app.course_units (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    resource_type TEXT NOT NULL,
    storage_bucket TEXT,
    storage_path TEXT,
    external_url TEXT,
    mux_playback_id TEXT,
    sort_order INTEGER DEFAULT 0 NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.course_resources ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_active_course_resources ON app.course_resources;
CREATE POLICY student_select_active_course_resources
ON app.course_resources FOR SELECT
USING (
    is_active = TRUE
    AND EXISTS (
        SELECT 1
        FROM app.course_units u
        JOIN app.course_domains d ON d.id = u.domain_id
        WHERE u.id = unit_id
          AND u.is_active = TRUE
          AND d.is_active = TRUE
    )
);

GRANT SELECT ON app.course_resources TO anon, authenticated;
GRANT ALL ON app.course_resources TO service_role;

-- ========================================
-- 8) RPC ÉTUDIANT - BIBLIOTHÈQUE DE COURS
-- ========================================

CREATE OR REPLACE FUNCTION app_list_course_library()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'domain_id', d.id,
                'title', d.title,
                'description', d.description,
                'sort_order', d.sort_order,
                'units', COALESCE(
                    (
                        SELECT JSONB_AGG(
                                   JSONB_BUILD_OBJECT(
                                       'unit_id', u.id,
                                       'title', u.title,
                                       'description', u.description,
                                       'sort_order', u.sort_order,
                                       'resources', COALESCE(
                                           (
                                               SELECT JSONB_AGG(
                                                          JSONB_BUILD_OBJECT(
                                                              'resource_id', r.id,
                                                              'title', r.title,
                                                              'description', r.description,
                                                              'resource_type', r.resource_type,
                                                              'storage_bucket', r.storage_bucket,
                                                              'storage_path', r.storage_path,
                                                              'external_url', r.external_url,
                                                              'mux_playback_id', r.mux_playback_id,
                                                              'sort_order', r.sort_order,
                                                              'created_at', r.created_at
                                                          )
                                                          ORDER BY r.sort_order, r.created_at DESC
                                                      )
                                               FROM app.course_resources r
                                               WHERE r.unit_id = u.id
                                                 AND r.is_active = TRUE
                                           ),
                                           '[]'::JSONB
                                       )
                                   )
                                   ORDER BY u.sort_order, u.created_at DESC
                               )
                        FROM app.course_units u
                        WHERE u.domain_id = d.id
                          AND u.is_active = TRUE
                    ),
                    '[]'::JSONB
                )
            )
            ORDER BY d.sort_order, d.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.course_domains d
    WHERE d.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'domains', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_course_library() TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_course_library() TO service_role;

-- ========================================
-- 9) RPC ADMIN - GESTION BIBLIOTHÈQUE DE COURS
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_course_library()
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
                'domain_id', d.id,
                'title', d.title,
                'description', d.description,
                'sort_order', d.sort_order,
                'is_active', d.is_active,
                'units', COALESCE(
                    (
                        SELECT JSONB_AGG(
                                   JSONB_BUILD_OBJECT(
                                       'unit_id', u.id,
                                       'domain_id', u.domain_id,
                                       'title', u.title,
                                       'description', u.description,
                                       'sort_order', u.sort_order,
                                       'is_active', u.is_active,
                                       'resources', COALESCE(
                                           (
                                               SELECT JSONB_AGG(
                                                          JSONB_BUILD_OBJECT(
                                                              'resource_id', r.id,
                                                              'unit_id', r.unit_id,
                                                              'title', r.title,
                                                              'description', r.description,
                                                              'resource_type', r.resource_type,
                                                              'storage_bucket', r.storage_bucket,
                                                              'storage_path', r.storage_path,
                                                              'external_url', r.external_url,
                                                              'mux_playback_id', r.mux_playback_id,
                                                              'sort_order', r.sort_order,
                                                              'is_active', r.is_active,
                                                              'created_at', r.created_at,
                                                              'updated_at', r.updated_at
                                                          )
                                                          ORDER BY r.sort_order, r.created_at DESC
                                                      )
                                               FROM app.course_resources r
                                               WHERE r.unit_id = u.id
                                           ),
                                           '[]'::JSONB
                                       )
                                   )
                                   ORDER BY u.sort_order, u.created_at DESC
                               )
                        FROM app.course_units u
                        WHERE u.domain_id = d.id
                    ),
                    '[]'::JSONB
                )
            )
            ORDER BY d.sort_order, d.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.course_domains d;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'domains', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_course_library() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_course_library() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_course_domain(
    p_domain_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_sort_order INTEGER,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_domain_id UUID;
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

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF p_domain_id IS NULL THEN
        INSERT INTO app.course_domains (
            title,
            description,
            sort_order,
            is_active
        )
        VALUES (
            p_title,
            p_description,
            COALESCE(p_sort_order, 0),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_domain_id;
    ELSE
        UPDATE app.course_domains
        SET
            title = p_title,
            description = p_description,
            sort_order = COALESCE(p_sort_order, sort_order),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_domain_id
        RETURNING id INTO v_domain_id;
    END IF;

    IF v_domain_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'domain_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'domain_id', v_domain_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_course_domain(UUID, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_course_domain(UUID, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_course_unit(
    p_unit_id UUID,
    p_domain_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_sort_order INTEGER,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_unit_id UUID;
    v_domain_exists BOOLEAN;
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

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF p_domain_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'domain_required');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM app.course_domains d WHERE d.id = p_domain_id
    ) INTO v_domain_exists;

    IF NOT v_domain_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'domain_not_found');
    END IF;

    IF p_unit_id IS NULL THEN
        INSERT INTO app.course_units (
            domain_id,
            title,
            description,
            sort_order,
            is_active
        )
        VALUES (
            p_domain_id,
            p_title,
            p_description,
            COALESCE(p_sort_order, 0),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_unit_id;
    ELSE
        UPDATE app.course_units
        SET
            domain_id = p_domain_id,
            title = p_title,
            description = p_description,
            sort_order = COALESCE(p_sort_order, sort_order),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_unit_id
        RETURNING id INTO v_unit_id;
    END IF;

    IF v_unit_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unit_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'unit_id', v_unit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_course_unit(UUID, UUID, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_course_unit(UUID, UUID, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_course_resource(
    p_resource_id UUID,
    p_unit_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_resource_type TEXT,
    p_storage_bucket TEXT,
    p_storage_path TEXT,
    p_external_url TEXT,
    p_mux_playback_id TEXT,
    p_sort_order INTEGER,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_resource_id UUID;
    v_unit_exists BOOLEAN;
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

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF p_unit_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unit_required');
    END IF;

    IF p_resource_type IS NULL OR LENGTH(TRIM(p_resource_type)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'resource_type_required');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM app.course_units u WHERE u.id = p_unit_id
    ) INTO v_unit_exists;

    IF NOT v_unit_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unit_not_found');
    END IF;

    IF p_resource_id IS NULL THEN
        INSERT INTO app.course_resources (
            unit_id,
            title,
            description,
            resource_type,
            storage_bucket,
            storage_path,
            external_url,
            mux_playback_id,
            sort_order,
            is_active
        )
        VALUES (
            p_unit_id,
            p_title,
            p_description,
            p_resource_type,
            p_storage_bucket,
            p_storage_path,
            p_external_url,
            p_mux_playback_id,
            COALESCE(p_sort_order, 0),
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_resource_id;
    ELSE
        UPDATE app.course_resources
        SET
            unit_id = p_unit_id,
            title = p_title,
            description = p_description,
            resource_type = p_resource_type,
            storage_bucket = p_storage_bucket,
            storage_path = p_storage_path,
            external_url = p_external_url,
            mux_playback_id = p_mux_playback_id,
            sort_order = COALESCE(p_sort_order, sort_order),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE id = p_resource_id
        RETURNING id INTO v_resource_id;
    END IF;

    IF v_resource_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'resource_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'resource_id', v_resource_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_course_resource(UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_course_resource(UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;

-- ========================================
-- 10) VALIDATION RAPIDE DU MODULE COURS/EXERCICES/BIBLIOTHÈQUE
-- ========================================

SELECT
  'courses_module_status' AS check_name,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'courses')) AS courses_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'course_enrollments')) AS course_enrollments_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'exercises')) AS exercises_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'course_domains')) AS course_domains_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'course_units')) AS course_units_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'course_resources')) AS course_resources_table_exists;
