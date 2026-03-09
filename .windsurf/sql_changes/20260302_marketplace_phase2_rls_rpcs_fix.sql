-- ========================================
-- ACADEMIA - MARKETPLACE (ALIBABA-LIKE)
-- PHASE 2 FIX: app_merchant_upsert_opportunity signature + grant
--
-- Cause:
-- PostgreSQL n'accepte pas des paramètres sans default après un paramètre avec default.
-- ========================================

-- Recréer la fonction avec une signature valide (pas de default sur le 1er param)
CREATE OR REPLACE FUNCTION public.app_merchant_upsert_opportunity(
  p_opportunity_id UUID,
  p_title TEXT,
  p_short_description TEXT,
  p_description TEXT,
  p_type TEXT,
  p_category TEXT,
  p_organization_name TEXT,
  p_organization_logo_url TEXT,
  p_country TEXT,
  p_city TEXT,
  p_is_remote_possible BOOLEAN,
  p_contract_type TEXT,
  p_duration_months INTEGER,
  p_start_date DATE,
  p_application_deadline DATE,
  p_price_from NUMERIC,
  p_price_to NUMERIC,
  p_currency TEXT,
  p_min_order_qty INTEGER,
  p_lead_time_days INTEGER,
  p_is_ready_to_ship BOOLEAN
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

-- Grant sur la signature corrigée
GRANT EXECUTE ON FUNCTION public.app_merchant_upsert_opportunity(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, INTEGER, DATE, DATE, NUMERIC, NUMERIC, TEXT, INTEGER, INTEGER, BOOLEAN) TO authenticated;
