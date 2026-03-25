#!/usr/bin/env python3
"""AUDIT PART 2 — sections critiques manquantes de la sortie tronquée."""
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
    print(f"\n=== {label} ===")
    if not ok:
        print(f"ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:600]}")
    for row in rows[:20]:
        print(json.dumps(row, ensure_ascii=False, default=str)[:600])
    if ok and not rows: print("(0 rows)")
    return rows

# SECTION 7: CAS angeautoecole — CRITIQUE
q("7.1 angeautoecole user_metadata ref_code", """
SELECT id::text, email,
       raw_user_meta_data->>'role' AS role,
       raw_user_meta_data->>'full_name' AS full_name,
       raw_user_meta_data->>'ref_code' AS metadata_ref_code,
       created_at, confirmed_at
FROM auth.users WHERE email = 'angeautoecole@gmail.com'
""")

q("7.2 angeautoecole in app.students", """
SELECT s.id::text, s.full_name FROM app.students s
WHERE s.id = (SELECT id FROM auth.users WHERE email = 'angeautoecole@gmail.com')
""")

q("7.3 angeautoecole in user_referrals", """
SELECT ur.id::text, ur.student_id::text, ur.commercial_user_id::text, ur.ref_code, ur.source
FROM app.user_referrals ur
WHERE ur.student_id = (SELECT id FROM auth.users WHERE email = 'angeautoecole@gmail.com')
""")

# SECTION 4: Triggers — état actuel
q("4. Triggers on application_payments (enabled state)", """
SELECT t.tgname, t.tgenabled, p.proname
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE n.nspname = 'app' AND c.relname = 'application_payments'
AND NOT t.tgisinternal
ORDER BY t.tgname
""")

q("4b. Triggers on referral_commissions", """
SELECT t.tgname, t.tgenabled, p.proname
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE n.nspname = 'app' AND c.relname = 'referral_commissions'
AND NOT t.tgisinternal
ORDER BY t.tgname
""")

q("4c. Triggers on user_referrals", """
SELECT t.tgname, t.tgenabled, p.proname
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE n.nspname = 'app' AND c.relname = 'user_referrals'
AND NOT t.tgisinternal
ORDER BY t.tgname
""")

# SECTION 6: Données critiques
q("6.1 commercial_profiles (ALL)", """
SELECT cp.user_id::text, u.email, cp.ref_code, cp.ref_link,
       cp.commission_rate, cp.is_active, cp.tier, cp.total_confirmed_payments
FROM app.commercial_profiles cp
JOIN auth.users u ON u.id = cp.user_id ORDER BY cp.created_at
""")

q("6.2 user_referrals (ALL)", """
SELECT ur.id::text, ur.student_id::text, ur.commercial_user_id::text,
       ur.ref_code, ur.source, ur.attributed_at,
       u_s.email AS student_email, u_c.email AS commercial_email
FROM app.user_referrals ur
LEFT JOIN auth.users u_s ON u_s.id = ur.student_id
LEFT JOIN auth.users u_c ON u_c.id = ur.commercial_user_id
ORDER BY ur.attributed_at DESC
""")

q("6.3 referral_commissions (ALL)", """
SELECT COUNT(*) AS total FROM app.referral_commissions
""")

# SECTION: Vérifier les contraintes UNIQUE actuelles sur referral_commissions
q("CONTRAINTES referral_commissions", """
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname='app' AND tablename='referral_commissions' AND indexname LIKE '%unique%'
""")

# SECTION: Vérifier les contraintes UNIQUE sur user_referrals
q("CONTRAINTES user_referrals", """
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname='app' AND tablename='user_referrals' AND indexname LIKE '%unique%'
""")
