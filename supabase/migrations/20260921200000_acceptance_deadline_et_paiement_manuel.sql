-- Phase 4 (suite) : délai de paiement après acceptation + paiement manuel espèces/guichet.
-- Objectif : l'étudiant sait jusqu'à quand il doit payer, et peut déclarer un
-- versement en espèces ou au guichet en attendant la confirmation admin.

-- ── 1. Date butoir de paiement ─────────────────────────────────────────────
ALTER TABLE app.applications
  ADD COLUMN IF NOT EXISTS payment_deadline_at TIMESTAMPTZ;

COMMENT ON COLUMN app.applications.payment_deadline_at IS
  'Date limite de paiement des frais de courtage après acceptation de la candidature. '
  'Fixée automatiquement à J+7 lors du passage au statut accepted.';

-- ── 2. L'université fixe le délai en acceptant ────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_university_update_application_status(
  p_application_id UUID,
  p_new_status TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
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
        raw_app_meta_data->>'role',
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
        updated_at = NOW(),
        payment_deadline_at = CASE
          WHEN p_new_status = 'accepted' THEN NOW() + INTERVAL '7 days'
          ELSE a.payment_deadline_at
        END
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
$function$;

-- ── 3. L'administrateur peut aussi accepter/refuser (même logique J+7) ────────
CREATE OR REPLACE FUNCTION public.app_admin_set_application_status(
  p_application_id UUID,
  p_status TEXT,
  p_admin_notes TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_app_id UUID;
    v_status TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_app_meta_data->>'role' INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF COALESCE(v_role, '') NOT IN ('admin', 'super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_status IS NULL OR p_status NOT IN ('submitted', 'under_review', 'accepted', 'rejected', 'canceled') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM app.applications WHERE id = p_application_id) THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    UPDATE app.applications
    SET status = p_status,
        updated_at = NOW(),
        admin_seen_at = COALESCE(admin_seen_at, NOW()),
        payment_deadline_at = CASE
          WHEN p_status = 'accepted' THEN NOW() + INTERVAL '7 days'
          ELSE payment_deadline_at
        END
    WHERE id = p_application_id
    RETURNING id, status INTO v_app_id, v_status;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'application_id', v_app_id,
        'status', v_status
    );
END;
$function$;

-- ── 4. L'étudiant déclare un paiement manuel espèces/guichet ─────────────────
CREATE OR REPLACE FUNCTION public.app_student_declare_manual_payment(
  p_application_id UUID,
  p_notes TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_app RECORD;
    v_role TEXT;
    v_fee NUMERIC;
    v_payment_id UUID;
    v_existing_id UUID;
    v_existing_status TEXT;
    v_existing_ref TEXT;
    v_reference_code TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT a.*, p.university_id, p.brokerage_fee
    INTO v_app
    FROM app.applications a
    JOIN app.programs p ON p.id = a.program_id
    WHERE a.id = p_application_id;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    IF v_app.student_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    IF v_app.status <> 'accepted' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_accepted');
    END IF;

    IF v_app.discount_rate IS NULL THEN
        RETURN JSONB_BUILD_OBJECT(
            'success', FALSE,
            'error', 'taux_de_reduction_non_fixe',
            'message', 'La réduction négociée n''a pas encore été enregistrée par Academia.'
        );
    END IF;

    v_fee := COALESCE(v_app.brokerage_fee, 0);
    IF v_fee <= 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'brokerage_fee_not_defined');
    END IF;

    -- S'il existe déjà un paiement pour cette candidature et ce motif,
    -- on réutilise ou bloque selon son statut.
    SELECT id, status, reference_code
    INTO v_existing_id, v_existing_status, v_existing_ref
    FROM app.application_payments
    WHERE application_id = p_application_id
      AND payment_reason = 'application_fee'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_status = 'confirmed' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'already_paid');
    END IF;

    IF v_existing_id IS NOT NULL THEN
        UPDATE app.application_payments
        SET status = 'declared_by_student',
            payment_method = 'manual_cash',
            channel = 'cash',
            student_note = COALESCE(NULLIF(TRIM(p_notes), ''), student_note),
            declared_at = COALESCE(declared_at, NOW()),
            updated_at = NOW()
        WHERE id = v_existing_id;
        v_payment_id := v_existing_id;
        v_reference_code := v_existing_ref;
    ELSE
        v_reference_code := 'AP-MANU-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                            SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);
        INSERT INTO app.application_payments (
            application_id, student_id, university_id, amount_due, currency,
            payment_reason, status, payment_method, channel, reference_code,
            student_note, declared_at, created_by
        ) VALUES (
            p_application_id, v_app.student_id, v_app.university_id, v_fee, 'XOF',
            'application_fee', 'declared_by_student', 'manual_cash', 'cash',
            v_reference_code, NULLIF(TRIM(p_notes), ''), NOW(), v_user_id
        )
        RETURNING id INTO v_payment_id;
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'payment_id', v_payment_id,
        'status', 'declared_by_student',
        'amount_due', v_fee,
        'currency', 'XOF',
        'reference_code', v_reference_code
    );
END;
$function$;

-- ── 5. app_create_application_payment refuse de doubler une déclaration manuelle
CREATE OR REPLACE FUNCTION public.app_create_application_payment(
  p_application_id UUID,
  p_payment_reason payment_reason,
  p_amount_due NUMERIC DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_app RECORD;
  v_role TEXT;
  v_amount NUMERIC;
  v_fee NUMERIC;
  v_student_id UUID;
  v_university_id UUID;
  v_payment_id UUID;
  v_existing_id UUID;
  v_existing_status TEXT;
  v_existing_ref TEXT;
  v_reference_code TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  IF p_application_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_application_id');
  END IF;

  IF p_payment_reason IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_payment_reason');
  END IF;

  SELECT a.*, p.university_id, p.brokerage_fee
  INTO v_app
  FROM app.applications a
  JOIN app.programs p ON p.id = a.program_id
  WHERE a.id = p_application_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
  END IF;

  v_student_id := v_app.student_id;
  v_university_id := v_app.university_id;

  IF v_student_id IS NULL OR v_university_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_links_invalid');
  END IF;

  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_student_id <> v_user_id AND COALESCE(v_role, '') <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  IF p_payment_reason = 'application_fee' THEN
    v_fee := COALESCE(v_app.brokerage_fee, 0);
    IF v_fee <= 0 THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'brokerage_fee_not_defined');
    END IF;

    IF v_app.discount_rate IS NULL THEN
      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE,
        'error', 'taux_de_reduction_non_fixe',
        'message', 'La réduction négociée n''a pas encore été enregistrée par Academia. Le paiement s''ouvrira dès qu''elle le sera.'
      );
    END IF;

    v_amount := v_fee;

    -- Ne pas doubler un paiement déjà déclaré manuellement.
    SELECT id, status, reference_code
    INTO v_existing_id, v_existing_status, v_existing_ref
    FROM app.application_payments
    WHERE application_id = p_application_id
      AND payment_reason = 'application_fee'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_status IN ('declared_by_student', 'under_verification') THEN
      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE,
        'error', 'manual_payment_pending',
        'message', 'Un paiement manuel est en cours de vérification. Attendez la confirmation ou utilisez l''option de déclaration.'
      );
    END IF;

    IF v_existing_status = 'confirmed' THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'already_paid');
    END IF;
  ELSE
    IF p_amount_due IS NULL OR p_amount_due <= 0 THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_amount_due');
    END IF;
    v_amount := p_amount_due;
  END IF;

  IF v_existing_id IS NOT NULL AND v_existing_status = 'pending' THEN
    -- Réutilise le pending existant pour éviter une ligne inutile.
    v_payment_id := v_existing_id;
    v_reference_code := v_existing_ref;
  ELSE
    v_reference_code := 'AP-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                        SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);
    INSERT INTO app.application_payments (
      application_id, student_id, university_id, amount_due, currency,
      payment_reason, status, reference_code, created_by
    ) VALUES (
      p_application_id, v_student_id, v_university_id, v_amount, 'XOF',
      p_payment_reason, 'pending', v_reference_code, v_user_id
    )
    RETURNING id INTO v_payment_id;
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'payment_id', v_payment_id,
    'reference_code', v_reference_code,
    'amount_due', v_amount,
    'currency', 'XOF',
    'payment_reason', p_payment_reason,
    'amount_imposed', p_payment_reason = 'application_fee',
    'discount_rate', v_app.discount_rate
  );
END;
$function$;

-- ── 6. Les listes admin et étudiant doivent renvoyer le délai ────────────────
CREATE OR REPLACE FUNCTION public.app_list_student_applications()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_result JSONB;
BEGIN
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
                'requested_degree_level', a.requested_degree_level,
                'requested_study_mode', a.requested_study_mode,
                'requested_schedule', a.requested_schedule,
                'discount_requested', a.discount_requested,
                'discount_details', a.discount_details,
                'discount_rate', a.discount_rate,
                'discount_validated_at', a.discount_validated_at,
                'payment_deadline_at', a.payment_deadline_at,
                'student_comment', a.student_comment,
                'program_title', p.title,
                'degree_level', p.degree_level,
                'university_id', u.id,
                'university_name', u.name,
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
    JOIN app.programs p ON p.id = a.program_id
    JOIN app.universities u ON u.id = p.university_id
    WHERE a.student_id = auth.uid();

    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_list_admin_applications()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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
                'requested_degree_level', a.requested_degree_level,
                'requested_study_mode', a.requested_study_mode,
                'requested_schedule', a.requested_schedule,
                'discount_requested', a.discount_requested,
                'discount_details', a.discount_details,
                'discount_rate', a.discount_rate,
                'discount_validated_at', a.discount_validated_at,
                'payment_deadline_at', a.payment_deadline_at,
                'student_comment', a.student_comment,
                'sent_to_university', a.sent_to_university,
                'sent_to_university_at', a.sent_to_university_at,
                'admin_seen_at', a.admin_seen_at,
                'has_unseen_for_admin',
                    CASE
                        WHEN a.admin_seen_at IS NULL THEN TRUE
                        ELSE FALSE
                    END,
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
$function$;
