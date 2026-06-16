#!/usr/bin/env python3
"""Audit v2 - find julesdekaya, check why referral not attached."""
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

# 1. Find ALL commercial users (role=commercial) with their emails
q("1. ALL commercial users", """
SELECT u.id::text, u.email, u.raw_user_meta_data->>'full_name' AS full_name,
       u.raw_user_meta_data->>'role' AS role, u.created_at
FROM auth.users u
WHERE u.raw_user_meta_data->>'role' = 'commercial'
ORDER BY u.created_at
""")

# 2. Match commercials with their profiles
q("2. Commercial profiles + emails", """
SELECT cp.user_id::text, u.email, cp.ref_code, cp.ref_link, cp.is_active
FROM app.commercial_profiles cp
JOIN auth.users u ON u.id = cp.user_id
ORDER BY cp.created_at
""")

# 3. The student angeautoecole — full details
q("3. angeautoecole full details", """
SELECT u.id::text, u.email, u.raw_user_meta_data->>'role' AS role,
       u.raw_user_meta_data->>'full_name' AS full_name, u.created_at,
       EXISTS(SELECT 1 FROM app.students s WHERE s.id = u.id) AS has_student_profile,
       EXISTS(SELECT 1 FROM app.user_referrals ur WHERE ur.student_id = u.id) AS has_referral
FROM auth.users u
WHERE u.email = 'angeautoecole@gmail.com'
""")

# 4. Check if angeautoecole has an entry in app.students
q("4. angeautoecole in app.students", """
SELECT s.id::text, s.full_name
FROM app.students s
WHERE s.id = '165056f6-2472-487b-92db-8234741af8c7'
""")

# 5. Verify: was angeautoecole created via the landing page or mobile app?
# Check if the account was created today
q("5. angeautoecole creation context", """
SELECT u.id::text, u.email, u.created_at,
       u.raw_user_meta_data->>'role' AS role,
       u.raw_user_meta_data->>'full_name' AS full_name,
       u.raw_app_meta_data AS app_metadata,
       u.confirmed_at, u.email_confirmed_at
FROM auth.users u
WHERE u.id = '165056f6-2472-487b-92db-8234741af8c7'
""")
