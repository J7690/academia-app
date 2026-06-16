-- ========================================
-- ACADEMIA - MARKETPLACE (ALIBABA-LIKE)
-- PHASE 2: RLS + RPC
--
-- Objectifs:
-- - RLS sur merchant_profiles + inquiries + inquiry_messages
-- - RPC Merchant (draft + submit review + inbox inquiries)
-- - RPC Admin (validation avant publication + verify merchant)
-- - RPC Buyer/Student (create inquiry + list inquiries)
--
-- Notes:
-- - Ce script conserve la lecture publique des opportunités publiées via la policy existante.
-- - La logique de validation Admin s'appuie sur auth.users.raw_user_meta_data->>'role'.
-- ========================================

-- =============================
-- 0) Helper: current role
-- =============================
CREATE OR REPLACE FUNCTION public.app_get_current_role()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN 'anon';
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  RETURN COALESCE(NULLIF(v_role, ''), 'student');
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_get_current_role() TO anon, authenticated;

-- =============================
-- 1) RLS: merchant_profiles
-- =============================
ALTER TABLE app.merchant_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS merchant_profiles_public_select_verified ON app.merchant_profiles;
CREATE POLICY merchant_profiles_public_select_verified
ON app.merchant_profiles FOR SELECT
USING (
  is_active = TRUE
  AND is_verified = TRUE
);

DROP POLICY IF EXISTS merchant_profiles_user_select_own ON app.merchant_profiles;
CREATE POLICY merchant_profiles_user_select_own
ON app.merchant_profiles FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
);

DROP POLICY IF EXISTS merchant_profiles_user_upsert_own ON app.merchant_profiles;
CREATE POLICY merchant_profiles_user_upsert_own
ON app.merchant_profiles FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
);

DROP POLICY IF EXISTS merchant_profiles_user_update_own ON app.merchant_profiles;
CREATE POLICY merchant_profiles_user_update_own
ON app.merchant_profiles FOR UPDATE
TO authenticated
USING (
  user_id = auth.uid()
)
WITH CHECK (
  user_id = auth.uid()
);

GRANT SELECT, INSERT, UPDATE ON app.merchant_profiles TO authenticated;
GRANT ALL ON app.merchant_profiles TO service_role;

-- =============================
-- 2) RLS: opportunity_inquiries
-- =============================
ALTER TABLE app.opportunity_inquiries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS opportunity_inquiries_user_select_own ON app.opportunity_inquiries;
CREATE POLICY opportunity_inquiries_user_select_own
ON app.opportunity_inquiries FOR SELECT
TO authenticated
USING (
  buyer_id = auth.uid() OR merchant_id = auth.uid()
);

DROP POLICY IF EXISTS opportunity_inquiries_buyer_insert ON app.opportunity_inquiries;
CREATE POLICY opportunity_inquiries_buyer_insert
ON app.opportunity_inquiries FOR INSERT
TO authenticated
WITH CHECK (
  buyer_id = auth.uid()
);

DROP POLICY IF EXISTS opportunity_inquiries_buyer_update_status_own ON app.opportunity_inquiries;
CREATE POLICY opportunity_inquiries_buyer_update_status_own
ON app.opportunity_inquiries FOR UPDATE
TO authenticated
USING (
  buyer_id = auth.uid()
)
WITH CHECK (
  buyer_id = auth.uid()
);

DROP POLICY IF EXISTS opportunity_inquiries_merchant_update_status_own ON app.opportunity_inquiries;
CREATE POLICY opportunity_inquiries_merchant_update_status_own
ON app.opportunity_inquiries FOR UPDATE
TO authenticated
USING (
  merchant_id = auth.uid()
)
WITH CHECK (
  merchant_id = auth.uid()
);

GRANT SELECT, INSERT, UPDATE ON app.opportunity_inquiries TO authenticated;
GRANT ALL ON app.opportunity_inquiries TO service_role;

-- =============================
-- 3) RLS: inquiry_messages
-- =============================
ALTER TABLE app.opportunity_inquiry_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS opportunity_inquiry_messages_select_participants ON app.opportunity_inquiry_messages;
CREATE POLICY opportunity_inquiry_messages_select_participants
ON app.opportunity_inquiry_messages FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM app.opportunity_inquiries i
    WHERE i.id = inquiry_id
      AND (i.buyer_id = auth.uid() OR i.merchant_id = auth.uid())
  )
);

DROP POLICY IF EXISTS opportunity_inquiry_messages_insert_participants ON app.opportunity_inquiry_messages;
CREATE POLICY opportunity_inquiry_messages_insert_participants
ON app.opportunity_inquiry_messages FOR INSERT
TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM app.opportunity_inquiries i
    WHERE i.id = inquiry_id
      AND (i.buyer_id = auth.uid() OR i.merchant_id = auth.uid())
  )
);

GRANT SELECT, INSERT ON app.opportunity_inquiry_messages TO authenticated;
GRANT ALL ON app.opportunity_inquiry_messages TO service_role;

-- =============================
-- 4) RPC: Merchant profile upsert
-- =============================
CREATE OR REPLACE FUNCTION public.app_merchant_upsert_profile(
  p_display_name TEXT,
  p_logo_url TEXT DEFAULT NULL,
  p_bio TEXT DEFAULT NULL,
  p_country TEXT DEFAULT NULL,
  p_city TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  IF p_display_name IS NULL OR length(trim(p_display_name)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'display_name_required');
  END IF;

  INSERT INTO app.merchant_profiles(
    user_id, display_name, logo_url, bio, country, city, updated_at
  ) VALUES (
    v_user_id, trim(p_display_name), p_logo_url, p_bio, p_country, p_city, now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    logo_url = EXCLUDED.logo_url,
    bio = EXCLUDED.bio,
    country = EXCLUDED.country,
    city = EXCLUDED.city,
    updated_at = now();

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_upsert_profile(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- =============================
-- 5) RPC: Merchant upsert opportunity (draft)
-- =============================
CREATE OR REPLACE FUNCTION public.app_merchant_upsert_opportunity(
  p_opportunity_id UUID DEFAULT NULL,
  p_title TEXT,
  p_short_description TEXT,
  p_description TEXT DEFAULT NULL,
  p_type TEXT,
  p_category TEXT DEFAULT NULL,
  p_organization_name TEXT,
  p_organization_logo_url TEXT DEFAULT NULL,
  p_country TEXT,
  p_city TEXT,
  p_is_remote_possible BOOLEAN DEFAULT NULL,
  p_contract_type TEXT DEFAULT NULL,
  p_duration_months INTEGER DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_application_deadline DATE DEFAULT NULL,
  p_price_from NUMERIC DEFAULT NULL,
  p_price_to NUMERIC DEFAULT NULL,
  p_currency TEXT DEFAULT NULL,
  p_min_order_qty INTEGER DEFAULT NULL,
  p_lead_time_days INTEGER DEFAULT NULL,
  p_is_ready_to_ship BOOLEAN DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'title_required');
  END IF;

  IF p_short_description IS NULL OR length(trim(p_short_description)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'short_description_required');
  END IF;

  IF p_type IS NULL OR length(trim(p_type)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'type_required');
  END IF;

  IF p_organization_name IS NULL OR length(trim(p_organization_name)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'organization_name_required');
  END IF;

  IF p_country IS NULL OR length(trim(p_country)) = 0 OR p_city IS NULL OR length(trim(p_city)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'location_required');
  END IF;

  IF p_opportunity_id IS NULL THEN
    INSERT INTO app.opportunities(
      title, short_description, description, type, category,
      organization_name, organization_logo_url,
      country, city, is_remote_possible,
      contract_type, duration_months, start_date, application_deadline,
      status, is_featured, is_active,
      created_by_user_id,
      merchant_id,
      review_status,
      price_from, price_to, currency,
      min_order_qty, lead_time_days, is_ready_to_ship,
      created_at, updated_at
    ) VALUES (
      trim(p_title), trim(p_short_description), p_description, trim(p_type), p_category,
      trim(p_organization_name), p_organization_logo_url,
      trim(p_country), trim(p_city), COALESCE(p_is_remote_possible, false),
      p_contract_type, p_duration_months, p_start_date, p_application_deadline,
      'draft', false, true,
      v_user_id,
      v_user_id,
      'draft',
      p_price_from, p_price_to, p_currency,
      p_min_order_qty, p_lead_time_days, COALESCE(p_is_ready_to_ship, false),
      now(), now()
    ) RETURNING id INTO v_id;
  ELSE
    UPDATE app.opportunities
    SET
      title = trim(p_title),
      short_description = trim(p_short_description),
      description = p_description,
      type = trim(p_type),
      category = p_category,
      organization_name = trim(p_organization_name),
      organization_logo_url = p_organization_logo_url,
      country = trim(p_country),
      city = trim(p_city),
      is_remote_possible = COALESCE(p_is_remote_possible, is_remote_possible),
      contract_type = p_contract_type,
      duration_months = p_duration_months,
      start_date = p_start_date,
      application_deadline = p_application_deadline,
      price_from = p_price_from,
      price_to = p_price_to,
      currency = p_currency,
      min_order_qty = p_min_order_qty,
      lead_time_days = p_lead_time_days,
      is_ready_to_ship = COALESCE(p_is_ready_to_ship, is_ready_to_ship),
      updated_at = now()
    WHERE id = p_opportunity_id
      AND merchant_id = v_user_id
      AND review_status IN ('draft', 'rejected')
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'not_found_or_not_editable');
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'opportunity_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_upsert_opportunity(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, INTEGER, DATE, DATE, NUMERIC, NUMERIC, TEXT, INTEGER, INTEGER, BOOLEAN) TO authenticated;

-- =============================
-- 6) RPC: Merchant submit for review
-- =============================
CREATE OR REPLACE FUNCTION public.app_merchant_submit_opportunity_for_review(
  p_opportunity_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  UPDATE app.opportunities
  SET
    review_status = 'pending_review',
    submitted_at = now(),
    updated_at = now()
  WHERE id = p_opportunity_id
    AND merchant_id = v_user_id
    AND review_status IN ('draft', 'rejected')
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_found_or_not_submittable');
  END IF;

  RETURN jsonb_build_object('success', true, 'opportunity_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_submit_opportunity_for_review(UUID) TO authenticated;

-- =============================
-- 7) RPC: Admin list pending review
-- =============================
CREATE OR REPLACE FUNCTION public.app_admin_list_pending_opportunities()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'opportunities', (
      SELECT COALESCE(jsonb_agg(to_jsonb(o) ORDER BY o.submitted_at DESC), '[]'::jsonb)
      FROM app.opportunities o
      WHERE o.review_status = 'pending_review'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_list_pending_opportunities() TO authenticated;

-- =============================
-- 8) RPC: Admin review opportunity
-- =============================
CREATE OR REPLACE FUNCTION public.app_admin_review_opportunity(
  p_opportunity_id UUID,
  p_decision TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  IF p_decision NOT IN ('approve', 'reject') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_decision');
  END IF;

  IF p_decision = 'approve' THEN
    UPDATE app.opportunities
    SET
      review_status = 'approved',
      review_reason = NULL,
      reviewed_at = now(),
      reviewed_by = v_user_id,
      status = 'published',
      is_active = TRUE,
      updated_at = now()
    WHERE id = p_opportunity_id
      AND review_status = 'pending_review'
    RETURNING id INTO v_id;
  ELSE
    UPDATE app.opportunities
    SET
      review_status = 'rejected',
      review_reason = p_reason,
      reviewed_at = now(),
      reviewed_by = v_user_id,
      status = 'draft',
      updated_at = now()
    WHERE id = p_opportunity_id
      AND review_status = 'pending_review'
    RETURNING id INTO v_id;
  END IF;

  IF v_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_found_or_not_pending');
  END IF;

  RETURN jsonb_build_object('success', true, 'opportunity_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_review_opportunity(UUID, TEXT, TEXT) TO authenticated;

-- =============================
-- 9) RPC: Admin verify merchant
-- =============================
CREATE OR REPLACE FUNCTION public.app_admin_set_merchant_verification(
  p_merchant_id UUID,
  p_is_verified BOOLEAN,
  p_verification_level TEXT DEFAULT 'none'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  UPDATE app.merchant_profiles
  SET
    is_verified = COALESCE(p_is_verified, is_verified),
    verification_level = COALESCE(NULLIF(p_verification_level, ''), verification_level),
    updated_at = now()
  WHERE user_id = p_merchant_id
  RETURNING user_id INTO v_id;

  IF v_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_not_found');
  END IF;

  RETURN jsonb_build_object('success', true, 'merchant_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_set_merchant_verification(UUID, BOOLEAN, TEXT) TO authenticated;

-- =============================
-- 10) RPC: Buyer create inquiry
-- =============================
CREATE OR REPLACE FUNCTION public.app_student_create_opportunity_inquiry(
  p_opportunity_id UUID,
  p_message TEXT,
  p_quantity INTEGER DEFAULT NULL,
  p_budget NUMERIC DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_merchant_id UUID;
  v_inquiry_id UUID;
  v_is_published BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_message IS NULL OR length(trim(p_message)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'message_required');
  END IF;

  SELECT o.merchant_id,
         (o.status = 'published' AND o.is_active = TRUE) AS is_published
  INTO v_merchant_id, v_is_published
  FROM app.opportunities o
  WHERE o.id = p_opportunity_id;

  IF v_merchant_id IS NULL OR v_is_published IS DISTINCT FROM TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'opportunity_not_available');
  END IF;

  INSERT INTO app.opportunity_inquiries(
    opportunity_id, buyer_id, merchant_id, message, quantity, budget, status, created_at, last_message_at
  ) VALUES (
    p_opportunity_id, v_user_id, v_merchant_id, trim(p_message), p_quantity, p_budget, 'open', now(), now()
  ) RETURNING id INTO v_inquiry_id;

  INSERT INTO app.opportunity_inquiry_messages(
    inquiry_id, sender_id, content, created_at
  ) VALUES (
    v_inquiry_id, v_user_id, trim(p_message), now()
  );

  RETURN jsonb_build_object('success', true, 'inquiry_id', v_inquiry_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_create_opportunity_inquiry(UUID, TEXT, INTEGER, NUMERIC) TO authenticated;

-- =============================
-- 11) RPC: Buyer list my inquiries
-- =============================
CREATE OR REPLACE FUNCTION public.app_student_list_my_opportunity_inquiries(
  p_limit INTEGER DEFAULT 30,
  p_offset INTEGER DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'inquiries', (
      SELECT COALESCE(jsonb_agg(to_jsonb(i) ORDER BY i.last_message_at DESC), '[]'::jsonb)
      FROM app.opportunity_inquiries i
      WHERE i.buyer_id = v_user_id
      LIMIT GREATEST(1, LEAST(p_limit, 100))
      OFFSET GREATEST(0, p_offset)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_my_opportunity_inquiries(INTEGER, INTEGER) TO authenticated;

-- =============================
-- 12) RPC: Merchant list inquiries
-- =============================
CREATE OR REPLACE FUNCTION public.app_merchant_list_inquiries(
  p_status TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 30,
  p_offset INTEGER DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'inquiries', (
      SELECT COALESCE(jsonb_agg(to_jsonb(i) ORDER BY i.last_message_at DESC), '[]'::jsonb)
      FROM app.opportunity_inquiries i
      WHERE i.merchant_id = v_user_id
        AND (p_status IS NULL OR i.status = p_status)
      LIMIT GREATEST(1, LEAST(p_limit, 100))
      OFFSET GREATEST(0, p_offset)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_list_inquiries(TEXT, INTEGER, INTEGER) TO authenticated;

-- =============================
-- 13) RPC: Merchant reply inquiry
-- =============================
CREATE OR REPLACE FUNCTION public.app_merchant_reply_inquiry(
  p_inquiry_id UUID,
  p_message TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_ok BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  IF p_message IS NULL OR length(trim(p_message)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'message_required');
  END IF;

  SELECT TRUE
  INTO v_ok
  FROM app.opportunity_inquiries i
  WHERE i.id = p_inquiry_id
    AND i.merchant_id = v_user_id;

  IF v_ok IS DISTINCT FROM TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'inquiry_not_found');
  END IF;

  INSERT INTO app.opportunity_inquiry_messages(inquiry_id, sender_id, content, created_at)
  VALUES (p_inquiry_id, v_user_id, trim(p_message), now());

  UPDATE app.opportunity_inquiries
  SET
    status = 'replied',
    last_message_at = now()
  WHERE id = p_inquiry_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_reply_inquiry(UUID, TEXT) TO authenticated;
