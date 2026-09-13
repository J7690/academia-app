-- ============================================================================
-- CORRIGER app_get_university_application_detail : le défaut || sur tableau vide
--
-- CE DÉFAUT. `app_get_university_application_detail` construit un tableau
-- `v_missing_fields TEXT[]` avec l'opérateur `||` :
--     v_missing_fields := v_missing_fields || 'date_of_birth';
-- Quand le tableau est vide et que le littéral n'est pas typé, PostgreSQL
-- choisit la surcharge `text[] || text[]` et tente de convertir
-- 'date_of_birth' EN TABLEAU → malformed array literal.
--
-- C'EST EXACTEMENT le défaut corrigé le 08/09 dans `app_is_student_dossier_complete`
-- (commit f3b2f48, migration 20260908210000), où `||` a été remplacé par
-- `array_append()`. La correction n'a pas été portée ici.
--
-- CONSÉQUENCE MESURÉE : 7 candidatures transmises sur 26 sont illisibles par
-- l'université depuis le 10/09. Ce sont les étudiants inscrits après
-- l'allègement du dossier (Amed Youssef Compaore, Aminata Guinko, Nathalie
-- zongo, DICKO HADIZATOU) — tous sans date_of_birth.
--
-- AUSSI ALIGNÉ : la section `student_dossier_status` vérifie maintenant les
-- MÊMES champs que `app_is_student_dossier_complete` (full_name + last_diploma),
-- et non plus 12 champs dont 10 ne sont plus exigés.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_get_university_application_detail(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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

    -- ALIGNÉ sur app_is_student_dossier_complete (migration 20260908210000) :
    -- seuls full_name et last_diploma sont exigés pour candidater depuis le 08/09.
    -- `array_append`, JAMAIS `||` — c'est ce détail qui cassait.
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
$function$;
