#!/usr/bin/env python3
"""AUDIT COMPLET MULTI-PLATEFORME — Flux commercial/referral.
Cartographie: schémas, tables, colonnes, RPCs, triggers, indexes, contraintes, RLS, données."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def q(label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    rows = d.get("rows", []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    print(f"\n{'='*70}\n{label}\n{'='*70}")
    if not ok:
        print(f"ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:600]}")
    for row in rows[:30]:
        print(json.dumps(row, ensure_ascii=False, default=str)[:600])
    if ok and not rows: print("(0 rows)")
    return rows

print("=" * 70)
print("AUDIT COMPLET — FLUX COMMERCIAL / REFERRAL / MULTI-PLATEFORME")
print("=" * 70)

# ═══════════════════════════════════════════════════════════════
# SECTION 1: CARTOGRAPHIE DES TABLES
# ═══════════════════════════════════════════════════════════════

q("1.1 TOUTES les tables impliquées dans le flux commercial", """
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'app'
AND (table_name LIKE '%commercial%' OR table_name LIKE '%referral%'
     OR table_name LIKE '%commission%' OR table_name LIKE '%milestone%'
     OR table_name LIKE '%invitation%' OR table_name = 'students'
     OR table_name = 'applications' OR table_name = 'application_payments'
     OR table_name = 'programs' OR table_name = 'payment_receipts')
ORDER BY table_name
""")

# 1.2 Colonnes de chaque table critique
for tbl in ['commercial_profiles', 'user_referrals', 'referral_commissions',
            'commission_rules', 'commercial_milestones', 'commercial_milestone_claims',
            'user_invitations', 'students', 'applications', 'application_payments']:
    q(f"1.2 Colonnes de app.{tbl}", f"""
    SELECT column_name, data_type, column_default, is_nullable
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='{tbl}'
    ORDER BY ordinal_position
    """)

# ═══════════════════════════════════════════════════════════════
# SECTION 2: CONTRAINTES ET INDEXES
# ═══════════════════════════════════════════════════════════════

for tbl in ['commercial_profiles', 'user_referrals', 'referral_commissions']:
    q(f"2.1 Contraintes sur app.{tbl}", f"""
    SELECT conname, pg_get_constraintdef(c.oid) AS definition
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE n.nspname = 'app' AND t.relname = '{tbl}'
    ORDER BY conname
    """)
    q(f"2.2 Indexes sur app.{tbl}", f"""
    SELECT indexname, indexdef FROM pg_indexes
    WHERE schemaname='app' AND tablename='{tbl}'
    """)

# ═══════════════════════════════════════════════════════════════
# SECTION 3: TOUTES LES RPCs DU FLUX
# ═══════════════════════════════════════════════════════════════

q("3.1 TOUTES les RPCs commerciales/referral", """
SELECT p.proname, n.nspname, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE (p.proname LIKE '%commercial%' OR p.proname LIKE '%referral%'
       OR p.proname LIKE '%commission%' OR p.proname LIKE '%milestone%')
AND n.nspname IN ('public', 'app')
ORDER BY p.proname
""")

# ═══════════════════════════════════════════════════════════════
# SECTION 4: TRIGGERS
# ═══════════════════════════════════════════════════════════════

q("4.1 TOUS les triggers liés au flux commercial", """
SELECT t.tgname, c.relname AS table_name, p.proname AS func_name,
       t.tgenabled AS enabled,
       CASE t.tgtype & 2 WHEN 2 THEN 'BEFORE' ELSE 'AFTER' END AS timing,
       CASE t.tgtype & 28
         WHEN 4 THEN 'INSERT' WHEN 8 THEN 'DELETE' WHEN 16 THEN 'UPDATE'
         WHEN 20 THEN 'INSERT OR UPDATE' WHEN 28 THEN 'ALL'
         ELSE 'OTHER' END AS event
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE n.nspname = 'app'
  AND (c.relname IN ('referral_commissions', 'user_referrals', 'application_payments',
                      'commercial_profiles', 'commercial_milestone_claims')
       OR p.proname LIKE '%referral%' OR p.proname LIKE '%commission%' OR p.proname LIKE '%commercial%')
  AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname
""")

# ═══════════════════════════════════════════════════════════════
# SECTION 5: RLS POLICIES
# ═══════════════════════════════════════════════════════════════

q("5.1 RLS sur tables commerciales", """
SELECT tablename, policyname, permissive, roles, cmd,
       LEFT(qual::text, 120) AS qual
FROM pg_policies
WHERE schemaname='app'
AND tablename IN ('commercial_profiles','user_referrals','referral_commissions',
                   'commission_rules','commercial_milestones','commercial_milestone_claims','user_invitations')
ORDER BY tablename, policyname
""")

# ═══════════════════════════════════════════════════════════════
# SECTION 6: DONNÉES RÉELLES
# ═══════════════════════════════════════════════════════════════

q("6.1 commercial_profiles (tous)", """
SELECT cp.user_id::text, u.email, cp.ref_code, cp.ref_link,
       cp.commission_rate, cp.is_active, cp.tier,
       cp.max_commissions_per_prospect, cp.total_confirmed_payments
FROM app.commercial_profiles cp
JOIN auth.users u ON u.id = cp.user_id
ORDER BY cp.created_at
""")

q("6.2 user_referrals (tous)", """
SELECT ur.id::text, ur.student_id::text, ur.commercial_user_id::text,
       ur.ref_code, ur.source, ur.attributed_at,
       u_s.email AS student_email, u_c.email AS commercial_email,
       s.full_name AS student_name
FROM app.user_referrals ur
LEFT JOIN auth.users u_s ON u_s.id = ur.student_id
LEFT JOIN auth.users u_c ON u_c.id = ur.commercial_user_id
LEFT JOIN app.students s ON s.id = ur.student_id
ORDER BY ur.attributed_at DESC
""")

q("6.3 referral_commissions (tous)", """
SELECT rc.id::text, rc.commercial_user_id::text, rc.student_id::text,
       rc.payment_id::text, rc.commission_rate, rc.commission_amount,
       rc.currency, rc.status, rc.created_at
FROM app.referral_commissions rc
ORDER BY rc.created_at DESC
""")

q("6.4 commission_rules (toutes)", """
SELECT id::text, payment_reason, degree_level, commission_rate, max_amount,
       currency, is_active, priority, LEFT(description, 50) AS description
FROM app.commission_rules
ORDER BY payment_reason, degree_level
""")

q("6.5 commercial_milestones", """
SELECT * FROM app.commercial_milestones ORDER BY threshold
""")

q("6.6 commercial_milestone_claims", """
SELECT * FROM app.commercial_milestone_claims ORDER BY claimed_at DESC
""")

# ═══════════════════════════════════════════════════════════════
# SECTION 7: VÉRIFICATION DU FLUX — CAS angeautoecole
# ═══════════════════════════════════════════════════════════════

q("7.1 angeautoecole — auth.users", """
SELECT id::text, email, raw_user_meta_data->>'role' AS role,
       raw_user_meta_data->>'full_name' AS full_name,
       raw_user_meta_data->>'ref_code' AS metadata_ref_code,
       created_at, confirmed_at, email_confirmed_at
FROM auth.users WHERE email = 'angeautoecole@gmail.com'
""")

q("7.2 angeautoecole — app.students", """
SELECT s.id::text, s.full_name FROM app.students s
WHERE s.id = (SELECT id FROM auth.users WHERE email = 'angeautoecole@gmail.com')
""")

q("7.3 angeautoecole — user_referrals", """
SELECT * FROM app.user_referrals
WHERE student_id = (SELECT id FROM auth.users WHERE email = 'angeautoecole@gmail.com')
""")

q("7.4 julesdekaya (kayadejule) — profil commercial", """
SELECT cp.*, u.email FROM app.commercial_profiles cp
JOIN auth.users u ON u.id = cp.user_id
WHERE u.email = 'kayadejule@gmail.com'
""")

# ═══════════════════════════════════════════════════════════════
# SECTION 8: VÉRIFICATION SUPABASE AUTH CONFIG
# ═══════════════════════════════════════════════════════════════

q("8.1 Supabase auth redirect URLs configured", """
SELECT key, value FROM auth.config WHERE key IN ('SITE_URL', 'ADDITIONAL_REDIRECT_URLS', 'URI_ALLOW_LIST')
""")

q("8.2 Recent auth events for angeautoecole", """
SELECT id::text, factor_id::text, created_at, updated_at, authentication_method
FROM auth.mfa_factors
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'angeautoecole@gmail.com')
ORDER BY created_at DESC LIMIT 5
""")

# ═══════════════════════════════════════════════════════════════
# SECTION 9: VÉRIFICATION MULTI-PLATEFORME
# ═══════════════════════════════════════════════════════════════

q("9.1 Tous les comptes créés depuis 7 jours — vérifier metadata ref_code", """
SELECT id::text, email,
       raw_user_meta_data->>'role' AS role,
       raw_user_meta_data->>'ref_code' AS metadata_ref_code,
       created_at
FROM auth.users
WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY created_at DESC
""")

print("\n" + "="*70)
print("AUDIT COMPLET TERMINÉ")
print("="*70)
