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
    bepc_year INTEGER,
    bepc_institution TEXT,
    bepc_country TEXT,
    bepc_mention TEXT,
    bac_year INTEGER,
    bac_series TEXT,
    bac_mention TEXT,
    bac_institution TEXT,
    bac_country TEXT,
    study_project_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.students ENABLE ROW LEVEL SECURITY;

-- Colonnes académiques (2.2) ajoutées de manière idempotente
ALTER TABLE app.students
    ADD COLUMN IF NOT EXISTS bepc_year INTEGER,
    ADD COLUMN IF NOT EXISTS bepc_institution TEXT,
    ADD COLUMN IF NOT EXISTS bepc_country TEXT,
    ADD COLUMN IF NOT EXISTS bepc_mention TEXT,
    ADD COLUMN IF NOT EXISTS bac_year INTEGER,
    ADD COLUMN IF NOT EXISTS bac_series TEXT,
    ADD COLUMN IF NOT EXISTS bac_mention TEXT,
    ADD COLUMN IF NOT EXISTS bac_institution TEXT,
    ADD COLUMN IF NOT EXISTS bac_country TEXT,
    ADD COLUMN IF NOT EXISTS study_project_text TEXT;

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
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_message_at TIMESTAMPTZ
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

ALTER TABLE app.applications
    ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_student_read_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_admin_read_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_university_read_at TIMESTAMPTZ;

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

-- ========================================
-- 3c) TABLE DOCUMENTS DU DOSSIER ÉTUDIANT (GLOBAL 2.1)
-- ========================================

CREATE TABLE IF NOT EXISTS app.student_dossier_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    document_type TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'uploaded',
    uploaded_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    validated_at TIMESTAMPTZ,
    validated_by UUID
);

ALTER TABLE app.student_dossier_documents ENABLE ROW LEVEL SECURITY;

-- Un étudiant ne voit et ne gère que ses propres documents de dossier
DROP POLICY IF EXISTS student_select_own_dossier_documents ON app.student_dossier_documents;
CREATE POLICY student_select_own_dossier_documents
ON app.student_dossier_documents FOR SELECT
USING (student_id = auth.uid());

DROP POLICY IF EXISTS student_insert_own_dossier_documents ON app.student_dossier_documents;
CREATE POLICY student_insert_own_dossier_documents
ON app.student_dossier_documents FOR INSERT
WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS student_update_own_dossier_documents ON app.student_dossier_documents;
CREATE POLICY student_update_own_dossier_documents
ON app.student_dossier_documents FOR UPDATE
USING (student_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON app.student_dossier_documents TO authenticated;
GRANT ALL ON app.student_dossier_documents TO service_role;

-- ========================================
-- 3c bis) CONFIGURATION STORAGE POUR DOCUMENTS ÉTUDIANTS
-- ========================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('application-files', 'application-files', FALSE)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS students_manage_own_application_files ON storage.objects;
CREATE POLICY students_manage_own_application_files
ON storage.objects
AS PERMISSIVE
FOR ALL
TO authenticated
USING (
  bucket_id = 'application-files'
)
WITH CHECK (
  bucket_id = 'application-files'
);

-- ========================================
-- 3d) RPC DOCUMENTS DU DOSSIER ÉTUDIANT (GLOBAL 2.1)
-- ========================================

CREATE OR REPLACE FUNCTION app_list_student_dossier_documents()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'not_authenticated'
        );
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', d.id,
                'student_id', d.student_id,
                'document_type', d.document_type,
                'storage_path', d.storage_path,
                'status', d.status,
                'uploaded_at', d.uploaded_at,
                'validated_at', d.validated_at
            )
            ORDER BY d.uploaded_at DESC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.student_dossier_documents d
    WHERE d.student_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'documents', v_result
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_student_dossier_documents() TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_student_dossier_documents() TO service_role;

CREATE OR REPLACE FUNCTION app_add_student_dossier_document(
    p_document_type TEXT,
    p_storage_path TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_doc_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'not_authenticated'
        );
    END IF;

    IF p_document_type IS NULL OR LENGTH(TRIM(p_document_type)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'invalid_document_type'
        );
    END IF;

    IF p_storage_path IS NULL OR LENGTH(TRIM(p_storage_path)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'invalid_storage_path'
        );
    END IF;

    INSERT INTO app.student_dossier_documents (student_id, document_type, storage_path)
    VALUES (v_user_id, p_document_type, p_storage_path)
    RETURNING id INTO v_doc_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'document_id', v_doc_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_add_student_dossier_document(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_add_student_dossier_document(TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_delete_student_dossier_document(
    p_document_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_owner_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'not_authenticated'
        );
    END IF;

    SELECT student_id
    INTO v_owner_id
    FROM app.student_dossier_documents
    WHERE id = p_document_id;

    IF v_owner_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'document_not_found'
        );
    END IF;

    IF v_owner_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'not_owner'
        );
    END IF;

    DELETE FROM app.student_dossier_documents
    WHERE id = p_document_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_delete_student_dossier_document(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_delete_student_dossier_document(UUID) TO service_role;

CREATE TABLE IF NOT EXISTS app.application_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES app.applications (id) ON DELETE CASCADE,
    sender_role TEXT NOT NULL,
    audience TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.application_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_application_messages ON app.application_messages;
CREATE POLICY student_select_own_application_messages
ON app.application_messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.applications a
    WHERE a.id = application_messages.application_id
      AND a.student_id = auth.uid()
  )
);

DROP POLICY IF EXISTS student_insert_own_application_messages ON app.application_messages;
CREATE POLICY student_insert_own_application_messages
ON app.application_messages FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.applications a
    WHERE a.id = application_messages.application_id
      AND a.student_id = auth.uid()
  )
  AND sender_role = 'student'
);

GRANT SELECT, INSERT ON app.application_messages TO authenticated;
GRANT ALL ON app.application_messages TO service_role;

-- ========================================
-- 3b) RPC FICHIERS DE CANDIDATURE
-- ========================================

CREATE OR REPLACE FUNCTION app_list_application_files(
    p_application_id UUID
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
                'id', f.id,
                'application_id', f.application_id,
                'file_type', f.file_type,
                'storage_path', f.storage_path,
                'uploaded_at', f.uploaded_at
            )
            ORDER BY f.uploaded_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.application_files f
    JOIN app.applications a ON a.id = f.application_id
    WHERE f.application_id = p_application_id
      AND a.student_id = auth.uid();

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_application_files(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_application_files(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_add_application_file(
    p_application_id UUID,
    p_file_type TEXT,
    p_storage_path TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id UUID;
    v_file_id UUID;
BEGIN
    SELECT student_id INTO v_student_id
    FROM app.applications
    WHERE id = p_application_id;

    IF v_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    IF v_student_id <> auth.uid() THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    INSERT INTO app.application_files (application_id, file_type, storage_path)
    VALUES (p_application_id, p_file_type, p_storage_path)
    RETURNING id INTO v_file_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'file_id', v_file_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_add_application_file(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_add_application_file(UUID, TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_delete_application_file(
    p_file_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_student_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'not_authenticated'
        );
    END IF;

    SELECT a.student_id
    INTO v_student_id
    FROM app.application_files f
    JOIN app.applications a ON a.id = f.application_id
    WHERE f.id = p_file_id;

    IF v_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'file_not_found'
        );
    END IF;

    IF v_student_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'not_owner'
        );
    END IF;

    DELETE FROM app.application_files
    WHERE id = p_file_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_delete_application_file(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_delete_application_file(UUID) TO service_role;

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

-- Supprimer l'ancienne version (6 paramètres) si elle existe, pour éviter les surcharges ambiguës
DROP FUNCTION IF EXISTS app_update_student_profile(
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    DATE,
    TEXT
);

CREATE OR REPLACE FUNCTION app_update_student_profile(
    p_full_name TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_country TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_date_of_birth DATE DEFAULT NULL,
    p_avatar_url TEXT DEFAULT NULL,
    p_bepc_year INTEGER DEFAULT NULL,
    p_bepc_institution TEXT DEFAULT NULL,
    p_bepc_country TEXT DEFAULT NULL,
    p_bepc_mention TEXT DEFAULT NULL,
    p_bac_year INTEGER DEFAULT NULL,
    p_bac_series TEXT DEFAULT NULL,
    p_bac_mention TEXT DEFAULT NULL,
    p_bac_institution TEXT DEFAULT NULL,
    p_bac_country TEXT DEFAULT NULL,
    p_study_project_text TEXT DEFAULT NULL
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
        bepc_year = COALESCE(p_bepc_year, bepc_year),
        bepc_institution = COALESCE(p_bepc_institution, bepc_institution),
        bepc_country = COALESCE(p_bepc_country, bepc_country),
        bepc_mention = COALESCE(p_bepc_mention, bepc_mention),
        bac_year = COALESCE(p_bac_year, bac_year),
        bac_series = COALESCE(p_bac_series, bac_series),
        bac_mention = COALESCE(p_bac_mention, bac_mention),
        bac_institution = COALESCE(p_bac_institution, bac_institution),
        bac_country = COALESCE(p_bac_country, bac_country),
        study_project_text = COALESCE(p_study_project_text, study_project_text),
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
-- 3c) RPC - STATUT DE COMPLÉTUDE DU DOSSIER (PROFIL ACADÉMIQUE 2.2)
-- ========================================

CREATE OR REPLACE FUNCTION app_is_student_dossier_complete()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile RECORD;
    v_missing_fields TEXT[] := ARRAY[]::TEXT[];
    v_missing_documents TEXT[] := ARRAY[]::TEXT[];
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'not_authenticated'
        );
    END IF;

    SELECT
        s.full_name,
        s.date_of_birth,
        s.bepc_year,
        s.bepc_institution,
        s.bepc_country,
        s.bepc_mention,
        s.bac_year,
        s.bac_series,
        s.bac_mention,
        s.bac_institution,
        s.bac_country,
        s.study_project_text
    INTO v_profile
    FROM app.students s
    WHERE s.id = v_user_id;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'student_profile_not_found'
        );
    END IF;

    -- Champs obligatoires du profil académique (2.2)
    IF COALESCE(v_profile.full_name, '') = '' THEN
        v_missing_fields := v_missing_fields || 'full_name';
    END IF;
    IF v_profile.date_of_birth IS NULL THEN
        v_missing_fields := v_missing_fields || 'date_of_birth';
    END IF;
    IF v_profile.bepc_year IS NULL THEN
        v_missing_fields := v_missing_fields || 'bepc_year';
    END IF;
    IF COALESCE(v_profile.bepc_institution, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bepc_institution';
    END IF;
    IF COALESCE(v_profile.bepc_country, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bepc_country';
    END IF;
    IF COALESCE(v_profile.bepc_mention, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bepc_mention';
    END IF;
    IF v_profile.bac_year IS NULL THEN
        v_missing_fields := v_missing_fields || 'bac_year';
    END IF;
    IF COALESCE(v_profile.bac_series, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bac_series';
    END IF;
    IF COALESCE(v_profile.bac_mention, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bac_mention';
    END IF;
    IF COALESCE(v_profile.bac_institution, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bac_institution';
    END IF;
    IF COALESCE(v_profile.bac_country, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bac_country';
    END IF;
    IF COALESCE(v_profile.study_project_text, '') = '' THEN
        v_missing_fields := v_missing_fields || 'study_project_text';
    END IF;

    -- Pour l'instant, les documents 2.1 ne sont pas bloquants dans le calcul
    -- v_missing_documents reste vide jusqu'à ce que l'UI de dossier soit en place.

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'is_complete',
            (COALESCE(array_length(v_missing_fields, 1), 0) = 0
             AND COALESCE(array_length(v_missing_documents, 1), 0) = 0),
        'missing_fields', COALESCE(
            (SELECT TO_JSONB(v_missing_fields)), '[]'::JSONB
        ),
        'missing_documents', COALESCE(
            (SELECT TO_JSONB(v_missing_documents)), '[]'::JSONB
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_is_student_dossier_complete() TO authenticated;
GRANT EXECUTE ON FUNCTION app_is_student_dossier_complete() TO service_role;

CREATE OR REPLACE FUNCTION app_list_application_messages_for_student(
    p_application_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'application_id', m.application_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.application_messages m
    JOIN app.applications a ON a.id = m.application_id
    WHERE m.application_id = p_application_id
      AND a.student_id = v_user_id
      AND (m.sender_role = 'student' OR m.audience = 'student');

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_application_messages_for_student(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_application_messages_for_student(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_add_application_message_from_student(
    p_application_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_app_student_id UUID;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT student_id INTO v_app_student_id
    FROM app.applications
    WHERE id = p_application_id;

    IF v_app_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    IF v_app_student_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'student', 'admin_only', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_add_application_message_from_student(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_add_application_message_from_student(UUID, TEXT) TO service_role;

-- ========================================
-- 3e) RPC MESSAGES - ADMIN & UNIVERSITÉ
-- ========================================

-- Admin : lister toutes les candidatures avec activité de messages
CREATE OR REPLACE FUNCTION app_list_admin_applications()
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
                'id', a.id,
                'status', a.status,
                'motivation_text', a.motivation_text,
                'submitted_at', a.submitted_at,
                'created_at', a.created_at,
                'updated_at', a.updated_at,
                'last_message_at', a.last_message_at,
                'last_student_read_at', a.last_student_read_at,
                'last_admin_read_at', a.last_admin_read_at,
                'last_university_read_at', a.last_university_read_at,
                'student_id', s.id,
                'student_full_name', s.full_name,
                'program_id', p.id,
                'program_title', p.title,
                'degree_level', p.degree_level,
                'university_id', u.id,
                'university_name', u.name,
                'last_activity_at', GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at)),
                'has_unread_for_admin',
                    CASE
                        WHEN a.last_message_at IS NULL THEN FALSE
                        WHEN a.last_admin_read_at IS NULL THEN TRUE
                        ELSE a.last_message_at > a.last_admin_read_at
                    END
            )
            ORDER BY GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at)) DESC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.applications a
    JOIN app.students s ON s.id = a.student_id
    JOIN app.programs p ON p.id = a.program_id
    JOIN app.universities u ON u.id = p.university_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'applications', v_result
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_admin_applications() TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_admin_applications() TO service_role;

-- Admin : lister tous les messages d'une candidature
CREATE OR REPLACE FUNCTION app_list_application_messages_for_admin(
    p_application_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
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

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'application_id', m.application_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.application_messages m
    WHERE m.application_id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'messages', v_result
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_application_messages_for_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_application_messages_for_admin(UUID) TO service_role;

-- Admin : envoyer un message vers l'étudiant
CREATE OR REPLACE FUNCTION app_add_application_message_from_admin_to_student(
    p_application_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_message_id UUID;
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

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'admin', 'student', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_add_application_message_from_admin_to_student(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_add_application_message_from_admin_to_student(UUID, TEXT) TO service_role;

-- Admin : envoyer un message vers l'université
CREATE OR REPLACE FUNCTION app_add_application_message_from_admin_to_university(
    p_application_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_message_id UUID;
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

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'admin', 'university', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_add_application_message_from_admin_to_university(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_add_application_message_from_admin_to_university(UUID, TEXT) TO service_role;

-- Admin : marquer les messages d'une candidature comme lus
CREATE OR REPLACE FUNCTION app_mark_application_messages_read_for_admin(
    p_application_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
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

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    UPDATE app.applications
    SET last_admin_read_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_mark_application_messages_read_for_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_mark_application_messages_read_for_admin(UUID) TO service_role;

-- Université : lister les candidatures liées à ses programmes
CREATE OR REPLACE FUNCTION app_list_university_applications()
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
                'id', a.id,
                'status', a.status,
                'motivation_text', a.motivation_text,
                'submitted_at', a.submitted_at,
                'created_at', a.created_at,
                'updated_at', a.updated_at,
                'last_message_at', a.last_message_at,
                'last_student_read_at', a.last_student_read_at,
                'last_admin_read_at', a.last_admin_read_at,
                'last_university_read_at', a.last_university_read_at,
                'student_id', s.id,
                'student_full_name', s.full_name,
                'program_id', p.id,
                'program_title', p.title,
                'degree_level', p.degree_level,
                'university_id', u.id,
                'university_name', u.name,
                'last_activity_at', GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at)),
                'has_unread_for_university',
                    CASE
                        WHEN a.last_message_at IS NULL THEN FALSE
                        WHEN a.last_university_read_at IS NULL THEN TRUE
                        ELSE a.last_message_at > a.last_university_read_at
                    END
            )
            ORDER BY GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at)) DESC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.applications a
    JOIN app.students s ON s.id = a.student_id
    JOIN app.programs p ON p.id = a.program_id
    JOIN app.universities u ON u.id = p.university_id
    WHERE u.id = v_university_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'applications', v_result
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_university_applications() TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_university_applications() TO service_role;

-- Université : lister les messages visibles pour elle sur une candidature
CREATE OR REPLACE FUNCTION app_list_application_messages_for_university(
    p_application_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_exists BOOLEAN;
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

    SELECT EXISTS(
        SELECT 1
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        WHERE a.id = p_application_id
          AND p.university_id = v_university_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'application_id', m.application_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.application_messages m
    JOIN app.applications a ON a.id = m.application_id
    JOIN app.programs p ON p.id = a.program_id
    WHERE m.application_id = p_application_id
      AND p.university_id = v_university_id
      AND (m.audience = 'university' OR m.sender_role = 'university');

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'messages', v_result
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_application_messages_for_university(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_application_messages_for_university(UUID) TO service_role;

-- Université : envoyer un message vers l'admin (jamais directement à l'étudiant)
CREATE OR REPLACE FUNCTION app_add_application_message_from_university(
    p_application_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_exists BOOLEAN;
    v_message_id UUID;
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

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS(
        SELECT 1
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        WHERE a.id = p_application_id
          AND p.university_id = v_university_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'university', 'admin_only', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_add_application_message_from_university(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_add_application_message_from_university(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_university_update_application_status(
    p_application_id UUID,
    p_new_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_exists BOOLEAN;
    v_app_id UUID;
    v_status TEXT;
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

    IF p_new_status IS NULL OR LENGTH(TRIM(p_new_status)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    IF p_new_status NOT IN ('under_review', 'accepted', 'rejected', 'canceled') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unsupported_status');
    END IF;

    SELECT EXISTS(
        SELECT 1
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        WHERE a.id = p_application_id
          AND p.university_id = v_university_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    UPDATE app.applications a
    SET status = p_new_status,
        updated_at = NOW()
    WHERE a.id = p_application_id
    RETURNING a.id, a.status INTO v_app_id, v_status;

    IF v_app_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'application_id', v_app_id,
        'status', v_status
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_university_update_application_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_university_update_application_status(UUID, TEXT) TO service_role;

-- Université : marquer les messages d'une candidature comme lus
CREATE OR REPLACE FUNCTION app_mark_application_messages_read_for_university(
    p_application_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_exists BOOLEAN;
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

    SELECT EXISTS(
        SELECT 1
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        WHERE a.id = p_application_id
          AND p.university_id = v_university_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    UPDATE app.applications
    SET last_university_read_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_mark_application_messages_read_for_university(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_mark_application_messages_read_for_university(UUID) TO service_role;

-- Étudiant : marquer les messages d'une candidature comme lus
CREATE OR REPLACE FUNCTION app_mark_application_messages_read_for_student(
    p_application_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_owner_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT student_id INTO v_owner_id
    FROM app.applications
    WHERE id = p_application_id;

    IF v_owner_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    IF v_owner_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    UPDATE app.applications
    SET last_student_read_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_mark_application_messages_read_for_student(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_mark_application_messages_read_for_student(UUID) TO service_role;

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
                'updated_at', a.updated_at,
                'last_message_at', a.last_message_at,
                'has_unread_for_student',
                    CASE
                        WHEN a.last_message_at IS NULL THEN FALSE
                        WHEN a.last_student_read_at IS NULL THEN TRUE
                        ELSE a.last_message_at > a.last_student_read_at
                    END
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
    v_dossier_status JSONB;
BEGIN
    -- Récupérer l'étudiant correspondant à l'utilisateur connecté
    SELECT id INTO v_student_id
    FROM app.students
    WHERE id = auth.uid();

    IF v_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'Profil étudiant introuvable'
        );
    END IF;

    -- Vérifier que le dossier de candidature (profil académique 2.2) est complet
    v_dossier_status := app_is_student_dossier_complete();

    IF COALESCE(v_dossier_status->>'success', 'false') <> 'true' THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'verification_failed',
            'details', v_dossier_status
        );
    END IF;

    IF (v_dossier_status->>'is_complete')::BOOLEAN IS NOT TRUE THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'dossier_incomplete',
            'details', v_dossier_status
        );
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

CREATE OR REPLACE FUNCTION app_get_university_application_detail(
    p_application_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_app RECORD;
    v_student RECORD;
    v_program RECORD;
    v_university RECORD;
    v_app_files JSONB;
    v_dossier_docs JSONB;
    v_missing_fields TEXT[] := ARRAY[]::TEXT[];
    v_is_complete BOOLEAN;
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

    SELECT a.*
    INTO v_app
    FROM app.applications a
    JOIN app.programs p ON p.id = a.program_id
    WHERE a.id = p_application_id
      AND p.university_id = v_university_id;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    SELECT s.*
    INTO v_student
    FROM app.students s
    WHERE s.id = v_app.student_id;

    SELECT p.*
    INTO v_program
    FROM app.programs p
    WHERE p.id = v_app.program_id;

    SELECT u.*
    INTO v_university
    FROM app.universities u
    WHERE u.id = v_program.university_id
      AND u.id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', f.id,
                'application_id', f.application_id,
                'file_type', f.file_type,
                'storage_path', f.storage_path,
                'uploaded_at', f.uploaded_at
            )
            ORDER BY f.uploaded_at DESC
        ),
        '[]'::JSONB
    )
    INTO v_app_files
    FROM app.application_files f
    WHERE f.application_id = p_application_id;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', d.id,
                'student_id', d.student_id,
                'document_type', d.document_type,
                'storage_path', d.storage_path,
                'status', d.status,
                'uploaded_at', d.uploaded_at,
                'validated_at', d.validated_at
            )
            ORDER BY d.uploaded_at DESC
        ),
        '[]'::JSONB
    )
    INTO v_dossier_docs
    FROM app.student_dossier_documents d
    WHERE d.student_id = v_student.id;

    IF COALESCE(v_student.full_name, '') = '' THEN
        v_missing_fields := v_missing_fields || 'full_name';
    END IF;
    IF v_student.date_of_birth IS NULL THEN
        v_missing_fields := v_missing_fields || 'date_of_birth';
    END IF;
    IF v_student.bepc_year IS NULL THEN
        v_missing_fields := v_missing_fields || 'bepc_year';
    END IF;
    IF COALESCE(v_student.bepc_institution, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bepc_institution';
    END IF;
    IF COALESCE(v_student.bepc_country, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bepc_country';
    END IF;
    IF COALESCE(v_student.bepc_mention, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bepc_mention';
    END IF;
    IF v_student.bac_year IS NULL THEN
        v_missing_fields := v_missing_fields || 'bac_year';
    END IF;
    IF COALESCE(v_student.bac_series, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bac_series';
    END IF;
    IF COALESCE(v_student.bac_mention, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bac_mention';
    END IF;
    IF COALESCE(v_student.bac_institution, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bac_institution';
    END IF;
    IF COALESCE(v_student.bac_country, '') = '' THEN
        v_missing_fields := v_missing_fields || 'bac_country';
    END IF;
    IF COALESCE(v_student.study_project_text, '') = '' THEN
        v_missing_fields := v_missing_fields || 'study_project_text';
    END IF;

    v_is_complete := COALESCE(array_length(v_missing_fields, 1), 0) = 0;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'application', JSONB_BUILD_OBJECT(
            'id', v_app.id,
            'status', v_app.status,
            'motivation_text', v_app.motivation_text,
            'submitted_at', v_app.submitted_at,
            'created_at', v_app.created_at,
            'updated_at', v_app.updated_at,
            'last_message_at', v_app.last_message_at,
            'last_student_read_at', v_app.last_student_read_at,
            'last_admin_read_at', v_app.last_admin_read_at,
            'last_university_read_at', v_app.last_university_read_at
        ),
        'student_profile', JSONB_BUILD_OBJECT(
            'id', v_student.id,
            'full_name', v_student.full_name,
            'phone', v_student.phone,
            'country', v_student.country,
            'city', v_student.city,
            'date_of_birth', v_student.date_of_birth,
            'bepc_year', v_student.bepc_year,
            'bepc_institution', v_student.bepc_institution,
            'bepc_country', v_student.bepc_country,
            'bepc_mention', v_student.bepc_mention,
            'bac_year', v_student.bac_year,
            'bac_series', v_student.bac_series,
            'bac_mention', v_student.bac_mention,
            'bac_institution', v_student.bac_institution,
            'bac_country', v_student.bac_country,
            'study_project_text', v_student.study_project_text
        ),
        'student_dossier_status', JSONB_BUILD_OBJECT(
            'is_complete', v_is_complete,
            'missing_fields', COALESCE(
                (SELECT TO_JSONB(v_missing_fields)), '[]'::JSONB
            )
        ),
        'application_files', v_app_files,
        'dossier_documents', v_dossier_docs,
        'program', JSONB_BUILD_OBJECT(
            'id', v_program.id,
            'title', v_program.title,
            'description', v_program.description,
            'degree_level', v_program.degree_level,
            'mode', v_program.mode,
            'duration_months', v_program.duration_months,
            'tuition_fees', v_program.tuition_fees
        ),
        'university', JSONB_BUILD_OBJECT(
            'id', v_university.id,
            'name', v_university.name,
            'slug', v_university.slug,
            'country', v_university.country,
            'city', v_university.city,
            'website_url', v_university.website_url
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_get_university_application_detail(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_get_university_application_detail(UUID) TO service_role;

-- ========================================
-- 6) VALIDATION RAPIDE DU MODULE
-- ========================================

-- Vérifier l'existence des tables principales
SELECT
  'student_module_status' AS check_name,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'students')) AS students_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'applications')) AS applications_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'application_files')) AS application_files_table_exists;
