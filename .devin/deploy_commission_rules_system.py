#!/usr/bin/env python3
"""
Deploy commission rules system:
1. Table commission_rules (payment_reason × degree_level → rate + max_amount)
2. Function to resolve commission rate for a given payment
3. Update app_admin_confirm_payment to auto-create referral_commissions
4. Admin CRUD RPCs for commission rules
"""
import requests
import time

PROJECT_REF = "thevdfcwlcqzdoybfvgs"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

RPC_URL = f"https://{PROJECT_REF}.supabase.co/rest/v1/rpc/execute_sql"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def inject_ddl(label, ddl_sql):
    payload = f"SELECT 1) t; {ddl_sql}; SELECT * FROM (SELECT 1"
    r = requests.post(RPC_URL, headers=HEADERS, json={"sql_query": payload}, timeout=60)
    result = r.json()
    if isinstance(result, dict) and result.get('error'):
        print(f"  ❌ {label}: {result['error'][:300]}")
        return False
    else:
        print(f"  ✅ {label}")
        return True

STEPS = []

# ─────────────────────────────────────────────────────────────────────
# 1. Create commission_rules table
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create commission_rules table", """
CREATE TABLE IF NOT EXISTS app.commission_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_reason TEXT NOT NULL DEFAULT '*',
    degree_level TEXT NOT NULL DEFAULT '*',
    commission_rate NUMERIC NOT NULL DEFAULT 0.10,
    max_amount NUMERIC NOT NULL DEFAULT 0,
    currency TEXT NOT NULL DEFAULT 'XOF',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    description TEXT,
    priority INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(payment_reason, degree_level)
)
"""))

# ─────────────────────────────────────────────────────────────────────
# 2. Insert default rules
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Insert default commission rules", """
INSERT INTO app.commission_rules (payment_reason, degree_level, commission_rate, max_amount, description, priority)
VALUES
    ('application_fee', '*',       0.20, 5000,  'Frais de dossier — toutes formations', 10),
    ('registration_fee', 'BTS',    0.10, 15000, 'Frais inscription — BTS', 30),
    ('registration_fee', 'licence', 0.12, 25000, 'Frais inscription — Licence', 30),
    ('registration_fee', 'Licence', 0.12, 25000, 'Frais inscription — Licence (maj)', 30),
    ('registration_fee', 'LMD',    0.12, 25000, 'Frais inscription — LMD', 30),
    ('registration_fee', 'master',  0.15, 40000, 'Frais inscription — Master', 30),
    ('registration_fee', 'Master',  0.15, 40000, 'Frais inscription — Master (maj)', 30),
    ('registration_fee', 'Master1', 0.15, 40000, 'Frais inscription — Master1', 30),
    ('registration_fee', 'doctorat', 0.15, 50000, 'Frais inscription — Doctorat', 30),
    ('registration_fee', '*',       0.12, 25000, 'Frais inscription — défaut', 20),
    ('tuition_deposit',  '*',       0.05, 20000, 'Acompte scolarité — toutes formations', 10),
    ('td_access',        '*',       0.00, 0,     'Accès TD — pas de commission', 10),
    ('*',                '*',       0.08, 10000, 'Règle par défaut universelle', 0)
ON CONFLICT (payment_reason, degree_level) DO NOTHING
"""))

# ─────────────────────────────────────────────────────────────────────
# 3. Function to resolve commission rate
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create fn_resolve_commission_rate function", """
CREATE OR REPLACE FUNCTION app.fn_resolve_commission_rate(
    p_payment_reason TEXT,
    p_degree_level TEXT
) RETURNS TABLE(resolved_rate NUMERIC, resolved_max_amount NUMERIC, resolved_currency TEXT, rule_id UUID)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_rule RECORD;
BEGIN
    -- Priority order: exact match > payment_reason match > degree_level match > wildcard
    SELECT cr.commission_rate, cr.max_amount, cr.currency, cr.id
    INTO v_rule
    FROM app.commission_rules cr
    WHERE cr.is_active = TRUE
      AND (cr.payment_reason = p_payment_reason OR cr.payment_reason = '*')
      AND (cr.degree_level = p_degree_level OR cr.degree_level = '*')
    ORDER BY
        CASE WHEN cr.payment_reason = p_payment_reason AND cr.degree_level = p_degree_level THEN 0
             WHEN cr.payment_reason = p_payment_reason AND cr.degree_level = '*' THEN 1
             WHEN cr.payment_reason = '*' AND cr.degree_level = p_degree_level THEN 2
             ELSE 3
        END,
        cr.priority DESC
    LIMIT 1;

    IF v_rule IS NULL THEN
        RETURN QUERY SELECT 0.08::NUMERIC, 10000::NUMERIC, 'XOF'::TEXT, NULL::UUID;
        RETURN;
    END IF;

    RETURN QUERY SELECT v_rule.commission_rate, v_rule.max_amount, v_rule.currency, v_rule.id;
    RETURN;
END;
$$
"""))

# ─────────────────────────────────────────────────────────────────────
# 4. Update app_admin_confirm_payment to auto-create commissions
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Update app_admin_confirm_payment with auto-commission", """
CREATE OR REPLACE FUNCTION public.app_admin_confirm_payment(p_payment_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_payment app.application_payments%ROWTYPE;
  v_receipt_id UUID;
  v_receipt_number TEXT;
  v_snapshot JSONB;
  -- Commission variables
  v_commercial_user_id UUID;
  v_degree_level TEXT;
  v_resolved_rate NUMERIC;
  v_resolved_max NUMERIC;
  v_resolved_currency TEXT;
  v_resolved_rule_id UUID;
  v_cap_allowed BOOLEAN;
  v_cap_number INTEGER;
  v_cap_adjusted_rate NUMERIC;
  v_final_rate NUMERIC;
  v_commission_amount NUMERIC;
  v_commission_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role NOT IN ('admin', 'super_admin') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

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

  IF v_payment.status NOT IN ('pending', 'declared_by_student', 'under_verification') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status_for_confirmation');
  END IF;

  IF v_payment.amount_paid IS NULL OR v_payment.amount_paid <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'amount_paid_missing');
  END IF;

  IF v_payment.channel IN ('orange_money', 'moov_money', 'telecel_money')
     AND (v_payment.external_reference IS NULL OR LENGTH(TRIM(v_payment.external_reference)) = 0)
  THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'external_reference_required_for_mobile_money');
  END IF;

  v_receipt_number := 'REC-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                      SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

  v_snapshot := JSONB_BUILD_OBJECT(
    'payment_id', v_payment.id,
    'application_id', v_payment.application_id,
    'student_id', v_payment.student_id,
    'university_id', v_payment.university_id,
    'amount_due', v_payment.amount_due,
    'amount_paid', v_payment.amount_paid,
    'currency', v_payment.currency,
    'payment_reason', v_payment.payment_reason,
    'channel', v_payment.channel,
    'reference_code', v_payment.reference_code,
    'external_reference', v_payment.external_reference,
    'created_at', v_payment.created_at,
    'confirmed_at', NOW()
  );

  INSERT INTO app.payment_receipts (
    payment_id, receipt_number, issued_by, issued_at, snapshot
  ) VALUES (
    v_payment.id, v_receipt_number, v_user_id, NOW(), v_snapshot
  )
  RETURNING id INTO v_receipt_id;

  UPDATE app.application_payments
  SET
    status = 'confirmed',
    confirmed_by = v_user_id,
    confirmed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_payment_id;

  -- ═══════════════════════════════════════════════════════════════════
  -- AUTO-CREATE COMMISSION for commercial referrer (if any)
  -- ═══════════════════════════════════════════════════════════════════
  SELECT ur.commercial_user_id INTO v_commercial_user_id
  FROM app.user_referrals ur
  WHERE ur.student_id = v_payment.student_id
  LIMIT 1;

  IF v_commercial_user_id IS NOT NULL THEN
    -- Check if commercial profile is active
    IF EXISTS (SELECT 1 FROM app.commercial_profiles WHERE user_id = v_commercial_user_id AND is_active = TRUE) THEN

      -- Get degree_level from the program
      SELECT p.degree_level INTO v_degree_level
      FROM app.applications a
      JOIN app.programs p ON p.id = a.program_id
      WHERE a.id = v_payment.application_id;

      -- Resolve commission rate from rules
      SELECT r.resolved_rate, r.resolved_max_amount, r.resolved_currency, r.rule_id
      INTO v_resolved_rate, v_resolved_max, v_resolved_currency, v_resolved_rule_id
      FROM app.fn_resolve_commission_rate(
          v_payment.payment_reason::TEXT,
          COALESCE(v_degree_level, '*')
      ) r;

      -- Skip if rate is 0
      IF v_resolved_rate > 0 THEN
        -- Check commission cap per prospect
        SELECT cap.allowed, cap.commission_number, cap.adjusted_rate
        INTO v_cap_allowed, v_cap_number, v_cap_adjusted_rate
        FROM app.fn_check_commission_cap(v_commercial_user_id, v_payment.student_id) cap;

        IF v_cap_allowed THEN
          -- Apply degressive rate: min(resolved_rate, cap_adjusted_rate)
          v_final_rate := LEAST(v_resolved_rate, v_cap_adjusted_rate);

          -- Calculate commission amount
          v_commission_amount := ROUND(v_payment.amount_paid * v_final_rate, 0);

          -- Apply max_amount cap
          IF v_resolved_max > 0 AND v_commission_amount > v_resolved_max THEN
            v_commission_amount := v_resolved_max;
          END IF;

          -- Avoid duplicate commissions for same payment
          IF NOT EXISTS (
            SELECT 1 FROM app.referral_commissions
            WHERE payment_id = v_payment.id AND commercial_user_id = v_commercial_user_id
          ) THEN
            INSERT INTO app.referral_commissions (
              id, commercial_user_id, student_id, payment_id,
              commission_rate, commission_amount, currency, status, created_at
            ) VALUES (
              gen_random_uuid(), v_commercial_user_id, v_payment.student_id, v_payment.id,
              v_final_rate, v_commission_amount, COALESCE(v_resolved_currency, v_payment.currency),
              'pending', NOW()
            )
            RETURNING id INTO v_commission_id;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'receipt_id', v_receipt_id,
    'receipt_number', v_receipt_number,
    'commission_created', v_commission_id IS NOT NULL,
    'commission_id', v_commission_id,
    'commission_amount', v_commission_amount
  );
END;
$$
"""))

# ─────────────────────────────────────────────────────────────────────
# 5. Admin RPC: List commission rules
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create app_admin_list_commission_rules", """
CREATE OR REPLACE FUNCTION public.app_admin_list_commission_rules()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_result JSONB;
BEGIN
    SELECT raw_user_meta_data->>'role' INTO v_role
    FROM auth.users WHERE id = v_user_id;

    IF v_role IS NULL OR v_role NOT IN ('admin', 'super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authorized');
    END IF;

    SELECT COALESCE(JSONB_AGG(row_to_json(cr)::JSONB ORDER BY cr.priority DESC, cr.payment_reason, cr.degree_level), '[]'::JSONB)
    INTO v_result
    FROM app.commission_rules cr;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'rules', v_result);
END;
$$
"""))

# ─────────────────────────────────────────────────────────────────────
# 6. Admin RPC: Upsert commission rule
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create app_admin_upsert_commission_rule", """
CREATE OR REPLACE FUNCTION public.app_admin_upsert_commission_rule(
    p_payment_reason TEXT,
    p_degree_level TEXT,
    p_commission_rate NUMERIC,
    p_max_amount NUMERIC DEFAULT 0,
    p_description TEXT DEFAULT NULL,
    p_priority INTEGER DEFAULT 0,
    p_is_active BOOLEAN DEFAULT TRUE
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_rule_id UUID;
BEGIN
    SELECT raw_user_meta_data->>'role' INTO v_role
    FROM auth.users WHERE id = v_user_id;

    IF v_role IS NULL OR v_role NOT IN ('admin', 'super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authorized');
    END IF;

    IF p_commission_rate < 0 OR p_commission_rate > 1 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_rate');
    END IF;

    INSERT INTO app.commission_rules (
        payment_reason, degree_level, commission_rate, max_amount,
        description, priority, is_active, updated_at
    ) VALUES (
        COALESCE(p_payment_reason, '*'), COALESCE(p_degree_level, '*'),
        p_commission_rate, COALESCE(p_max_amount, 0),
        p_description, COALESCE(p_priority, 0), p_is_active, NOW()
    )
    ON CONFLICT (payment_reason, degree_level) DO UPDATE SET
        commission_rate = EXCLUDED.commission_rate,
        max_amount = EXCLUDED.max_amount,
        description = EXCLUDED.description,
        priority = EXCLUDED.priority,
        is_active = EXCLUDED.is_active,
        updated_at = NOW()
    RETURNING id INTO v_rule_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'rule_id', v_rule_id);
END;
$$
"""))

# ─────────────────────────────────────────────────────────────────────
# 7. Admin RPC: Delete commission rule
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create app_admin_delete_commission_rule", """
CREATE OR REPLACE FUNCTION public.app_admin_delete_commission_rule(p_rule_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
BEGIN
    SELECT raw_user_meta_data->>'role' INTO v_role
    FROM auth.users WHERE id = v_user_id;

    IF v_role IS NULL OR v_role NOT IN ('admin', 'super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authorized');
    END IF;

    DELETE FROM app.commission_rules WHERE id = p_rule_id;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'rule_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$
"""))

def main():
    print("=" * 60)
    print("  DEPLOYING COMMISSION RULES SYSTEM")
    print("  (Table + Resolution + Auto-create + Admin CRUD)")
    print("=" * 60)
    success = 0
    failed = 0
    for i, (label, ddl) in enumerate(STEPS, 1):
        print(f"\n  [{i}/{len(STEPS)}]", end=" ")
        if inject_ddl(label, ddl.strip()):
            success += 1
        else:
            failed += 1
        time.sleep(0.3)
    print(f"\n\n{'='*60}")
    print(f"  RESULT: {success}/{len(STEPS)} succeeded, {failed} failed")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
