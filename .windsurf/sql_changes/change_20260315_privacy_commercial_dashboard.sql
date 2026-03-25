-- FIX: Privacy enhancement for commercial dashboard
-- Removed: channel (private financial data of prospect)
-- Changed: amount_paid -> amount_range (tranche instead of exact amount)

CREATE OR REPLACE FUNCTION public.app_commercial_get_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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
            WHEN v_total_confirmed >= 30 THEN NULL
            WHEN v_total_confirmed >= 15 THEN 'diamond'
            WHEN v_total_confirmed >= 5 THEN 'gold'
            ELSE 'silver'
        END,
        'next_tier_threshold', CASE
            WHEN v_total_confirmed >= 30 THEN NULL
            WHEN v_total_confirmed >= 15 THEN 30
            WHEN v_total_confirmed >= 5 THEN 15
            ELSE 5
        END,
        'milestones', (
            SELECT COALESCE(JSONB_AGG(row_to_json(ms)::JSONB ORDER BY ms.threshold), '[]'::JSONB)
            FROM (
                SELECT m.id, m.threshold, m.bonus_amount, m.currency, m.label, m.description,
                       v_total_confirmed >= m.threshold AS reached,
                       EXISTS(SELECT 1 FROM app.commercial_milestone_claims mc
                              WHERE mc.commercial_user_id = v_user_id AND mc.milestone_id = m.id) AS claimed,
                       (SELECT mc2.status FROM app.commercial_milestone_claims mc2
                        WHERE mc2.commercial_user_id = v_user_id AND mc2.milestone_id = m.id LIMIT 1) AS claim_status
                FROM app.commercial_milestones m
            ) ms
        )
    ) INTO v_gamification;

    -- Leaderboard: anonymized, monthly
    SELECT COALESCE(JSONB_AGG(row_to_json(lb)::JSONB ORDER BY lb.rank), '[]'::JSONB)
    INTO v_leaderboard
    FROM (
        SELECT
            ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rank,
            cp.tier,
            COUNT(*) AS score,
            cp.user_id = v_user_id AS is_me
        FROM app.referral_commissions rc
        JOIN app.commercial_profiles cp ON cp.user_id = rc.commercial_user_id
        WHERE rc.created_at >= DATE_TRUNC('month', NOW())
        GROUP BY cp.user_id, cp.tier
        ORDER BY COUNT(*) DESC
        LIMIT 10
    ) lb;

    -- Referrals: ANONYMIZED (PRO-xxx, no PII)
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

    -- Prospect payments: ANONYMIZED + PRIVACY-ENHANCED
    -- REMOVED: channel (private financial data — no business need for commercial)
    -- CHANGED: amount_paid replaced by amount_range (tranche, not exact value)
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
            CASE
                WHEN ap.amount_paid IS NULL THEN NULL
                WHEN ap.amount_paid < 5000 THEN '< 5k'
                WHEN ap.amount_paid < 10000 THEN '5-10k'
                WHEN ap.amount_paid < 25000 THEN '10-25k'
                WHEN ap.amount_paid < 50000 THEN '25-50k'
                WHEN ap.amount_paid < 100000 THEN '50-100k'
                ELSE '100k+'
            END AS amount_range,
            ap.currency,
            ap.status,
            ap.created_at,
            ap.confirmed_at,
            p.title AS program_name
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
$function$;
