#!/usr/bin/env python3
"""Vérifier la structure des tables de paiement et les triggers de commission"""
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
print("AUDIT TABLES DE PAIEMENT ET TRIGGERS")
print("=" * 70)

# 1. Trouver la table de paiement correcte
q(m, "Tables contenant 'payment' dans le nom", """
SELECT table_name, table_schema
FROM information_schema.tables
WHERE table_schema = 'app'
AND (table_name LIKE '%payment%' OR table_name LIKE '%paiement%' OR table_name LIKE '%transaction%')
ORDER BY table_name
""")

# 2. Vérifier student_applications (pour les frais de dossier)
q(m, "student_applications - colonnes", """
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema='app' AND table_name='student_applications'
ORDER BY ordinal_position
""")

# 3. Vérifier s'il y a des paiements/enregistrements
q(m, "student_applications - sample data", """
SELECT * FROM app.student_applications ORDER BY created_at DESC LIMIT 3
""")

# 4. Vérifier les triggers sur student_applications
q(m, "Triggers sur student_applications", """
SELECT tg.tgname, tg.tgrelid::regclass as table_name, 
       tg.tgfoid::regproc as function_name,
       pg_get_triggerdef(tg.oid) as trigger_def
FROM pg_trigger tg
WHERE tg.tgrelid = 'app.student_applications'::regclass
AND NOT tg.tgisinternal
ORDER BY tg.tgname
""")

# 5. Vérifier les fonctions de commission
q(m, "Fonctions de commission", """
SELECT p.proname, n.nspname, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname LIKE '%commission%' OR p.proname LIKE '%referral%'
AND n.nspname IN ('public', 'app')
ORDER BY p.proname
""")

# 6. Vérifier les tables liées aux commissions
q(m, "Tables de commission existantes", """
SELECT table_name, table_schema
FROM information_schema.tables
WHERE table_schema = 'app'
AND (table_name LIKE '%commission%' OR table_name LIKE '%referral%')
ORDER BY table_name
""")

print(f"\n{'='*70}")
print("ANALYSE")
print("=" * 70)

print("""
HYPOTHÈSE: Les paiements sont dans student_applications (frais de dossier) et non dans une table payments séparée.
Il faut vérifier si les triggers de commission sont sur student_applications.
""")

print(f"\n{'='*70}")
print("AUDIT TERMINÉ")
print(f"{'='*70}")
