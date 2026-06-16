#!/usr/bin/env python3
"""AUDIT COMPLET — Flux Commercial: tables, RPCs, liens personnalisés, prospects, commissions, referrals."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    rows = d.get('rows', []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    print(f"\n{'✅' if ok else '❌'} {label}")
    if not ok:
        print(f"  ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:600]}")
    for row in (rows or [])[:30]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:500]}")
    if ok and not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()
print("=" * 70)
print("AUDIT COMPLET — FLUX COMMERCIAL / ADMIN / PROSPECTS / COMMISSIONS")
print("=" * 70)

# ===== 1. TABLES COMMERCIALES =====
print("\n" + "=" * 70)
print("1. TABLES COMMERCIALES (schema app)")
print("=" * 70)

q(m, "1a. ALL tables containing 'commercial' or 'referral' or 'commission' or 'prospect'", """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
AND (table_name LIKE '%commercial%' OR table_name LIKE '%referral%'
     OR table_name LIKE '%commission%' OR table_name LIKE '%prospect%'
     OR table_name LIKE '%invitation%' OR table_name LIKE '%tier%'
     OR table_name LIKE '%milestone%' OR table_name LIKE '%leaderboard%')
ORDER BY table_name
""")

# ===== 2. COLONNES DE CHAQUE TABLE =====
print("\n" + "=" * 70)
print("2. COLONNES DE CHAQUE TABLE COMMERCIALE")
print("=" * 70)

for tbl in ['commercial_profiles', 'user_referrals', 'referral_commissions',
            'commission_rules', 'commercial_tiers', 'commercial_milestones',
            'user_invitations']:
    q(m, f"2. Columns of app.{tbl}", f"""
    SELECT column_name, data_type, column_default, is_nullable
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='{tbl}'
    ORDER BY ordinal_position
    """)

# ===== 3. RPCs COMMERCIALES =====
print("\n" + "=" * 70)
print("3. RPCs COMMERCIALES")
print("=" * 70)

q(m, "3a. ALL RPCs containing 'commercial' or 'referral' or 'commission' or 'invitation'", """
SELECT p.proname, n.nspname,
       pg_get_function_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE (p.proname LIKE '%commercial%' OR p.proname LIKE '%referral%'
       OR p.proname LIKE '%commission%' OR p.proname LIKE '%invitation%'
       OR p.proname LIKE '%prospect%' OR p.proname LIKE '%tier%'
       OR p.proname LIKE '%milestone%' OR p.proname LIKE '%leaderboard%')
AND n.nspname IN ('public', 'app')
ORDER BY p.proname
""")

# ===== 4. LIENS PERSONNALISES =====
print("\n" + "=" * 70)
print("4. LIENS PERSONNALISÉS / CODES REFERRAL")
print("=" * 70)

q(m, "4a. user_invitations structure", """
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema='app' AND table_name='user_invitations'
ORDER BY ordinal_position
""")

q(m, "4b. commercial_profiles — referral_code column exists?", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='commercial_profiles'
AND column_name LIKE '%code%'
""")

q(m, "4c. user_referrals — how referral links work", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='user_referrals'
ORDER BY ordinal_position
""")

# ===== 5. DONNÉES RÉELLES =====
print("\n" + "=" * 70)
print("5. DONNÉES RÉELLES")
print("=" * 70)

q(m, "5a. commercial_profiles count + sample", """
SELECT COUNT(*) AS total,
       COUNT(*) FILTER (WHERE is_active = true) AS active
FROM app.commercial_profiles
""")

q(m, "5b. commercial_profiles sample data", """
SELECT id, user_id, LEFT(referral_code, 20) AS ref_code, tier, is_active,
       total_referrals, confirmed_referrals, created_at
FROM app.commercial_profiles
ORDER BY created_at DESC LIMIT 5
""")

q(m, "5c. user_referrals count + sample", """
SELECT COUNT(*) AS total FROM app.user_referrals
""")

q(m, "5d. user_referrals sample", """
SELECT id, referrer_id, referred_user_id, LEFT(referral_code_used, 20) AS code_used,
       status, created_at
FROM app.user_referrals
ORDER BY created_at DESC LIMIT 10
""")

q(m, "5e. referral_commissions count + sample", """
SELECT COUNT(*) AS total,
       COUNT(*) FILTER (WHERE status = 'pending') AS pending,
       COUNT(*) FILTER (WHERE status = 'paid') AS paid,
       SUM(amount) AS total_amount
FROM app.referral_commissions
""")

q(m, "5f. referral_commissions sample", """
SELECT id, commercial_id, student_id, payment_id, amount, currency, status,
       commission_rate, created_at
FROM app.referral_commissions
ORDER BY created_at DESC LIMIT 10
""")

q(m, "5g. commission_rules count", """
SELECT COUNT(*) AS total FROM app.commission_rules
""")

q(m, "5h. commission_rules sample", """
SELECT id, payment_reason, degree_level, commission_rate, max_amount, currency,
       is_active, priority, LEFT(description, 40) AS description
FROM app.commission_rules
ORDER BY priority, payment_reason LIMIT 15
""")

q(m, "5i. commercial_tiers", """
SELECT * FROM app.commercial_tiers ORDER BY min_confirmed_referrals
""")

q(m, "5j. commercial_milestones", """
SELECT * FROM app.commercial_milestones ORDER BY threshold
""")

q(m, "5k. user_invitations count + sample", """
SELECT COUNT(*) AS total FROM app.user_invitations
""")

q(m, "5l. user_invitations sample", """
SELECT id, inviter_id, LEFT(invitation_code, 20) AS code, LEFT(target_email, 30) AS email,
       status, role, created_at
FROM app.user_invitations
ORDER BY created_at DESC LIMIT 10
""")

# ===== 6. RPC SOURCES (clés) =====
print("\n" + "=" * 70)
print("6. RPC SOURCES (fonctions clés)")
print("=" * 70)

for rpc in ['app_commercial_get_dashboard', 'app_commercial_get_referral_link',
            'app_commercial_get_prospects', 'app_commercial_get_commissions',
            'app_commercial_get_leaderboard', 'app_admin_list_commercials',
            'app_admin_create_commercial', 'app_attach_referral']:
    q(m, f"6. Source {rpc} (first 300 chars)", f"""
    SELECT LEFT(pg_get_functiondef(p.oid), 300) AS src
    FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = '{rpc}' AND n.nspname IN ('public', 'app')
    LIMIT 1
    """)

# ===== 7. RLS POLICIES =====
print("\n" + "=" * 70)
print("7. RLS POLICIES sur tables commerciales")
print("=" * 70)

q(m, "7. RLS policies", """
SELECT tablename, policyname, permissive, roles, cmd, LEFT(qual::text, 100) AS qual
FROM pg_policies
WHERE schemaname='app'
AND tablename IN ('commercial_profiles','user_referrals','referral_commissions',
                   'commission_rules','commercial_tiers','commercial_milestones','user_invitations')
ORDER BY tablename, policyname
""")

# ===== 8. TRIGGERS COMMERCIAUX =====
print("\n" + "=" * 70)
print("8. TRIGGERS COMMERCIAUX")
print("=" * 70)

q(m, "8. Triggers on commercial tables", """
SELECT trigger_name, event_object_table, event_manipulation,
       REPLACE(REPLACE(action_statement, 'EXECUTE FUNCTION ', ''), '()', '') AS func
FROM information_schema.triggers
WHERE event_object_schema = 'app'
AND (event_object_table LIKE '%commercial%' OR event_object_table LIKE '%referral%'
     OR event_object_table LIKE '%commission%' OR event_object_table LIKE '%invitation%')
ORDER BY event_object_table, trigger_name
""")

print(f"\n{'='*70}")
print("AUDIT SUPABASE COMMERCIAL TERMINÉ")
print(f"{'='*70}")
