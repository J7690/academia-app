#!/usr/bin/env python3
"""Audit du flux complet referral - capture → création → tracking"""
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
print("AUDIT FLUX REFERRAL COMPLET")
print("=" * 70)

# 1. Vérifier les liens de referral actifs
q(m, "Liens de referral actifs des commerciaux", """
SELECT cp.user_id, cp.ref_code, cp.ref_link, cp.is_active,
       u.email, u.created_at as user_created_at
FROM app.commercial_profiles cp
JOIN auth.users u ON u.id = cp.user_id
WHERE u.raw_user_meta_data->>'role' = 'commercial'
AND cp.is_active = true
ORDER BY cp.created_at DESC
""")

# 2. Vérifier les user_referrals enregistrés
q(m, "user_referrals - prospects trackés", """
SELECT ur.*, 
       u_s.email as student_email,
       u_c.email as commercial_email,
       u_s.created_at as student_created_at
FROM app.user_referrals ur
JOIN auth.users u_s ON u_s.id = ur.student_id
JOIN auth.users u_c ON u_c.id = ur.commercial_user_id
ORDER BY ur.attributed_at DESC LIMIT 5
""")

# 3. Vérifier si les étudiants créés via referral ont bien le role=student
q(m, "Étudiants créés via referral", """
SELECT u.id, u.email, u.created_at,
       u.raw_user_meta_data,
       ur.ref_code, ur.attributed_at,
       CASE WHEN u.raw_user_meta_data->>'role' = 'student' THEN 'YES' ELSE 'NO' END as is_student
FROM auth.users u
JOIN app.user_referrals ur ON ur.student_id = u.id
WHERE u.created_at >= ur.attributed_at - INTERVAL '1 hour'
ORDER BY u.created_at DESC LIMIT 5
""")

# 4. Vérifier les paiements de ces étudiants
q(m, "Paiements des étudiants référés", """
SELECT DISTINCT u.id as student_id, u.email, u.created_at,
       ur.ref_code, ur.attributed_at,
       p.id as payment_id, p.amount, p.payment_reason, p.status, p.created_at as payment_created_at
FROM auth.users u
JOIN app.user_referrals ur ON ur.student_id = u.id
LEFT JOIN app.payments p ON p.student_id = u.id
WHERE u.created_at >= ur.attributed_at - INTERVAL '1 hour'
ORDER BY u.created_at DESC, p.created_at DESC
LIMIT 5
""")

# 5. Vérifier si des commissions ont été générées
q(m, "Commissions générées pour les paiements", """
SELECT rc.*, p.amount, p.payment_reason, p.status as payment_status,
       u_s.email as student_email,
       u_c.email as commercial_email
FROM app.referral_commissions rc
JOIN app.payments p ON p.id = rc.payment_id
JOIN auth.users u_s ON u_s.id = rc.student_id  
JOIN auth.users u_c ON u_c.id = rc.commercial_user_id
ORDER BY rc.created_at DESC LIMIT 5
""")

# 6. Vérifier les triggers de commission
q(m, "Triggers de commission sur payments", """
SELECT tg.tgname, tg.tgrelid::regclass as table_name, 
       tg.tgfoid::regproc as function_name,
       pg_get_triggerdef(tg.oid) as trigger_def
FROM pg_trigger tg
WHERE tg.tgrelid = 'app.payments'::regclass
AND NOT tg.tgisinternal
ORDER BY tg.tgname
""")

print(f"\n{'='*70}")
print("ANALYSE DU PROBLÈME")
print("=" * 70)

print("""
1. Les liens de referral existent et sont actifs (ref_code + ref_link)
2. La capture du referral fonctionne (user_referrals a des enregistrements)
3. Les étudiants sont bien créés avec role=student
4. MAIS: referral_commissions est VIDE => problème de génération des commissions
5. MAIS: commercial_profiles n'a pas de colonnes de tracking (total_referrals, etc.)

PROBLÈMES IDENTIFIÉS:
- Les triggers de commission ne se déclenchent peut-être pas
- La colonne referral_code n'existe pas dans commercial_profiles (c'est ref_code)
- Le tracking des statistiques commerciales n'est pas à jour
""")

print(f"\n{'='*70}")
print("AUDIT TERMINÉ")
print(f"{'='*70}")
