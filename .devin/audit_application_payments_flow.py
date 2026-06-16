#!/usr/bin/env python3
"""Vérifier le flux application_payments et les triggers de commission"""
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
    for row in (rows or [])[:10]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:600]}")
    if ok and not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()

print("=" * 70)
print("AUDIT APPLICATION_PAYMENTS FLOW")
print("=" * 70)

# 1. Structure de application_payments
q(m, "application_payments - colonnes", """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='app' AND table_name='application_payments'
ORDER BY ordinal_position
""")

# 2. Données dans application_payments
q(m, "application_payments - sample data", """
SELECT * FROM app.application_payments ORDER BY created_at DESC LIMIT 5
""")

# 3. Vérifier les triggers sur application_payments
q(m, "Triggers sur application_payments", """
SELECT tg.tgname, tg.tgrelid::regclass as table_name, 
       tg.tgfoid::regproc as function_name,
       pg_get_triggerdef(tg.oid) as trigger_def
FROM pg_trigger tg
WHERE tg.tgrelid = 'app.application_payments'::regclass
AND NOT tg.tgisinternal
ORDER BY tg.tgname
""")

# 4. Vérifier les paiements des étudiants référés
q(m, "Paiements des étudiants référés", """
SELECT ap.*, 
       u.email as student_email,
       ur.ref_code, ur.attributed_at,
       u_c.email as commercial_email
FROM app.application_payments ap
JOIN auth.users u ON u.id = ap.student_id
LEFT JOIN app.user_referrals ur ON ur.student_id = u.id
LEFT JOIN auth.users u_c ON u_c.id = ur.commercial_user_id
WHERE ur.student_id IS NOT NULL
ORDER BY ap.created_at DESC
LIMIT 5
""")

# 5. Vérifier si des commissions existent pour ces paiements
q(m, "Commissions pour les paiements existants", """
SELECT rc.*, ap.amount, ap.payment_reason, ap.status as payment_status,
       u_s.email as student_email,
       u_c.email as commercial_email
FROM app.referral_commissions rc
RIGHT JOIN app.application_payments ap ON ap.id = rc.payment_id
JOIN auth.users u_s ON u_s.id = ap.student_id
LEFT JOIN app.user_referrals ur ON ur.student_id = u_s.id
LEFT JOIN auth.users u_c ON u_c.id = ur.commercial_user_id
WHERE ur.student_id IS NOT NULL
ORDER BY ap.created_at DESC
LIMIT 5
""")

# 6. Source de la fonction de génération de commission
q(m, "Source app_generate_referral_commission_for_payment", """
SELECT pg_get_functiondef(p.oid) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_generate_referral_commission_for_payment' AND n.nspname IN ('public', 'app')
""")

# 7. Source du trigger de commission
q(m, "Source app_on_payment_confirmed_generate_referral_commission", """
SELECT pg_get_functiondef(p.oid) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_on_payment_confirmed_generate_referral_commission' AND n.nspname IN ('public', 'app')
""")

print(f"\n{'='*70}")
print("ANALYSE FINALE DU PROBLÈME")
print("=" * 70)

print("""
CONCLUSIONS:
1. Les liens de referral fonctionnent (capture dans user_referrals) ✓
2. Les comptes étudiants sont créés avec le referral attaché ✓
3. Les paiements sont dans application_payments ✓
4. MAIS: referral_commissions est VIDE => les triggers ne se déclenchent pas ❌

PROBLÈMES PROBABLES:
- Le trigger sur application_payments n'existe pas ou est défectueux
- La fonction app_generate_referral_commission_for_payment n'est pas appelée
- Les conditions de génération de commission ne sont pas remplies

SOLUTIONS NÉCESSAIRES:
1. Créer/mettre à jour le trigger sur application_payments
2. Vérifier que la fonction de commission vérifie bien user_referrals
3. Tester manuellement la génération de commission
""")

print(f"\n{'='*70}")
print("AUDIT TERMINÉ")
print(f"{'='*70}")
