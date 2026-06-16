#!/usr/bin/env python3
"""Fix: manually attach angeautoecole to julesdekaya commercial."""
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
    for row in rows[:10]:
        print(json.dumps(row, ensure_ascii=False, default=str)[:500])
    if ok and not rows: print("(0 rows)")
    return rows

STUDENT_ID = "165056f6-2472-487b-92db-8234741af8c7"  # angeautoecole@gmail.com
COMMERCIAL_ID = "0e196e57-e982-4bdf-8529-a33f23724d7c"  # kayadejule@gmail.com (julesdekaya)
REF_CODE = "COMM-44abfda3"

# Step 1: Create student profile if missing
q("1. Create student profile", f"""
INSERT INTO app.students (id, full_name)
VALUES ('{STUDENT_ID}', 'auto ange')
ON CONFLICT (id) DO NOTHING
""")

# Step 2: Create referral
q("2. Create user_referral", f"""
INSERT INTO app.user_referrals (student_id, commercial_user_id, ref_code, source, attributed_at, expires_at, metadata)
VALUES ('{STUDENT_ID}', '{COMMERCIAL_ID}', '{REF_CODE}', 'manual_fix', NOW(), NOW() + INTERVAL '1 year', '{{}}'::jsonb)
ON CONFLICT (student_id) DO NOTHING
""")

# Step 3: Verify
q("3. Verify referral created", f"""
SELECT ur.id::text, ur.student_id::text, ur.commercial_user_id::text, ur.ref_code, ur.source, ur.attributed_at,
       u_s.email AS student_email, u_c.email AS commercial_email
FROM app.user_referrals ur
LEFT JOIN auth.users u_s ON u_s.id = ur.student_id
LEFT JOIN auth.users u_c ON u_c.id = ur.commercial_user_id
WHERE ur.student_id = '{STUDENT_ID}'
""")

# Step 4: Verify commercial dashboard would now show this prospect
q("4. Verify prospect count for julesdekaya", f"""
SELECT COUNT(*) AS prospects_count FROM app.user_referrals WHERE commercial_user_id = '{COMMERCIAL_ID}'
""")

print("\nDONE")
