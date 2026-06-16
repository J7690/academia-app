#!/usr/bin/env python3
"""Audit Supabase for Play Store / App Store compliance requirements.
Inventories: PII tables, auth schema, existing delete/account RPCs, user data footprint.
"""

import requests
import json
import sys

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
}

def run_sql(sql):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": sql}, timeout=30)
    if r.status_code == 200:
        return r.json()
    else:
        print(f"ERROR {r.status_code}: {r.text[:500]}")
        return None

queries = {
    "1_all_app_tables": """
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'app' 
        ORDER BY table_name
    """,
    "2_students_columns": """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'students'
        ORDER BY ordinal_position
    """,
    "3_auth_users_columns": """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'auth' AND table_name = 'users'
        ORDER BY ordinal_position
    """,
    "4_delete_related_rpcs": """
        SELECT routine_name
        FROM information_schema.routines
        WHERE routine_schema IN ('app', 'public')
        AND (routine_name ILIKE '%delete%' OR routine_name ILIKE '%suppress%' OR routine_name ILIKE '%purge%' OR routine_name ILIKE '%anonymi%')
        ORDER BY routine_name
    """,
    "5_pii_tables_with_user_id": """
        SELECT DISTINCT c.table_name, c.column_name
        FROM information_schema.columns c
        JOIN information_schema.tables t ON t.table_name = c.table_name AND t.table_schema = c.table_schema
        WHERE c.table_schema = 'app'
        AND (c.column_name IN ('user_id', 'author_id', 'sender_id', 'student_id', 'commercial_user_id', 'created_by_user_id', 'owner_user_id'))
        ORDER BY c.table_name, c.column_name
    """,
    "6_pii_columns": """
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = 'app'
        AND (column_name ILIKE '%name%' OR column_name ILIKE '%email%' OR column_name ILIKE '%phone%' 
             OR column_name ILIKE '%address%' OR column_name ILIKE '%avatar%' OR column_name ILIKE '%bio%'
             OR column_name ILIKE '%birth%' OR column_name ILIKE '%cv%' OR column_name ILIKE '%document%')
        ORDER BY table_name, column_name
    """,
    "7_storage_buckets": """
        SELECT id, name, public, file_size_limit, allowed_mime_types
        FROM storage.buckets
        ORDER BY name
    """,
    "8_device_tokens_table": """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'user_device_tokens'
        ORDER BY ordinal_position
    """,
    "9_notification_state_table": """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'user_notification_state'
        ORDER BY ordinal_position
    """,
    "10_account_status_columns": """
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = 'app'
        AND (column_name ILIKE '%status%' OR column_name ILIKE '%is_active%' OR column_name ILIKE '%deleted%' OR column_name ILIKE '%banned%')
        ORDER BY table_name, column_name
    """,
}

results = {}
for label, sql in queries.items():
    print(f"Running: {label}...")
    res = run_sql(sql.strip())
    results[label] = res
    if res:
        print(f"  -> {len(res)} rows")
    else:
        print(f"  -> FAILED")

# Write results
out_path = "logs/audit_store_compliance.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)

print(f"\nResults written to {out_path}")
