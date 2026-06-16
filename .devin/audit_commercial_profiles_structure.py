#!/usr/bin/env python3
"""Vérifier la structure exacte de commercial_profiles et trouver les referral_codes"""
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
print("AUDIT COMMERCIAL_PROFILES - REFERRAL_CODE")
print("=" * 70)

# 1. Structure complète de commercial_profiles
q(m, "commercial_profiles - ALL columns", """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='app' AND table_name='commercial_profiles'
ORDER BY ordinal_position
""")

# 2. Vérifier s'il y a une colonne referral_link ou similaire
q(m, "commercial_profiles - search for referral/link columns", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' 
AND table_name='commercial_profiles'
AND (column_name LIKE '%referral%' OR column_name LIKE '%link%' OR column_name LIKE '%code%')
""")

# 3. Comment les commerciaux obtiennent leur lien de referral
q(m, "commercial_profiles - sample data with all columns", """
SELECT * FROM app.commercial_profiles LIMIT 3
""")

# 4. Vérifier les utilisateurs commerciaux
q(m, "auth.users with role=commercial", """
SELECT id, email, raw_user_meta_data, created_at
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'commercial'
ORDER BY created_at DESC LIMIT 3
""")

# 5. Comment le referral_code est généré (dashboard commercial)
q(m, "app_commercial_get_dashboard - source (first 2000 chars)", """
SELECT LEFT(pg_get_functiondef(p.oid), 2000) AS src
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_commercial_get_dashboard' AND n.nspname IN ('public', 'app')
""")

print(f"\n{'='*70}")
print("AUDIT TERMINÉ")
print(f"{'='*70}")
