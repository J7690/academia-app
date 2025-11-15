-- ========================================
-- ACADEMIA - MODULE ÉTUDIANT / CANDIDATURES
-- Création des tables app.students, app.applications, app.application_files
-- + RPC métiers pour l'étudiant (liste & création de candidatures)
-- ========================================

-- 0) Schéma applicatif
CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE PROFIL ÉTUDIANT
-- ========================================

CREATE TABLE IF NOT EXISTS app.students (
    id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    country TEXT,
    city TEXT,
    date_of_birth DATE,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.students ENABLE ROW LEVEL SECURITY;

-- Un étudiant ne voit que son propre profil
DROP POLICY IF EXISTS student_select_own_profile ON app.students;
CREATE POLICY student_select_own_profile
ON app.students FOR SELECT
USING (id = auth.uid());

DROP POLICY IF EXISTS student_update_own_profile ON app.students;
CREATE POLICY student_update_own_profile
ON app.students FOR UPDATE
USING (id = auth.uid());

-- service_role garde tous les droits via rôle système
GRANT SELECT, INSERT, UPDATE, DELETE ON app.students TO authenticated;
GRANT ALL ON app.students TO service_role;

-- ========================================
-- 2) TABLE CANDIDATURES
-- ========================================

CREATE TABLE IF NOT EXISTS app.applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    program_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft',
    motivation_text TEXT,
    submitted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.applications ENABLE ROW LEVEL SECURITY;

-- Un étudiant ne voit que ses propres candidatures
DROP POLICY IF EXISTS student_select_own_applications ON app.applications;
CREATE POLICY student_select_own_applications
ON app.applications FOR SELECT
USING (student_id = auth.uid());

DROP POLICY IF EXISTS student_insert_own_applications ON app.applications;
CREATE POLICY student_insert_own_applications
ON app.applications FOR INSERT
WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS student_update_own_applications ON app.applications;
CREATE POLICY student_update_own_applications
ON app.applications FOR UPDATE
USING (student_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON app.applications TO authenticated;
GRANT ALL ON app.applications TO service_role;

-- ========================================
-- 3) TABLE FICHIERS DE CANDIDATURE
-- ========================================

CREATE TABLE IF NOT EXISTS app.application_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES app.applications (id) ON DELETE CASCADE,
    file_type TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    uploaded_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.application_files ENABLE ROW LEVEL SECURITY;

-- Un étudiant ne voit que les fichiers de ses propres candidatures
DROP POLICY IF EXISTS student_select_own_application_files ON app.application_files;
CREATE POLICY student_select_own_application_files
ON app.application_files FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.applications a
    WHERE a.id = application_files.application_id
      AND a.student_id = auth.uid()
  )
);

DROP POLICY IF EXISTS student_insert_own_application_files ON app.application_files;
CREATE POLICY student_insert_own_application_files
ON app.application_files FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.applications a
    WHERE a.id = application_files.application_id
      AND a.student_id = auth.uid()
  )
);

GRANT SELECT, INSERT ON app.application_files TO authenticated;
GRANT ALL ON app.application_files TO service_role;

CREATE OR REPLACE FUNCTION app_ensure_student_profile()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_email TEXT;
    v_full_name TEXT;
    v_exists BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT email,
            COALESCE(raw_user_meta_data->>'full_name', email)
    INTO v_email, v_full_name
    FROM auth.users
    WHERE id = v_user_id;

    IF v_email IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'user_not_found');
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM app.students s WHERE s.id = v_user_id
    ) INTO v_exists;

    IF v_exists THEN
        UPDATE app.students
        SET full_name = COALESCE(full_name, v_full_name),
            updated_at = NOW()
        WHERE id = v_user_id;
    ELSE
        INSERT INTO app.students (id, full_name)
        VALUES (v_user_id, v_full_name);
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'student_id', v_user_id,
        'full_name', v_full_name
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_ensure_student_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION app_ensure_student_profile() TO service_role;

CREATE OR REPLACE FUNCTION app_get_student_profile()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile JSONB;
BEGIN
    PERFORM app_ensure_student_profile();

    SELECT TO_JSONB(s)
    INTO v_profile
    FROM app.students s
    WHERE s.id = auth.uid();

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION app_get_student_profile TO authenticated;
GRANT EXECUTE ON FUNCTION app_get_student_profile TO service_role;

CREATE OR REPLACE FUNCTION app_update_student_profile(
    p_full_name TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_country TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_date_of_birth DATE DEFAULT NULL,
    p_avatar_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    UPDATE app.students
    SET
        full_name = COALESCE(p_full_name, full_name),
        phone = COALESCE(p_phone, phone),
        country = COALESCE(p_country, country),
        city = COALESCE(p_city, city),
        date_of_birth = COALESCE(p_date_of_birth, date_of_birth),
        avatar_url = COALESCE(p_avatar_url, avatar_url),
        updated_at = NOW()
    WHERE id = v_user_id;

    SELECT TO_JSONB(s)
    INTO v_profile
    FROM app.students s
    WHERE s.id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'profile', v_profile);
END;
$$;

GRANT EXECUTE ON FUNCTION app_update_student_profile TO authenticated;
GRANT EXECUTE ON FUNCTION app_update_student_profile TO service_role;

-- ========================================
-- 4) RPC - LISTER LES CANDIDATURES DE L'ÉTUDIANT
-- ========================================

CREATE OR REPLACE FUNCTION app_list_student_applications()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Retourner les candidatures de l'étudiant courant
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', a.id,
                'program_id', a.program_id,
                'status', a.status,
                'motivation_text', a.motivation_text,
                'submitted_at', a.submitted_at,
                'created_at', a.created_at,
                'updated_at', a.updated_at
            )
            ORDER BY a.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.applications a
    WHERE a.student_id = auth.uid();

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_student_applications TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_student_applications TO service_role;

-- ========================================
-- 5) RPC - CRÉER UNE CANDIDATURE POUR L'ÉTUDIANT COURANT
-- ========================================

CREATE OR REPLACE FUNCTION app_create_application(
    p_program_id UUID,
    p_motivation_text TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id UUID;
    v_application_id UUID;
BEGIN
    -- Récupérer l'étudiant correspondant à l'utilisateur connecté
    SELECT id INTO v_student_id
    FROM app.students
    WHERE id = auth.uid();

    IF v_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('error', 'Profil étudiant introuvable');
    END IF;

    -- Créer la candidature
    INSERT INTO app.applications (student_id, program_id, status, motivation_text, submitted_at)
    VALUES (v_student_id, p_program_id, 'submitted', p_motivation_text, NOW())
    RETURNING id INTO v_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'application_id', v_application_id,
        'status', 'submitted'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION app_create_application(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_create_application(UUID, TEXT) TO service_role;

-- ========================================
-- 6) VALIDATION RAPIDE DU MODULE
-- ========================================

-- Vérifier l'existence des tables principales
SELECT
  'student_module_status' AS check_name,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'students')) AS students_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'applications')) AS applications_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'application_files')) AS application_files_table_exists;
