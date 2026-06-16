#!/usr/bin/env python3
"""
Deploy admin RPCs for the new commercial hybrid system:
1. Enrich app_admin_list_commercials_overview with tier/cap/total_confirmed
2. Enrich app_admin_get_commercial_detail with tier/cap/milestones
3. New: app_admin_list_milestone_claims (all pending claims across commercials)
4. New: app_admin_update_milestone_claim_status (approve/pay/reject a claim)
5. New: app_admin_update_commercial_cap (change max_commissions_per_prospect)
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
# 1. Enrich commercials overview with tier, cap, total_confirmed
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Enrich app_admin_list_commercials_overview", """
CREATE OR REPLACE FUNCTION public.app_admin_list_commercials_overview()
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

    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.total_confirmed_payments DESC), '[]'::JSONB)
    INTO v_result
    FROM (
        SELECT
            cp.user_id,
            u.email,
            u.raw_user_meta_data->>'full_name' AS full_name,
            cp.ref_code,
            cp.ref_link,
            cp.commission_rate,
            cp.is_active,
            cp.tier,
            cp.max_commissions_per_prospect,
            cp.total_confirmed_payments,
            cp.created_at,
            (SELECT COUNT(*) FROM app.user_referrals ur WHERE ur.commercial_user_id = cp.user_id) AS students_count,
            COALESCE((SELECT SUM(rc.commission_amount) FROM app.referral_commissions rc WHERE rc.commercial_user_id = cp.user_id AND rc.status = 'pending'), 0) AS total_commission_pending,
            COALESCE((SELECT SUM(rc.commission_amount) FROM app.referral_commissions rc WHERE rc.commercial_user_id = cp.user_id AND rc.status = 'approved'), 0) AS total_commission_approved,
            COALESCE((SELECT SUM(rc.commission_amount) FROM app.referral_commissions rc WHERE rc.commercial_user_id = cp.user_id AND rc.status = 'paid'), 0) AS total_commission_paid,
            (SELECT COUNT(*) FROM app.commercial_milestone_claims mc WHERE mc.commercial_user_id = cp.user_id AND mc.status = 'pending') AS pending_milestone_claims
        FROM app.commercial_profiles cp
        JOIN auth.users u ON u.id = cp.user_id
    ) t;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'commercials', v_result);
END;
$$
"""))

# ─────────────────────────────────────────────────────────────────────
# 2. Enrich commercial detail with tier, cap, milestones
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Enrich app_admin_get_commercial_detail", """
CREATE OR REPLACE FUNCTION public.app_admin_get_commercial_detail(p_commercial_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_commercial JSONB;
    v_referrals JSONB;
    v_commissions JSONB;
    v_milestone_claims JSONB;
BEGIN
    SELECT raw_user_meta_data->>'role' INTO v_role
    FROM auth.users WHERE id = v_user_id;

    IF v_role IS NULL OR v_role NOT IN ('admin', 'super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authorized');
    END IF;

    SELECT row_to_json(t)::JSONB INTO v_commercial
    FROM (
        SELECT
            cp.user_id, u.email,
            u.raw_user_meta_data->>'full_name' AS full_name,
            cp.ref_code, cp.ref_link, cp.commission_rate,
            cp.is_active, cp.tier,
            cp.max_commissions_per_prospect,
            cp.total_confirmed_payments,
            cp.created_at
        FROM app.commercial_profiles cp
        JOIN auth.users u ON u.id = cp.user_id
        WHERE cp.user_id = p_commercial_user_id
    ) t;

    IF v_commercial IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'commercial_not_found');
    END IF;

    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.attributed_at DESC), '[]'::JSONB)
    INTO v_referrals
    FROM (
        SELECT ur.id, ur.student_id, ur.ref_code, ur.source,
               ur.attributed_at, ur.expires_at,
               s.full_name AS student_name,
               (SELECT COUNT(*) FROM app.referral_commissions rc
                WHERE rc.commercial_user_id = p_commercial_user_id AND rc.student_id = ur.student_id) AS commissions_count
        FROM app.user_referrals ur
        LEFT JOIN app.students s ON s.id = ur.student_id
        WHERE ur.commercial_user_id = p_commercial_user_id
    ) t;

    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.created_at DESC), '[]'::JSONB)
    INTO v_commissions
    FROM (
        SELECT rc.id, rc.student_id, rc.payment_id,
               rc.commission_rate, rc.commission_amount, rc.currency,
               rc.status, rc.created_at, rc.approved_at, rc.paid_at, rc.admin_note,
               s.full_name AS student_name
        FROM app.referral_commissions rc
        LEFT JOIN app.students s ON s.id = rc.student_id
        WHERE rc.commercial_user_id = p_commercial_user_id
    ) t;

    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.claimed_at DESC), '[]'::JSONB)
    INTO v_milestone_claims
    FROM (
        SELECT mc.id, mc.milestone_id, mc.claimed_at, mc.status, mc.paid_at,
               m.threshold, m.bonus_amount, m.currency, m.label
        FROM app.commercial_milestone_claims mc
        JOIN app.commercial_milestones m ON m.id = mc.milestone_id
        WHERE mc.commercial_user_id = p_commercial_user_id
    ) t;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'data', JSONB_BUILD_OBJECT(
            'commercial', v_commercial,
            'referrals', v_referrals,
            'commissions', v_commissions,
            'milestone_claims', v_milestone_claims
        )
    );
END;
$$
"""))

# ─────────────────────────────────────────────────────────────────────
# 3. List all pending milestone claims (across all commercials)
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create app_admin_list_milestone_claims", """
CREATE OR REPLACE FUNCTION public.app_admin_list_milestone_claims(p_status TEXT DEFAULT 'pending')
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

    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.claimed_at DESC), '[]'::JSONB)
    INTO v_result
    FROM (
        SELECT
            mc.id AS claim_id,
            mc.commercial_user_id,
            u.email AS commercial_email,
            u.raw_user_meta_data->>'full_name' AS commercial_name,
            cp.ref_code,
            cp.tier,
            mc.milestone_id,
            m.threshold,
            m.bonus_amount,
            m.currency,
            m.label AS milestone_label,
            mc.claimed_at,
            mc.status,
            mc.paid_at,
            cp.total_confirmed_payments
        FROM app.commercial_milestone_claims mc
        JOIN app.commercial_milestones m ON m.id = mc.milestone_id
        JOIN auth.users u ON u.id = mc.commercial_user_id
        JOIN app.commercial_profiles cp ON cp.user_id = mc.commercial_user_id
        WHERE mc.status = p_status OR p_status = 'all'
    ) t;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'claims', v_result);
END;
$$
"""))

# ─────────────────────────────────────────────────────────────────────
# 4. Update milestone claim status (paid / rejected)
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create app_admin_update_milestone_claim_status", """
CREATE OR REPLACE FUNCTION public.app_admin_update_milestone_claim_status(
    p_claim_id UUID,
    p_new_status TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
BEGIN
    SELECT raw_user_meta_data->>'role' INTO v_role
    FROM auth.users WHERE id = v_user_id;

    IF v_role IS NULL OR v_role NOT IN ('admin', 'super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authorized');
    END IF;

    IF p_new_status NOT IN ('paid', 'rejected') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    UPDATE app.commercial_milestone_claims
    SET status = p_new_status,
        paid_at = CASE WHEN p_new_status = 'paid' THEN NOW() ELSE paid_at END
    WHERE id = p_claim_id;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'claim_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$
"""))

# ─────────────────────────────────────────────────────────────────────
# 5. Update commercial cap (max_commissions_per_prospect)
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create app_admin_update_commercial_cap", """
CREATE OR REPLACE FUNCTION public.app_admin_update_commercial_cap(
    p_user_id UUID,
    p_max_cap INTEGER
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
BEGIN
    SELECT raw_user_meta_data->>'role' INTO v_role
    FROM auth.users WHERE id = v_user_id;

    IF v_role IS NULL OR v_role NOT IN ('admin', 'super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authorized');
    END IF;

    IF p_max_cap < 1 OR p_max_cap > 20 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_cap_value');
    END IF;

    UPDATE app.commercial_profiles
    SET max_commissions_per_prospect = p_max_cap, updated_at = NOW()
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'commercial_not_found');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$
"""))

def main():
    print("=" * 60)
    print("  DEPLOYING ADMIN COMMERCIAL RPCs")
    print("  (Overview + Detail + Milestones + Cap management)")
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
