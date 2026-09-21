-- Correction du 21/09/2026 : le telephone et le WhatsApp ne sont PLUS
-- exiges dans le dossier d'identite, mais dans le formulaire de candidature.
--
-- Raison : le mecanisme "aller remplir son profil" est abandonne depuis
-- longtemps. Le candidat renseigne ses contacts au moment ou il choisit
-- sa filiere, son niveau et son taux de courtage — directement dans la
-- boite de dialogue de candidature.
--
-- Ce que fait cette migration :
--   1. app_is_student_dossier_complete : ne verifie plus phone/whatsapp.
--   2. app_create_application : accepte p_phone et p_whatsapp_phone,
--      les rend obligatoires, et met a jour app.students.
--   3. app_get_university_application_detail : n'affiche plus phone/whatsapp
--      comme des manquants du dossier (mais continue de les exposer dans
--      student_profile).
--   4. Laisse app.students.phone et app.students.whatsapp_phone inchanges,
--      car ils sont utilises ailleurs (recus, affichage profil).

BEGIN;

-- ============================================================
-- 1. Dossier : seuls full_name et last_diploma restent exiges
-- ============================================================
CREATE OR REPLACE FUNCTION public.app_is_student_dossier_complete()
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
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT s.full_name, s.last_diploma
    INTO v_profile
    FROM app.students s
    WHERE s.id = v_user_id;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'student_profile_not_found');
    END IF;

    IF COALESCE(v_profile.full_name, '') = '' THEN
        v_missing_fields := array_append(v_missing_fields, 'full_name');
    END IF;
    IF COALESCE(v_profile.last_diploma, '') = '' THEN
        v_missing_fields := array_append(v_missing_fields, 'last_diploma');
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'is_complete', COALESCE(array_length(v_missing_fields, 1), 0) = 0,
        'missing_fields', TO_JSONB(v_missing_fields),
        'missing_documents', TO_JSONB(v_missing_documents)
    );
END;
$$;

-- ============================================================
-- 2. Creation de candidature : p_phone et p_whatsapp_phone obligatoires
-- ============================================================
DROP FUNCTION IF EXISTS public.app_create_application(
    UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TEXT
);

CREATE OR REPLACE FUNCTION public.app_create_application(
    p_program_id            UUID,
    p_motivation_text       TEXT DEFAULT NULL,
    p_requested_degree_level TEXT DEFAULT NULL,
    p_requested_study_mode  TEXT DEFAULT NULL,
    p_requested_schedule    TEXT DEFAULT NULL,
    p_discount_requested    BOOLEAN DEFAULT NULL,
    p_discount_details      TEXT DEFAULT NULL,
    p_student_comment       TEXT DEFAULT NULL,
    p_phone                 TEXT DEFAULT NULL,
    p_whatsapp_phone        TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_student_id UUID;
    v_application_id UUID;
    v_dossier_status JSONB;
    v_phone TEXT;
    v_whatsapp TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT id INTO v_student_id
    FROM app.students
    WHERE id = auth.uid();

    IF v_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'student_profile_not_found'
        );
    END IF;

    -- Les contacts sont obligatoires au moment de la candidature.
    v_phone := NULLIF(TRIM(p_phone), '');
    v_whatsapp := NULLIF(TRIM(p_whatsapp_phone), '');

    IF v_phone IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_phone');
    END IF;
    IF v_whatsapp IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_whatsapp_phone');
    END IF;

    -- La validation legere (>= 8 chiffres) reste cote client ; ici on garde
    -- une validation minimale pour eviter les chaines vides truquees.
    IF LENGTH(REGEXP_REPLACE(v_phone, '[^0-9]', '', 'g')) < 8 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_phone');
    END IF;
    IF LENGTH(REGEXP_REPLACE(v_whatsapp, '[^0-9]', '', 'g')) < 8 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_whatsapp_phone');
    END IF;

    -- Verification du dossier (full_name + last_diploma uniquement).
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

    -- Met a jour les contacts de l'etudiant.
    UPDATE app.students
    SET phone = v_phone,
        whatsapp_phone = v_whatsapp,
        updated_at = NOW()
    WHERE id = v_student_id;

    -- Cree la candidature.
    INSERT INTO app.applications (
        student_id,
        program_id,
        status,
        motivation_text,
        submitted_at,
        requested_degree_level,
        requested_study_mode,
        requested_schedule,
        discount_requested,
        discount_details,
        student_comment
    )
    VALUES (
        v_student_id,
        p_program_id,
        'submitted',
        p_motivation_text,
        NOW(),
        p_requested_degree_level,
        p_requested_study_mode,
        p_requested_schedule,
        COALESCE(p_discount_requested, FALSE),
        p_discount_details,
        p_student_comment
    )
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

-- ============================================================
-- 3. Vue universite : phone/whatsapp ne sont plus des manquants du dossier
-- ============================================================
CREATE OR REPLACE FUNCTION public.app_get_university_application_detail(
    p_application_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
      AND p.university_id = v_university_id
      AND a.sent_to_university = TRUE;

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

    -- Aligne sur app_is_student_dossier_complete : full_name + last_diploma.
    IF COALESCE(v_student.full_name, '') = '' THEN
        v_missing_fields := array_append(v_missing_fields, 'full_name');
    END IF;
    IF COALESCE(v_student.last_diploma, '') = '' THEN
        v_missing_fields := array_append(v_missing_fields, 'last_diploma');
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
            'sent_to_university', v_app.sent_to_university,
            'sent_to_university_at', v_app.sent_to_university_at,
            'requested_degree_level', v_app.requested_degree_level,
            'requested_study_mode', v_app.requested_study_mode,
            'requested_schedule', v_app.requested_schedule,
            'discount_requested', v_app.discount_requested,
            'discount_details', v_app.discount_details,
            'student_comment', v_app.student_comment,
            'last_message_at', v_app.last_message_at,
            'last_student_read_at', v_app.last_student_read_at,
            'last_admin_read_at', v_app.last_admin_read_at,
            'last_university_read_at', v_app.last_university_read_at
        ),
        'student_profile', JSONB_BUILD_OBJECT(
            'id', v_student.id,
            'full_name', v_student.full_name,
            'phone', v_student.phone,
            'whatsapp_phone', v_student.whatsapp_phone,
            'country', v_student.country,
            'city', v_student.city,
            'date_of_birth', v_student.date_of_birth,
            'last_diploma', v_student.last_diploma,
            'last_diploma_detail', v_student.last_diploma_detail,
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
            'missing_fields', TO_JSONB(v_missing_fields)
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

COMMIT;
