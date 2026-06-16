#!/usr/bin/env python3
"""
Deploy hybrid commercial system:
- DB schema additions (tier columns, milestones table, commission cap enforcement)
- Enhanced RPC with gamification data
- Anti-abuse trigger (cap commissions per prospect with degressive rates)
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
# 1. Add tier + cap columns to commercial_profiles
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Add tier column to commercial_profiles", """
ALTER TABLE app.commercial_profiles
ADD COLUMN IF NOT EXISTS tier TEXT NOT NULL DEFAULT 'bronze'
"""))

STEPS.append(("Add max_commissions_per_prospect column", """
ALTER TABLE app.commercial_profiles
ADD COLUMN IF NOT EXISTS max_commissions_per_prospect INTEGER NOT NULL DEFAULT 3
"""))

STEPS.append(("Add total_confirmed_payments column (cached counter)", """
ALTER TABLE app.commercial_profiles
ADD COLUMN IF NOT EXISTS total_confirmed_payments INTEGER NOT NULL DEFAULT 0
"""))

# ─────────────────────────────────────────────────────────────────────
# 2. Create commercial_milestones config table
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create commercial_milestones table", """
CREATE TABLE IF NOT EXISTS app.commercial_milestones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    threshold INTEGER NOT NULL,
    bonus_amount NUMERIC NOT NULL DEFAULT 0,
    currency TEXT NOT NULL DEFAULT 'XOF',
    label TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
"""))

STEPS.append(("Insert default milestones", """
INSERT INTO app.commercial_milestones (threshold, bonus_amount, label, description)
VALUES
    (5,  5000,  'Premier palier',  '5 paiements confirmés — Bonus de 5 000 XOF'),
    (15, 20000, 'Palier Argent',   '15 paiements confirmés — Bonus de 20 000 XOF'),
    (30, 50000, 'Palier Or',       '30 paiements confirmés — Bonus de 50 000 XOF'),
    (50, 100000,'Palier Diamant',  '50 paiements confirmés — Bonus de 100 000 XOF')
ON CONFLICT DO NOTHING
"""))

# ─────────────────────────────────────────────────────────────────────
# 3. Create commercial_milestone_claims table (track claimed bonuses)
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create commercial_milestone_claims table", """
CREATE TABLE IF NOT EXISTS app.commercial_milestone_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    commercial_user_id UUID NOT NULL REFERENCES auth.users(id),
    milestone_id UUID NOT NULL REFERENCES app.commercial_milestones(id),
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'pending',
    paid_at TIMESTAMPTZ,
    UNIQUE(commercial_user_id, milestone_id)
)
"""))

# ─────────────────────────────────────────────────────────────────────
# 4. Trigger: auto-update tier + total_confirmed_payments on commission change
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create tier auto-update function", """
CREATE OR REPLACE FUNCTION app.fn_update_commercial_tier()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_commercial_id UUID;
    v_count INTEGER;
    v_new_tier TEXT;
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        v_commercial_id := NEW.commercial_user_id;
    ELSE
        v_commercial_id := OLD.commercial_user_id;
    END IF;

    SELECT COUNT(DISTINCT student_id) INTO v_count
    FROM app.referral_commissions
    WHERE commercial_user_id = v_commercial_id
      AND status IN ('pending', 'approved', 'paid');

    IF v_count >= 30 THEN v_new_tier := 'diamond';
    ELSIF v_count >= 15 THEN v_new_tier := 'gold';
    ELSIF v_count >= 5 THEN v_new_tier := 'silver';
    ELSE v_new_tier := 'bronze';
    END IF;

    UPDATE app.commercial_profiles
    SET tier = v_new_tier,
        total_confirmed_payments = (
            SELECT COUNT(*) FROM app.referral_commissions
            WHERE commercial_user_id = v_commercial_id
              AND status IN ('pending', 'approved', 'paid')
        ),
        updated_at = NOW()
    WHERE user_id = v_commercial_id;

    RETURN COALESCE(NEW, OLD);
END;
$$
"""))

STEPS.append(("Create tier trigger on referral_commissions", """
DROP TRIGGER IF EXISTS trg_update_commercial_tier ON app.referral_commissions
"""))

STEPS.append(("Create tier trigger on referral_commissions (create)", """
CREATE TRIGGER trg_update_commercial_tier
AFTER INSERT OR UPDATE OR DELETE ON app.referral_commissions
FOR EACH ROW EXECUTE FUNCTION app.fn_update_commercial_tier()
"""))

# ─────────────────────────────────────────────────────────────────────
# 5. Function: check commission cap before creating commission
#    (called by the payment confirmation trigger)
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create commission cap check function", """
CREATE OR REPLACE FUNCTION app.fn_check_commission_cap(
    p_commercial_user_id UUID,
    p_student_id UUID
) RETURNS TABLE(allowed BOOLEAN, commission_number INTEGER, adjusted_rate NUMERIC)
LANGUAGE plpgsql SECURITY DEFINER AS $$
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
    IF v_base_rate IS NULL THEN v_base_rate := 0.15; END IF;

    SELECT COUNT(*) INTO v_existing_count
    FROM app.referral_commissions
    WHERE commercial_user_id = p_commercial_user_id
      AND student_id = p_student_id;

    IF v_existing_count >= v_max_cap THEN
        RETURN QUERY SELECT FALSE, v_existing_count + 1, 0::NUMERIC;
        RETURN;
    END IF;

    v_adjusted := v_base_rate * POWER(0.85, v_existing_count);
    IF v_adjusted < 0.05 THEN v_adjusted := 0.05; END IF;

    RETURN QUERY SELECT TRUE, v_existing_count + 1, ROUND(v_adjusted, 4);
    RETURN;
END;
$$
"""))

# ─────────────────────────────────────────────────────────────────────
# 6. Enhanced commercial dashboard RPC v3 — with gamification
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Commercial dashboard RPC v3 (gamification + caps)", """
CREATE OR REPLACE FUNCTION public.app_commercial_get_dashboard()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile JSONB;
    v_summary JSONB;
    v_referrals JSONB;
    v_commissions JSONB;
    v_prospect_payments JSONB;
    v_gamification JSONB;
    v_leaderboard JSONB;
    v_tier TEXT;
    v_total_confirmed INTEGER;
    v_max_cap INTEGER;
    v_base_rate NUMERIC;
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

    v_tier := COALESCE(v_profile->>'tier', 'bronze');
    v_total_confirmed := COALESCE((v_profile->>'total_confirmed_payments')::INTEGER, 0);
    v_max_cap := COALESCE((v_profile->>'max_commissions_per_prospect')::INTEGER, 3);
    v_base_rate := COALESCE((v_profile->>'commission_rate')::NUMERIC, 0.15);

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

    -- Gamification data
    SELECT JSONB_BUILD_OBJECT(
        'tier', v_tier,
        'total_confirmed_payments', v_total_confirmed,
        'max_commissions_per_prospect', v_max_cap,
        'base_commission_rate', v_base_rate,
        'tier_thresholds', JSONB_BUILD_OBJECT(
            'bronze', 0, 'silver', 5, 'gold', 15, 'diamond', 30
        ),
        'next_tier', CASE
            WHEN v_tier = 'bronze' THEN 'silver'
            WHEN v_tier = 'silver' THEN 'gold'
            WHEN v_tier = 'gold' THEN 'diamond'
            ELSE NULL
        END,
        'next_tier_threshold', CASE
            WHEN v_tier = 'bronze' THEN 5
            WHEN v_tier = 'silver' THEN 15
            WHEN v_tier = 'gold' THEN 30
            ELSE NULL
        END,
        'milestones', (
            SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.threshold), '[]'::JSONB)
            FROM (
                SELECT m.id, m.threshold, m.bonus_amount, m.currency, m.label, m.description,
                       CASE WHEN mc.id IS NOT NULL THEN TRUE ELSE FALSE END AS claimed,
                       mc.status AS claim_status,
                       mc.paid_at AS claim_paid_at,
                       CASE WHEN v_total_confirmed >= m.threshold THEN TRUE ELSE FALSE END AS reached
                FROM app.commercial_milestones m
                LEFT JOIN app.commercial_milestone_claims mc
                    ON mc.milestone_id = m.id AND mc.commercial_user_id = v_user_id
            ) t
        )
    ) INTO v_gamification;

    -- Leaderboard: top 10 commercials this month (anonymized)
    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY t.rank), '[]'::JSONB)
    INTO v_leaderboard
    FROM (
        SELECT
            ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rank,
            cp.tier,
            COUNT(*) AS score,
            CASE WHEN cp.user_id = v_user_id THEN TRUE ELSE FALSE END AS is_me
        FROM app.referral_commissions rc
        JOIN app.commercial_profiles cp ON cp.user_id = rc.commercial_user_id
        WHERE rc.created_at >= date_trunc('month', NOW())
          AND rc.status IN ('pending', 'approved', 'paid')
        GROUP BY cp.user_id, cp.tier
        ORDER BY COUNT(*) DESC
        LIMIT 10
    ) t;

    -- Referrals: ANONYMIZED
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
            ), 0) AS applications_count,
            COALESCE((
                SELECT COUNT(*) FROM app.referral_commissions rc
                WHERE rc.commercial_user_id = v_user_id AND rc.student_id = ur.student_id
            ), 0) AS commissions_earned,
            v_max_cap AS commissions_cap
        FROM app.user_referrals ur
        WHERE ur.commercial_user_id = v_user_id
    ) t;

    -- Commissions: ANONYMIZED
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

    -- Prospect payments: ANONYMIZED
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
        'gamification', v_gamification,
        'leaderboard', v_leaderboard,
        'referrals', v_referrals,
        'commissions', v_commissions,
        'prospect_payments', v_prospect_payments
    );
END;
$$
"""))

# ─────────────────────────────────────────────────────────────────────
# 7. RPC to claim a milestone bonus
# ─────────────────────────────────────────────────────────────────────
STEPS.append(("Create milestone claim RPC", """
CREATE OR REPLACE FUNCTION public.app_commercial_claim_milestone(p_milestone_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_threshold INTEGER;
    v_total INTEGER;
    v_existing UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT threshold INTO v_threshold
    FROM app.commercial_milestones WHERE id = p_milestone_id;

    IF v_threshold IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'milestone_not_found');
    END IF;

    SELECT total_confirmed_payments INTO v_total
    FROM app.commercial_profiles WHERE user_id = v_user_id;

    IF v_total IS NULL OR v_total < v_threshold THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'threshold_not_reached');
    END IF;

    SELECT id INTO v_existing
    FROM app.commercial_milestone_claims
    WHERE commercial_user_id = v_user_id AND milestone_id = p_milestone_id;

    IF v_existing IS NOT NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'already_claimed');
    END IF;

    INSERT INTO app.commercial_milestone_claims (commercial_user_id, milestone_id)
    VALUES (v_user_id, p_milestone_id);

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$
"""))

def main():
    print("=" * 60)
    print("  DEPLOYING HYBRID COMMERCIAL SYSTEM")
    print("  (Tiers + Caps + Milestones + Leaderboard + Anti-abuse)")
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
