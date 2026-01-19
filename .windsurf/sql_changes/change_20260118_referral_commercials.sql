-- ========================================
-- ACADEMIA - REFERRAL COMMERCIALS (LINKS + COMMISSIONS)
-- Comptes commerciaux, parrainage étudiants, commissions sur premiers paiements
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE: app.commercial_profiles
-- ========================================

CREATE TABLE IF NOT EXISTS app.commercial_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  ref_code TEXT NOT NULL UNIQUE,
  ref_link TEXT NOT NULL,
  commission_rate NUMERIC(5,2) NOT NULL DEFAULT 5.00,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deactivated_at TIMESTAMPTZ
);

ALTER TABLE app.commercial_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_select_commercial_profiles ON app.commercial_profiles;
CREATE POLICY admin_select_commercial_profiles
ON app.commercial_profiles FOR SELECT
USING (
  auth.jwt() ? 'role' AND auth.jwt()->>'role' = 'admin'
);

DROP POLICY IF EXISTS commercial_select_own_profile ON app.commercial_profiles;
CREATE POLICY commercial_select_own_profile
ON app.commercial_profiles FOR SELECT
USING (user_id = auth.uid());

GRANT SELECT ON app.commercial_profiles TO authenticated;
GRANT ALL ON app.commercial_profiles TO service_role;

-- ========================================
-- 2) TABLE: app.user_referrals
-- ========================================

CREATE TABLE IF NOT EXISTS app.user_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES app.students(id) ON DELETE CASCADE,
  commercial_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ref_code TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'link',
  attributed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB
);

ALTER TABLE app.user_referrals ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX IF NOT EXISTS user_referrals_student_unique
  ON app.user_referrals(student_id);

CREATE INDEX IF NOT EXISTS user_referrals_commercial_idx
  ON app.user_referrals(commercial_user_id);

CREATE INDEX IF NOT EXISTS user_referrals_ref_code_idx
  ON app.user_referrals(ref_code);

DROP POLICY IF EXISTS admin_select_all_user_referrals ON app.user_referrals;
CREATE POLICY admin_select_all_user_referrals
ON app.user_referrals FOR SELECT
USING (
  auth.jwt() ? 'role' AND auth.jwt()->>'role' = 'admin'
);

DROP POLICY IF EXISTS commercial_select_own_user_referrals ON app.user_referrals;
CREATE POLICY commercial_select_own_user_referrals
ON app.user_referrals FOR SELECT
USING (commercial_user_id = auth.uid());

DROP POLICY IF EXISTS student_select_own_user_referral ON app.user_referrals;
CREATE POLICY student_select_own_user_referral
ON app.user_referrals FOR SELECT
USING (student_id = auth.uid());

GRANT SELECT ON app.user_referrals TO authenticated;
GRANT ALL ON app.user_referrals TO service_role;

-- ========================================
-- 3) TABLE: app.referral_commissions
-- ========================================

CREATE TABLE IF NOT EXISTS app.referral_commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commercial_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES app.students(id) ON DELETE CASCADE,
  payment_id UUID NOT NULL REFERENCES app.application_payments(id) ON DELETE CASCADE,
  commission_rate NUMERIC(5,2) NOT NULL,
  commission_amount NUMERIC(12,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'XOF',
  status TEXT NOT NULL DEFAULT 'pending', -- pending | approved | paid | rejected
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  admin_note TEXT
);

ALTER TABLE app.referral_commissions ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX IF NOT EXISTS referral_commissions_commercial_student_unique
  ON app.referral_commissions(commercial_user_id, student_id);

CREATE INDEX IF NOT EXISTS referral_commissions_commercial_idx
  ON app.referral_commissions(commercial_user_id);

CREATE INDEX IF NOT EXISTS referral_commissions_student_idx
  ON app.referral_commissions(student_id);

CREATE INDEX IF NOT EXISTS referral_commissions_payment_idx
  ON app.referral_commissions(payment_id);

CREATE INDEX IF NOT EXISTS referral_commissions_status_idx
  ON app.referral_commissions(status);

DROP POLICY IF EXISTS admin_select_all_referral_commissions ON app.referral_commissions;
CREATE POLICY admin_select_all_referral_commissions
ON app.referral_commissions FOR SELECT
USING (
  auth.jwt() ? 'role' AND auth.jwt()->>'role' = 'admin'
);

DROP POLICY IF EXISTS commercial_select_own_referral_commissions ON app.referral_commissions;
CREATE POLICY commercial_select_own_referral_commissions
ON app.referral_commissions FOR SELECT
USING (commercial_user_id = auth.uid());

GRANT SELECT ON app.referral_commissions TO authenticated;
GRANT ALL ON app.referral_commissions TO service_role;

-- ========================================
-- 4) FUNCTION: app_generate_referral_commission_for_payment
-- ========================================

CREATE OR REPLACE FUNCTION app_generate_referral_commission_for_payment(
  p_payment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_payment app.application_payments%ROWTYPE;
  v_ref app.user_referrals%ROWTYPE;
  v_profile app.commercial_profiles%ROWTYPE;
  v_commercial_id UUID;
  v_student_id UUID;
  v_rate NUMERIC(5,2);
  v_amount NUMERIC(12,2);
  v_commission_id UUID;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF p_payment_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_payment_id');
  END IF;

  SELECT *
  INTO v_payment
  FROM app.application_payments
  WHERE id = p_payment_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_not_found');
  END IF;

  IF v_payment.status <> 'confirmed' THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generated', FALSE, 'reason', 'payment_not_confirmed');
  END IF;

  IF v_payment.amount_paid IS NULL OR v_payment.amount_paid <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generated', FALSE, 'reason', 'no_amount_paid');
  END IF;

  -- Filtrer éventuellement par type de paiement (ex: uniquement frais d'inscription / scolarité)
  IF v_payment.payment_reason NOT IN ('registration_fee', 'tuition_deposit') THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generated', FALSE, 'reason', 'payment_reason_not_eligible');
  END IF;

  v_student_id := v_payment.student_id;

  IF v_student_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generated', FALSE, 'reason', 'no_student');
  END IF;

  SELECT *
  INTO v_ref
  FROM app.user_referrals
  WHERE student_id = v_student_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generated', FALSE, 'reason', 'no_referral_for_student');
  END IF;

  v_commercial_id := v_ref.commercial_user_id;

  -- Vérifier l'existence d'un profil commercial actif
  SELECT *
  INTO v_profile
  FROM app.commercial_profiles
  WHERE user_id = v_commercial_id
    AND is_active = TRUE;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generated', FALSE, 'reason', 'commercial_profile_inactive_or_missing');
  END IF;

  -- Vérifier la fenêtre de 12 mois à partir de l'attribution
  IF v_payment.confirmed_at IS NOT NULL THEN
    IF v_payment.confirmed_at > v_ref.attributed_at + INTERVAL '1 year' THEN
      RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generated', FALSE, 'reason', 'outside_12_month_window');
    END IF;
  ELSE
    IF v_now > v_ref.attributed_at + INTERVAL '1 year' THEN
      RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generated', FALSE, 'reason', 'outside_12_month_window');
    END IF;
  END IF;

  -- Vérifier qu'aucune commission n'existe déjà pour ce binôme commercial/étudiant
  IF EXISTS (
    SELECT 1
    FROM app.referral_commissions c
    WHERE c.commercial_user_id = v_commercial_id
      AND c.student_id = v_student_id
  ) THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generated', FALSE, 'reason', 'commission_already_exists_for_pair');
  END IF;

  v_rate := COALESCE(v_profile.commission_rate, 5.00);
  v_amount := ROUND(v_payment.amount_paid * v_rate / 100.0, 2);

  INSERT INTO app.referral_commissions (
    commercial_user_id,
    student_id,
    payment_id,
    commission_rate,
    commission_amount,
    currency,
    status,
    created_at
  ) VALUES (
    v_commercial_id,
    v_student_id,
    v_payment.id,
    v_rate,
    v_amount,
    v_payment.currency,
    'pending',
    v_now
  )
  RETURNING id INTO v_commission_id;

  -- Notifier le commercial (file d'événements de notifications)
  BEGIN
    PERFORM app_queue_notification_event(
      v_commercial_id,
      'commercial_commissions',
      'commission_created',
      JSONB_BUILD_OBJECT(
        'commission_id', v_commission_id,
        'student_id', v_student_id,
        'payment_id', v_payment.id,
        'commission_amount', v_amount,
        'currency', v_payment.currency
      )
    );
  EXCEPTION WHEN OTHERS THEN
    -- On ignore les erreurs de notification pour ne pas bloquer la commission
    NULL;
  END;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'generated', TRUE,
    'commission_id', v_commission_id,
    'commission_amount', v_amount,
    'currency', v_payment.currency
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_generate_referral_commission_for_payment(UUID) TO service_role;

-- ========================================
-- 5) TRIGGER: génération automatique après confirmation de paiement
-- ========================================

CREATE OR REPLACE FUNCTION app_on_payment_confirmed_generate_referral_commission()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'confirmed' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
    PERFORM app_generate_referral_commission_for_payment(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_application_payments_referral_commission ON app.application_payments;
CREATE TRIGGER trg_app_application_payments_referral_commission
AFTER UPDATE ON app.application_payments
FOR EACH ROW
EXECUTE FUNCTION app_on_payment_confirmed_generate_referral_commission();

-- ========================================
-- 6) RPC ADMIN: app_admin_list_commercials_overview
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_commercials_overview()
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
        'user_id', u.id,
        'email', u.email,
        'role', u.raw_user_meta_data->>'role',
        'full_name', u.raw_user_meta_data->>'full_name',
        'ref_code', cp.ref_code,
        'ref_link', cp.ref_link,
        'commission_rate', cp.commission_rate,
        'is_active', cp.is_active,
        'created_at', cp.created_at,
        'updated_at', cp.updated_at,
        'students_count', COALESCE(stats.students_count, 0),
        'payments_confirmed_count', COALESCE(stats.payments_confirmed_count, 0),
        'total_commission_pending', COALESCE(stats.total_commission_pending, 0),
        'total_commission_paid', COALESCE(stats.total_commission_paid, 0)
      )
      ORDER BY cp.created_at DESC
    ),
    '[]'::JSONB
  )
  INTO v_result
  FROM auth.users u
  JOIN app.commercial_profiles cp ON cp.user_id = u.id
  LEFT JOIN LATERAL (
    SELECT
      COUNT(DISTINCT r.student_id) AS students_count,
      COUNT(DISTINCT CASE WHEN p.status = 'confirmed' THEN p.id END) AS payments_confirmed_count,
      COALESCE(SUM(CASE WHEN c.status = 'pending' THEN c.commission_amount END), 0) AS total_commission_pending,
      COALESCE(SUM(CASE WHEN c.status = 'paid' THEN c.commission_amount END), 0) AS total_commission_paid
    FROM app.user_referrals r
    LEFT JOIN app.referral_commissions c
      ON c.commercial_user_id = cp.user_id
     AND c.student_id = r.student_id
    LEFT JOIN app.application_payments p
      ON p.id = c.payment_id
    WHERE r.commercial_user_id = cp.user_id
  ) AS stats ON TRUE
  WHERE u.raw_user_meta_data->>'role' = 'commercial';

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'commercials', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_commercials_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_commercials_overview() TO service_role;

-- ========================================
-- 7) RPC ADMIN: app_admin_get_commercial_detail
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_get_commercial_detail(
  p_commercial_user_id UUID
)
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

  IF p_commercial_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_commercial_user_id');
  END IF;

  SELECT JSONB_BUILD_OBJECT(
    'commercial', JSONB_BUILD_OBJECT(
      'user_id', u.id,
      'email', u.email,
      'role', u.raw_user_meta_data->>'role',
      'full_name', u.raw_user_meta_data->>'full_name',
      'ref_code', cp.ref_code,
      'ref_link', cp.ref_link,
      'commission_rate', cp.commission_rate,
      'is_active', cp.is_active,
      'created_at', cp.created_at,
      'updated_at', cp.updated_at
    ),
    'referrals', COALESCE((
      SELECT JSONB_AGG(
               JSONB_BUILD_OBJECT(
                 'id', r.id,
                 'student_id', r.student_id,
                 'ref_code', r.ref_code,
                 'source', r.source,
                 'attributed_at', r.attributed_at,
                 'expires_at', r.expires_at
               )
               ORDER BY r.attributed_at DESC
             )
      FROM app.user_referrals r
      WHERE r.commercial_user_id = cp.user_id
    ), '[]'::JSONB),
    'commissions', COALESCE((
      SELECT JSONB_AGG(
               JSONB_BUILD_OBJECT(
                 'id', c.id,
                 'student_id', c.student_id,
                 'payment_id', c.payment_id,
                 'commission_rate', c.commission_rate,
                 'commission_amount', c.commission_amount,
                 'currency', c.currency,
                 'status', c.status,
                 'created_at', c.created_at,
                 'approved_at', c.approved_at,
                 'paid_at', c.paid_at
               )
               ORDER BY c.created_at DESC
             )
      FROM app.referral_commissions c
      WHERE c.commercial_user_id = cp.user_id
    ), '[]'::JSONB)
  )
  INTO v_result
  FROM auth.users u
  JOIN app.commercial_profiles cp ON cp.user_id = u.id
  WHERE u.id = p_commercial_user_id;

  IF v_result IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'commercial_not_found');
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'data', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_get_commercial_detail(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_get_commercial_detail(UUID) TO service_role;

-- ========================================
-- 8) RPC ADMIN: app_admin_set_commercial_commission_rate
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_set_commercial_commission_rate(
  p_user_id UUID,
  p_rate NUMERIC(5,2)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_existing app.commercial_profiles%ROWTYPE;
  v_ref_code TEXT;
  v_base_url TEXT := 'https://app.academia.africa';
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

  IF p_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_user_id');
  END IF;

  IF p_rate IS NULL OR p_rate < 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_rate');
  END IF;

  SELECT *
  INTO v_existing
  FROM app.commercial_profiles
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    -- Générer un ref_code simple basé sur un UUID tronqué
    v_ref_code := 'COMM-' || SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 8);

    INSERT INTO app.commercial_profiles (
      user_id,
      ref_code,
      ref_link,
      commission_rate,
      is_active,
      created_at,
      updated_at
    ) VALUES (
      p_user_id,
      v_ref_code,
      v_base_url || '/?ref=' || v_ref_code,
      p_rate,
      TRUE,
      NOW(),
      NOW()
    );
  ELSE
    UPDATE app.commercial_profiles
    SET
      commission_rate = p_rate,
      updated_at = NOW()
    WHERE user_id = p_user_id;
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_set_commercial_commission_rate(UUID, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_set_commercial_commission_rate(UUID, NUMERIC) TO service_role;

-- ========================================
-- 9) RPC COMMERCIAL: app_commercial_get_dashboard
-- ========================================

CREATE OR REPLACE FUNCTION app_commercial_get_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_profile app.commercial_profiles%ROWTYPE;
  v_summary JSONB;
  v_referrals JSONB;
  v_commissions JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'commercial' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_commercial');
  END IF;

  SELECT *
  INTO v_profile
  FROM app.commercial_profiles
  WHERE user_id = v_user_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'commercial_profile_missing');
  END IF;

  -- Résumé
  SELECT JSONB_BUILD_OBJECT(
    'students_count', COALESCE(COUNT(DISTINCT r.student_id), 0),
    'payments_confirmed_count', COALESCE(COUNT(DISTINCT CASE WHEN p.status = 'confirmed' THEN p.id END), 0),
    'total_commission_pending', COALESCE(SUM(CASE WHEN c.status = 'pending' THEN c.commission_amount END), 0),
    'total_commission_paid', COALESCE(SUM(CASE WHEN c.status = 'paid' THEN c.commission_amount END), 0)
  )
  INTO v_summary
  FROM app.user_referrals r
  LEFT JOIN app.referral_commissions c
    ON c.commercial_user_id = v_user_id
   AND c.student_id = r.student_id
  LEFT JOIN app.application_payments p
    ON p.id = c.payment_id
  WHERE r.commercial_user_id = v_user_id;

  -- Liste des referrals
  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', r.id,
        'student_id', r.student_id,
        'ref_code', r.ref_code,
        'attributed_at', r.attributed_at,
        'expires_at', r.expires_at
      )
      ORDER BY r.attributed_at DESC
    ),
    '[]'::JSONB
  )
  INTO v_referrals
  FROM app.user_referrals r
  WHERE r.commercial_user_id = v_user_id;

  -- Liste des commissions
  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', c.id,
        'student_id', c.student_id,
        'payment_id', c.payment_id,
        'commission_rate', c.commission_rate,
        'commission_amount', c.commission_amount,
        'currency', c.currency,
        'status', c.status,
        'created_at', c.created_at,
        'approved_at', c.approved_at,
        'paid_at', c.paid_at
      )
      ORDER BY c.created_at DESC
    ),
    '[]'::JSONB
  )
  INTO v_commissions
  FROM app.referral_commissions c
  WHERE c.commercial_user_id = v_user_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'profile', JSONB_BUILD_OBJECT(
      'user_id', v_profile.user_id,
      'ref_code', v_profile.ref_code,
      'ref_link', v_profile.ref_link,
      'commission_rate', v_profile.commission_rate,
      'is_active', v_profile.is_active,
      'created_at', v_profile.created_at,
      'updated_at', v_profile.updated_at
    ),
    'summary', v_summary,
    'referrals', v_referrals,
    'commissions', v_commissions
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_commercial_get_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION app_commercial_get_dashboard() TO service_role;

-- ========================================
-- 10) RPC ETUDIANT: app_register_referral_for_current_user
-- ========================================

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
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'student' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_student');
  END IF;

  IF p_ref_code IS NULL OR LENGTH(TRIM(p_ref_code)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_ref_code');
  END IF;

  SELECT id
  INTO v_student_id
  FROM app.students
  WHERE id = v_user_id;

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

-- ========================================
-- 11) RPC ADMIN: app_admin_update_referral_commission_status
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_update_referral_commission_status(
  p_commission_id UUID,
  p_new_status TEXT,
  p_admin_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_comm app.referral_commissions%ROWTYPE;
  v_now TIMESTAMPTZ := NOW();
  v_final_status TEXT;
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

  IF p_commission_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_commission_id');
  END IF;

  IF p_new_status IS NULL OR LENGTH(TRIM(p_new_status)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
  END IF;

  v_final_status := LOWER(TRIM(p_new_status));

  IF v_final_status NOT IN ('pending', 'approved', 'paid', 'rejected') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unsupported_status');
  END IF;

  SELECT *
  INTO v_comm
  FROM app.referral_commissions
  WHERE id = p_commission_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'commission_not_found');
  END IF;

  -- Empêcher de modifier une commission déjà payée ou rejetée
  IF v_comm.status IN ('paid', 'rejected') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'status_immutable');
  END IF;

  -- Autoriser :
  -- pending -> approved / paid / rejected
  -- approved -> paid / rejected
  IF v_comm.status = 'pending' THEN
    IF v_final_status NOT IN ('approved', 'paid', 'rejected') THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_transition');
    END IF;
  ELSIF v_comm.status = 'approved' THEN
    IF v_final_status NOT IN ('paid', 'rejected') THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_transition');
    END IF;
  ELSE
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_transition');
  END IF;

  UPDATE app.referral_commissions
  SET
    status = v_final_status,
    approved_at = CASE
      WHEN v_final_status IN ('approved', 'paid') AND approved_at IS NULL
        THEN v_now
      ELSE approved_at
    END,
    paid_at = CASE
      WHEN v_final_status = 'paid' THEN v_now
      ELSE paid_at
    END,
    admin_note = COALESCE(p_admin_note, admin_note)
  WHERE id = p_commission_id;

  -- Notification quand la commission est marquée comme payée
  IF v_final_status = 'paid' THEN
    BEGIN
      PERFORM app_queue_notification_event(
        v_comm.commercial_user_id,
        'commercial_commissions',
        'commission_paid',
        JSONB_BUILD_OBJECT(
          'commission_id', v_comm.id,
          'student_id', v_comm.student_id,
          'payment_id', v_comm.payment_id,
          'commission_amount', v_comm.commission_amount,
          'currency', v_comm.currency
        )
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'new_status', v_final_status);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_update_referral_commission_status(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_update_referral_commission_status(UUID, TEXT, TEXT) TO service_role;
