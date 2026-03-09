#!/usr/bin/env python3
"""Get REAL columns of commercial_profiles + user_invitations + user_referrals."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    rows = d.get('rows', []) if isinstance(d, dict) else []
    print(f"\n{'✅' if ok else '❌'} {label}")
    if not ok: print(f"  ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:400]}")
    for row in (rows or [])[:20]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:400]}")
    if ok and not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()

q(m, "commercial_profiles REAL columns", """
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns WHERE table_schema='app' AND table_name='commercial_profiles'
ORDER BY ordinal_position
""")

q(m, "commercial_profiles sample (ALL columns)", """
SELECT * FROM app.commercial_profiles LIMIT 3
""")

q(m, "user_invitations REAL columns", """
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns WHERE table_schema='app' AND table_name='user_invitations'
ORDER BY ordinal_position
""")

q(m, "user_referrals REAL columns", """
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns WHERE table_schema='app' AND table_name='user_referrals'
ORDER BY ordinal_position
""")

q(m, "user_referrals sample (ALL columns)", """
SELECT * FROM app.user_referrals LIMIT 5
""")
