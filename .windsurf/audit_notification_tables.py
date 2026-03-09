#!/usr/bin/env python3
"""Audit notification_events and user_device_tokens tables + related RPCs"""
import requests, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

def sql(label, q):
    print(f"\n--- {label} ---")
    r = requests.post(url, headers=m.headers, json={"p_sql": q.strip()}, timeout=30)
    data = r.json() if r.status_code == 200 else {"error": r.status_code}
    if isinstance(data, dict) and "rows" in data:
        for row in data["rows"]:
            print(f"  {json.dumps(row, default=str)}")
    else:
        print(f"  {json.dumps(data, default=str)[:500]}")

sql("notification_events columns", """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='app' AND table_name='notification_events'
ORDER BY ordinal_position
""")

sql("user_device_tokens columns", """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='app' AND table_name='user_device_tokens'
ORDER BY ordinal_position
""")

sql("notification RPCs", """
SELECT routine_name FROM information_schema.routines
WHERE routine_schema='public' AND (routine_name LIKE '%notif%' OR routine_name LIKE '%push%' OR routine_name LIKE '%device_token%')
ORDER BY routine_name
""")

sql("sample notification_events", """
SELECT * FROM app.notification_events LIMIT 3
""")

sql("count device_tokens", """
SELECT COUNT(*) as cnt FROM app.user_device_tokens
""")

sql("Edge Functions list", """
SELECT routine_name FROM information_schema.routines
WHERE routine_schema='public' AND routine_name LIKE '%send%push%'
ORDER BY routine_name
""")

print("\nDone.")
