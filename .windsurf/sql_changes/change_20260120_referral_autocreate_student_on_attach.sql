-- Corrige l’attachement des parrainages pour les nouveaux étudiants
-- en créant automatiquement un profil app.students minimal si nécessaire.

CREATE OR REPLACE FUNCTION app_register_referral_for_current_user(
  p_ref_code TEXT,
  p_source TEXT DEFAULT 'link',
  p_metadata JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_student_id UUID;
  v_commercial_user_id UUID;
  v_existing BOOLEAN;
  v_full_name TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role',
         raw_user_meta_data->>'full_name'
  INTO v_role, v_full_name
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'student' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_student');
  END IF;

  IF p_ref_code IS NULL OR LENGTH(TRIM(p_ref_code)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_ref_code');
  END IF;

  -- S'assurer que le profil étudiant existe, sinon créer un profil minimal.
  SELECT id
  INTO v_student_id
  FROM app.students
  WHERE id = v_user_id;

  IF v_student_id IS NULL THEN
    INSERT INTO app.students (id, full_name)
    VALUES (
      v_user_id,
      COALESCE(NULLIF(TRIM(v_full_name), ''), 'Etudiant')
    )
    ON CONFLICT (id) DO NOTHING;

    SELECT id
    INTO v_student_id
    FROM app.students
    WHERE id = v_user_id;
  END IF;

  IF v_student_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'student_not_found');
  END IF;

  -- Ne pas écraser un parrainage existant
  SELECT TRUE
  INTO v_existing
  FROM app.user_referrals
  WHERE student_id = v_student_id
  LIMIT 1;

  IF FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'attached', FALSE, 'reason', 'already_attached');
  END IF;

  -- Trouver le commercial actif pour ce ref_code
  SELECT user_id
  INTO v_commercial_user_id
  FROM app.commercial_profiles
  WHERE ref_code = p_ref_code
    AND is_active = TRUE
  LIMIT 1;

  IF v_commercial_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'ref_code_not_found');
  END IF;

  INSERT INTO app.user_referrals (
    student_id,
    commercial_user_id,
    ref_code,
    source,
    attributed_at,
    expires_at,
    metadata
  ) VALUES (
    v_student_id,
    v_commercial_user_id,
    p_ref_code,
    COALESCE(NULLIF(TRIM(p_source), ''), 'link'),
    NOW(),
    NOW() + INTERVAL '1 year',
    COALESCE(p_metadata, '{}'::JSONB)
  );

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'attached', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_register_referral_for_current_user(TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION app_register_referral_for_current_user(TEXT, TEXT, JSONB) TO service_role;
