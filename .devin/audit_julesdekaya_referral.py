#!/usr/bin/env python3
"""Audit julesdekaya commercial + angeautoecole referral flow."""
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
    print(f"\n{'='*60}\n{label}\n{'='*60}")
    if not ok:
        print(f"ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:600]}")
    for row in rows[:20]:
        print(json.dumps(row, ensure_ascii=False, default=str)[:600])
    if ok and not rows: print("(0 rows)")
    return rows

# 1. Find julesdekaya
q("1. julesdekaya in auth.users", """
SELECT id::text, email, raw_user_meta_data->>'role' AS role,
       raw_user_meta_data->>'full_name' AS full_name, created_at
FROM auth.users WHERE email LIKE '%julesdekaya%'
""")

# 2. Find ALL commercials and their profiles
q("2. ALL commercial_profiles with emails", """
SELECT cp.user_id::text, u.email, cp.ref_code, cp.ref_link, cp.is_active, cp.tier,
       cp.total_confirmed_payments, cp.commission_rate, cp.created_at
FROM app.commercial_profiles cp
JOIN auth.users u ON u.id = cp.user_id
ORDER BY cp.created_at DESC
""")

# 3. Find angeautoecole or similar
q("3. angeautoecole in auth.users", """
SELECT id::text, email, raw_user_meta_data->>'role' AS role,
       raw_user_meta_data->>'full_name' AS full_name, created_at
FROM auth.users WHERE email LIKE '%ange%'
""")

# 4. ALL user_referrals
q("4. ALL user_referrals (complete dump)", """
SELECT ur.id::text, ur.student_id::text, ur.commercial_user_id::text,
       ur.ref_code, ur.source, ur.attributed_at,
       s.full_name AS student_name,
       u_student.email AS student_email,
       u_comm.email AS commercial_email
FROM app.user_referrals ur
LEFT JOIN app.students s ON s.id = ur.student_id
LEFT JOIN auth.users u_student ON u_student.id = ur.student_id
LEFT JOIN auth.users u_comm ON u_comm.id = ur.commercial_user_id
ORDER BY ur.attributed_at DESC
""")

# 5. Recent users (last 7 days)
q("5. Users created last 7 days", """
SELECT id::text, email, raw_user_meta_data->>'role' AS role,
       raw_user_meta_data->>'full_name' AS full_name, created_at
FROM auth.users WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY created_at DESC
""")

# 6. Recent users (last 30 days)
q("6. Users created last 30 days", """
SELECT id::text, email, raw_user_meta_data->>'role' AS role,
       raw_user_meta_data->>'full_name' AS full_name, created_at
FROM auth.users WHERE created_at >= NOW() - INTERVAL '30 days'
ORDER BY created_at DESC
""")

# 7. Check app.students for angeautoecole
q("7. Students with ange in name/email", """
SELECT s.id::text, s.full_name, u.email, u.created_at
FROM app.students s
JOIN auth.users u ON u.id = s.id
WHERE u.email LIKE '%ange%' OR s.full_name ILIKE '%ange%'
""")

# 8. Check SharedPreferences equivalent — is there a pending referral somewhere?
# Check if the student was created but referral not attached
q("8. All students NOT in user_referrals (no referral)", """
SELECT COUNT(*) AS students_without_referral
FROM app.students s
WHERE NOT EXISTS (SELECT 1 FROM app.user_referrals ur WHERE ur.student_id = s.id)
""")

# 9. Check the commercial dashboard RPC output for julesdekaya's commercial
q("9. All commercial ref_codes and links", """
SELECT ref_code, ref_link, user_id::text FROM app.commercial_profiles ORDER BY created_at
""")

print("\n" + "="*60)
print("AUDIT COMPLETE")
print("="*60)
