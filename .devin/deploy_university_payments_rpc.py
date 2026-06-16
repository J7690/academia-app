#!/usr/bin/env python3
"""Deploy RPC for university payments listing + commercial dashboard enrichment."""
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
        print(f"  ❌ {label}: {result['error'][:200]}")
        return False
    else:
        print(f"  ✅ {label}")
        return True

STEPS = []

# 1. University list payments RPC
STEPS.append(("University list payments RPC", """
CREATE OR REPLACE FUNCTION public.app_university_list_payments()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_uni_id UUID;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT (raw_user_meta_data->>'university_id')::UUID INTO v_uni_id
    FROM auth.users WHERE id = v_user_id;

    IF v_uni_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_university_id');
    END IF;

    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.created_at DESC), '[]'::JSONB)
    INTO v_result
    FROM (
        SELECT
            ap.id, ap.application_id, ap.student_id, ap.university_id,
            ap.amount_due, ap.amount_paid, ap.currency, ap.payment_reason,
            ap.channel, ap.status, ap.reference_code, ap.external_reference,
            ap.student_note, ap.created_at, ap.updated_at,
            ap.declared_at, ap.verified_at, ap.confirmed_at,
            s.full_name AS student_name,
            p.name AS program_name
        FROM app.application_payments ap
        LEFT JOIN app.students s ON s.id = ap.student_id
        LEFT JOIN app.applications a ON a.id = ap.application_id
        LEFT JOIN app.programs p ON p.id = a.program_id
        WHERE ap.university_id = v_uni_id
    ) t;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'payments', v_result);
END;
$$
"""))

# 2. Commercial dashboard enriched RPC (with student names)
STEPS.append(("Commercial enriched referrals RPC", """
CREATE OR REPLACE FUNCTION public.app_commercial_get_dashboard()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile JSONB;
    v_summary JSONB;
    v_referrals JSONB;
    v_commissions JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT row_to_json(cp)::JSONB INTO v_profile
    FROM app.commercial_profiles cp
    WHERE cp.user_id = v_user_id;

    IF v_profile IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_commercial_profile');
    END IF;

    SELECT JSONB_BUILD_OBJECT(
        'students_count', (SELECT COUNT(*) FROM app.user_referrals WHERE commercial_user_id = v_user_id),
        'payments_confirmed_count', (
            SELECT COUNT(*) FROM app.application_payments ap
            JOIN app.user_referrals ur ON ur.student_id = ap.student_id AND ur.commercial_user_id = v_user_id
            WHERE ap.status = 'confirmed'
        ),
        'total_commission_pending', COALESCE((
            SELECT SUM(commission_amount) FROM app.referral_commissions
            WHERE commercial_user_id = v_user_id AND status = 'pending'
        ), 0),
        'total_commission_paid', COALESCE((
            SELECT SUM(commission_amount) FROM app.referral_commissions
            WHERE commercial_user_id = v_user_id AND status = 'paid'
        ), 0)
    ) INTO v_summary;

    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.attributed_at DESC), '[]'::JSONB)
    INTO v_referrals
    FROM (
        SELECT ur.id, ur.student_id, ur.ref_code, ur.source,
               ur.attributed_at, ur.expires_at, ur.metadata,
               s.full_name AS student_name,
               s.phone AS student_phone
        FROM app.user_referrals ur
        LEFT JOIN app.students s ON s.id = ur.student_id
        WHERE ur.commercial_user_id = v_user_id
    ) t;

    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.created_at DESC), '[]'::JSONB)
    INTO v_commissions
    FROM (
        SELECT rc.id, rc.student_id, rc.payment_id,
               rc.commission_rate, rc.commission_amount, rc.currency,
               rc.status, rc.created_at, rc.approved_at, rc.paid_at,
               rc.admin_note,
               s.full_name AS student_name
        FROM app.referral_commissions rc
        LEFT JOIN app.students s ON s.id = rc.student_id
        WHERE rc.commercial_user_id = v_user_id
    ) t;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'profile', v_profile,
        'summary', v_summary,
        'referrals', v_referrals,
        'commissions', v_commissions
    );
END;
$$
"""))

def main():
    print("=" * 60)
    print("  DEPLOYING UNIVERSITY + COMMERCIAL RPCs")
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
