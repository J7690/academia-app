#!/usr/bin/env python3
"""Audit final et synthèse du problème referral/commercial"""
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
print("AUDIT FINAL - SYSTÈME REFERRAL/COMMERCIAL")
print("=" * 70)

print("\n🔍 ÉTAT ACTUEL DU SYSTÈME:")
print("-" * 50)

# 1. Vérifier s'il y a des étudiants référés avec des paiements
q(m, "Cross-check étudiants référés vs paiements", """
SELECT u.id, u.email, u.created_at,
       ur.ref_code, ur.attributed_at,
       COUNT(ap.id) as payment_count,
       MAX(CASE WHEN ap.status = 'confirmed' THEN 1 ELSE 0 END) as has_confirmed_payment
FROM auth.users u
JOIN app.user_referrals ur ON ur.student_id = u.id
LEFT JOIN app.application_payments ap ON ap.student_id = u.id
WHERE u.raw_user_meta_data->>'role' = 'student'
GROUP BY u.id, u.email, u.created_at, ur.ref_code, ur.attributed_at
ORDER BY u.created_at DESC
LIMIT 5
""")

# 2. Vérifier les paiements confirmés récents
q(m, "Paiements confirmés récents (tous étudiants)", """
SELECT ap.id, ap.status, ap.amount_due, ap.amount_paid, ap.created_at,
       u.email as student_email,
       EXISTS(SELECT 1 FROM app.user_referrals ur WHERE ur.student_id = u.id) as has_referral
FROM app.application_payments ap
JOIN auth.users u ON u.id = ap.student_id
WHERE ap.status = 'confirmed'
ORDER BY ap.created_at DESC
LIMIT 5
""")

# 3. Vérifier s'il y a eu des tentatives de commission
q(m, "Toutes les commissions (même échouées)", """
SELECT * FROM app.referral_commissions ORDER BY created_at DESC LIMIT 5
""")

# 4. Statistiques globales
q(m, "Statistiques globales du système", """
SELECT 
    (SELECT COUNT(*) FROM app.commercial_profiles WHERE is_active = true) as active_commercials,
    (SELECT COUNT(*) FROM app.user_referrals) as total_referrals,
    (SELECT COUNT(*) FROM app.application_payments WHERE status = 'confirmed') as confirmed_payments,
    (SELECT COUNT(*) FROM app.referral_commissions) as total_commissions
""")

print(f"\n{'='*70}")
print("SYNTHÈSE DU PROBLÈME")
print("=" * 70)

print("""
🎯 RAPPEL DE L'OBJECTIF:
Le flux commercial-admin-étudiant doit permettre:
1. Commercial génère lien unique ✅
2. Étudiant clique → redirection vers app ✅  
3. Création compte avec tracking referral ✅
4. Paiement étudiant → commission automatique ❌
5. Dashboard commercial + admin voit les stats ❌

📊 ÉTAT DES LIEUX:
✅ Liens referral: commercial_profiles.ref_link (actifs)
✅ Capture referral: user_referrals (fonctionne)
✅ Création comptes: étudiants avec role=student (OK)
✅ Paiements: application_payments.status='confirmed' (existants)
❌ Commissions: referral_commissions (VIDE)
❌ Stats commercial: dashboard commercial (incomplet)

🔍 DIAGNOSTIC PRÉCIS:
- Le trigger trg_app_application_payments_referral_commission existe ✅
- La fonction app_generate_referral_commission_for_payment existe ✅
- MAIS aucunes commissions ne sont générées ❌

🚨 PROBLÈMES IDENTIFIÉS:
1. Les étudiants référés n'ont pas de paiements confirmés
2. OU la fonction de commission a un bug silencieux
3. OU les conditions de commission ne sont pas remplies

📋 PLAN D'ACTION RECOMMANDÉ:
1. Vérifier si les étudiants référés ont des paiements confirmés
2. Si oui: debugger la fonction app_generate_referral_commission_for_payment
3. Si non: le problème est en amont (pas de paiements = pas de commissions)
4. Mettre à jour les statistiques commerciales (dashboard)
""")

print(f"\n{'='*70}")
print("AUDIT TERMINÉ")
print(f"{'='*70}")
