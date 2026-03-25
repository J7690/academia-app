-- ============================================================
-- FIX COMMERCIAL SYSTEM — 15 Mars 2026
-- Fixes: unit mismatch, double commission path, tier counter,
--        netlify domain unification, commission_rules dedup
-- ============================================================

-- ============================================================
-- FIX 2: fn_check_commission_cap — return rate as FRACTION
-- (was returning percentage from commercial_profiles.commission_rate)
-- Now divides by 100 to match commission_rules fraction format
-- ============================================================
CREATE OR REPLACE FUNCTION app.fn_check_commission_cap(
    p_commercial_user_id uuid,
    p_student_id uuid
)
RETURNS TABLE(allowed boolean, commission_number integer, adjusted_rate numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_max_cap INTEGER;
    v_existing_count INTEGER;
    v_base_rate NUMERIC;
    v_adjusted NUMERIC;
BEGIN
    SELECT max_commissions_per_prospect, commission_rate
    INTO v_max_cap, v_base_rate
    FROM app.commercial_profiles
    WHERE user_id = p_commercial_user_id;

    IF v_max_cap IS NULL THEN v_max_cap := 3; END IF;
    -- commission_rate in commercial_profiles is stored as PERCENTAGE (5.0 = 5%)
    -- Convert to fraction for consistency with commission_rules (0.05 = 5%)
    IF v_base_rate IS NULL THEN v_base_rate := 5.0; END IF;
    v_base_rate := v_base_rate / 100.0;

    SELECT COUNT(*) INTO v_existing_count
    FROM app.referral_commissions
    WHERE commercial_user_id = p_commercial_user_id
      AND student_id = p_student_id;

    IF v_existing_count >= v_max_cap THEN
        RETURN QUERY SELECT FALSE, v_existing_count + 1, 0::NUMERIC;
        RETURN;
    END IF;

    -- Degressive rate: base * 0.85^n (in fraction units now)
    v_adjusted := v_base_rate * POWER(0.85, v_existing_count);
    IF v_adjusted < 0.005 THEN v_adjusted := 0.005; END IF;

    RETURN QUERY SELECT TRUE, v_existing_count + 1, ROUND(v_adjusted, 4);
    RETURN;
END;
$function$;

-- ============================================================
-- FIX 3: Disable the trigger-based commission generation path
-- Keep only the inline path in app_admin_confirm_payment
-- ============================================================
ALTER TABLE app.application_payments
    DISABLE TRIGGER trg_app_application_payments_referral_commission;

-- ============================================================
-- FIX 5: fn_update_commercial_tier — align counter with tier calc
-- Both now use COUNT(*) for total_confirmed_payments
-- Tier thresholds remain based on DISTINCT student count
-- ============================================================
CREATE OR REPLACE FUNCTION app.fn_update_commercial_tier()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_commercial_id UUID;
    v_distinct_students INTEGER;
    v_total_commissions INTEGER;
    v_new_tier TEXT;
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        v_commercial_id := NEW.commercial_user_id;
    ELSE
        v_commercial_id := OLD.commercial_user_id;
    END IF;

    -- Tier based on distinct students with commissions
    SELECT COUNT(DISTINCT student_id) INTO v_distinct_students
    FROM app.referral_commissions
    WHERE commercial_user_id = v_commercial_id
      AND status IN ('pending', 'approved', 'paid');

    -- Total commissions count (all statuses except rejected)
    SELECT COUNT(*) INTO v_total_commissions
    FROM app.referral_commissions
    WHERE commercial_user_id = v_commercial_id
      AND status IN ('pending', 'approved', 'paid');

    IF v_distinct_students >= 30 THEN v_new_tier := 'diamond';
    ELSIF v_distinct_students >= 15 THEN v_new_tier := 'gold';
    ELSIF v_distinct_students >= 5 THEN v_new_tier := 'silver';
    ELSE v_new_tier := 'bronze';
    END IF;

    UPDATE app.commercial_profiles
    SET tier = v_new_tier,
        total_confirmed_payments = v_total_commissions,
        updated_at = NOW()
    WHERE user_id = v_commercial_id;

    RETURN COALESCE(NEW, OLD);
END;
$function$;

-- ============================================================
-- FIX 6: Unify Netlify domain in ref_links
-- Update old domain to current domain
-- ============================================================
UPDATE app.commercial_profiles
SET ref_link = REPLACE(ref_link, 'amazing-boba-9a75a7.netlify.app', 'dulcet-snickerdoodle-915a6b.netlify.app'),
    updated_at = NOW()
WHERE ref_link LIKE '%amazing-boba-9a75a7.netlify.app%';

-- ============================================================
-- FIX 7: Remove duplicate commission_rules (case variants)
-- Keep the properly capitalized versions
-- ============================================================
DELETE FROM app.commission_rules
WHERE id IN (
    SELECT cr.id
    FROM app.commission_rules cr
    WHERE EXISTS (
        SELECT 1 FROM app.commission_rules cr2
        WHERE LOWER(cr2.degree_level) = LOWER(cr.degree_level)
          AND cr2.payment_reason = cr.payment_reason
          AND cr2.id <> cr.id
          AND cr2.created_at < cr.created_at
    )
    AND cr.degree_level <> INITCAP(cr.degree_level)
    AND cr.degree_level <> UPPER(cr.degree_level)
);
