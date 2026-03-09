#!/usr/bin/env python3
"""Deploy refactored commercial dashboard RPC — anonymized, with prospect payments."""
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

# Replace the commercial dashboard RPC with anonymized version
STEPS.append(("Commercial dashboard RPC v2 (anonymized + prospect_payments)", """
CREATE OR REPLACE FUNCTION public.app_commercial_get_dashboard()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile JSONB;
    v_summary JSONB;
    v_referrals JSONB;
    v_commissions JSONB;
    v_prospect_payments JSONB;
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

    -- Summary with financial breakdown
    SELECT JSONB_BUILD_OBJECT(
        'prospects_count', (SELECT COUNT(*) FROM app.user_referrals WHERE commercial_user_id = v_user_id),
        'prospects_with_application', (
            SELECT COUNT(DISTINCT ur.student_id)
            FROM app.user_referrals ur
            JOIN app.applications a ON a.student_id = ur.student_id
            WHERE ur.commercial_user_id = v_user_id
        ),
        'payments_confirmed_count', (
            SELECT COUNT(*) FROM app.application_payments ap
            JOIN app.user_referrals ur ON ur.student_id = ap.student_id AND ur.commercial_user_id = v_user_id
            WHERE ap.status = 'confirmed'
        ),
        'payments_pending_count', (
            SELECT COUNT(*) FROM app.application_payments ap
            JOIN app.user_referrals ur ON ur.student_id = ap.student_id AND ur.commercial_user_id = v_user_id
            WHERE ap.status IN ('declared_by_student', 'under_verification', 'pending')
        ),
        'total_commission_pending', COALESCE((
            SELECT SUM(commission_amount) FROM app.referral_commissions
            WHERE commercial_user_id = v_user_id AND status = 'pending'
        ), 0),
        'total_commission_approved', COALESCE((
            SELECT SUM(commission_amount) FROM app.referral_commissions
            WHERE commercial_user_id = v_user_id AND status = 'approved'
        ), 0),
        'total_commission_paid', COALESCE((
            SELECT SUM(commission_amount) FROM app.referral_commissions
            WHERE commercial_user_id = v_user_id AND status = 'paid'
        ), 0),
        'currency', COALESCE((
            SELECT currency FROM app.referral_commissions
            WHERE commercial_user_id = v_user_id LIMIT 1
        ), 'XOF')
    ) INTO v_summary;

    -- Referrals: ANONYMIZED — no name, no phone, just prospect_id + status
    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.attributed_at DESC), '[]'::JSONB)
    INTO v_referrals
    FROM (
        SELECT
            'PRO-' || LPAD(ROW_NUMBER() OVER (ORDER BY ur.attributed_at ASC)::TEXT, 3, '0') AS prospect_id,
            ur.attributed_at,
            ur.source,
            CASE
                WHEN EXISTS (
                    SELECT 1 FROM app.application_payments ap2
                    WHERE ap2.student_id = ur.student_id AND ap2.status = 'confirmed'
                ) THEN 'payment_confirmed'
                WHEN EXISTS (
                    SELECT 1 FROM app.application_payments ap2
                    WHERE ap2.student_id = ur.student_id AND ap2.status IN ('declared_by_student', 'under_verification')
                ) THEN 'payment_declared'
                WHEN EXISTS (
                    SELECT 1 FROM app.applications a
                    WHERE a.student_id = ur.student_id
                ) THEN 'has_application'
                ELSE 'registered_only'
            END AS prospect_status,
            COALESCE((
                SELECT COUNT(*) FROM app.applications a WHERE a.student_id = ur.student_id
            ), 0) AS applications_count
        FROM app.user_referrals ur
        WHERE ur.commercial_user_id = v_user_id
    ) t;

    -- Commissions: ANONYMIZED — prospect_id instead of student name
    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.created_at DESC), '[]'::JSONB)
    INTO v_commissions
    FROM (
        SELECT
            rc.id,
            'PRO-' || LPAD((
                SELECT ROW_NUMBER() OVER (ORDER BY ur2.attributed_at ASC)
                FROM app.user_referrals ur2
                WHERE ur2.commercial_user_id = v_user_id
                  AND ur2.student_id = rc.student_id
                LIMIT 1
            )::TEXT, 3, '0') AS prospect_id,
            rc.commission_rate,
            rc.commission_amount,
            rc.currency,
            rc.status,
            rc.created_at,
            rc.approved_at,
            rc.paid_at
        FROM app.referral_commissions rc
        WHERE rc.commercial_user_id = v_user_id
    ) t;

    -- Prospect payments: ANONYMIZED — what the commercial needs to track brokerage
    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.created_at DESC), '[]'::JSONB)
    INTO v_prospect_payments
    FROM (
        SELECT
            'PRO-' || LPAD((
                SELECT ROW_NUMBER() OVER (ORDER BY ur2.attributed_at ASC)
                FROM app.user_referrals ur2
                WHERE ur2.commercial_user_id = v_user_id
                  AND ur2.student_id = ap.student_id
                LIMIT 1
            )::TEXT, 3, '0') AS prospect_id,
            ap.payment_reason,
            ap.amount_paid,
            ap.currency,
            ap.status,
            ap.channel,
            ap.created_at,
            ap.confirmed_at,
            p.name AS program_name
        FROM app.application_payments ap
        JOIN app.user_referrals ur ON ur.student_id = ap.student_id AND ur.commercial_user_id = v_user_id
        LEFT JOIN app.applications a ON a.id = ap.application_id
        LEFT JOIN app.programs p ON p.id = a.program_id
    ) t;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'profile', v_profile,
        'summary', v_summary,
        'referrals', v_referrals,
        'commissions', v_commissions,
        'prospect_payments', v_prospect_payments
    );
END;
$$
"""))

def main():
    print("=" * 60)
    print("  DEPLOYING COMMERCIAL RPC v2 (ANONYMIZED)")
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
