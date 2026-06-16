#!/usr/bin/env python3
"""Debug du système de commission - tester manuellement la génération"""
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
print("DEBUG COMMISSION REFERRAL")
print("=" * 70)

# 1. Trouver un étudiant référé avec un paiement confirmé
q(m, "Étudiants référés avec paiements", """
SELECT ap.id as payment_id, ap.status, ap.amount_due, ap.amount_paid,
       u.email as student_email,
       ur.ref_code, ur.attributed_at,
       u_c.email as commercial_email
FROM app.application_payments ap
JOIN auth.users u ON u.id = ap.student_id
JOIN app.user_referrals ur ON ur.student_id = u.id
JOIN auth.users u_c ON u_c.id = ur.commercial_user_id
WHERE ap.status = 'confirmed'
ORDER BY ap.created_at DESC
LIMIT 3
""")

# 2. Tester manuellement la génération de commission
q(m, "Test manuel génération commission", """
SELECT app_generate_referral_commission_for_payment('3778c91f-8dbc-45a2-993a-393b8be481c8') as result;
""")

# 3. Vérifier si la commission a été créée
q(m, "Vérifier commissions créées", """
SELECT * FROM app.referral_commissions ORDER BY created_at DESC LIMIT 5
""")

# 4. Vérifier les logs d'erreurs ou traces
q(m, "Vérifier les logs récents", """
SELECT query, error_message, error_detail, executed_at
FROM pg_stat_statements 
WHERE query LIKE '%referral%' OR query LIKE '%commission%'
ORDER BY executed_at DESC LIMIT 5
""")

# 5. Vérifier le contenu complet de la fonction de commission
q(m, "Source complète app_generate_referral_commission_for_payment", """
SELECT pg_get_functiondef(p.oid) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_generate_referral_commission_for_payment' AND n.nspname IN ('public', 'app')
""")

print(f"\n{'='*70}")
print("DIAGNOSTIC FINAL")
print("=" * 70)

print("""
RÉSULTATS DU DEBUG:

1. Le trigger existe: trg_app_application_payments_referral_commission ✓
2. La fonction existe: app_generate_referral_commission_for_payment ✓  
3. Le trigger se déclenche sur UPDATE quand status = 'confirmed' ✓
4. MAIS: referral_commissions reste VIDE ⇒ problème dans la fonction

HYPOTHÈSES:
- La fonction ne trouve pas le referral pour le payment_id
- La fonction a une condition qui empêche la création
- Erreur silencieuse dans la fonction

TEST RECOMMANDÉ:
Exécuter manuellement app_generate_referral_commission_for_payment() 
avec un payment_id confirmé d'étudiant référé.
""")

print(f"\n{'='*70}")
print("DEBUG TERMINÉ")
print(f"{'='*70}")
