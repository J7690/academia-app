#!/usr/bin/env python3
"""Part 2: Get existing delete_user_account RPC source + storage buckets + direct_conversations."""

import requests
import json

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
    "1_delete_user_account_rpc_source": """
        SELECT prosrc as source_code
        FROM pg_proc
        WHERE proname = 'app_admin_delete_user_account'
        LIMIT 1
    """,
    "2_delete_data_safe_rpc_source": """
        SELECT prosrc as source_code
        FROM pg_proc
        WHERE proname = 'delete_data_safe'
        LIMIT 1
    """,
    "3_storage_buckets": """
        SELECT id, name, public, file_size_limit
        FROM storage.buckets
        ORDER BY name
    """,
    "4_application_files_columns": """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'application_files'
        ORDER BY ordinal_position
    """,
    "5_student_dossier_documents_columns": """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'student_dossier_documents'
        ORDER BY ordinal_position
    """,
    "6_direct_conversations_columns": """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'direct_conversations'
        ORDER BY ordinal_position
    """,
    "7_support_conversations_columns": """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'support_conversations'
        ORDER BY ordinal_position
    """,
    "8_auth_users_deleted_at_check": """
        SELECT column_name, data_type, column_default
        FROM information_schema.columns
        WHERE table_schema = 'auth' AND table_name = 'users'
        AND column_name IN ('deleted_at', 'banned_until', 'is_anonymous')
    """,
    "9_existing_account_related_rpcs": """
        SELECT routine_name
        FROM information_schema.routines
        WHERE routine_schema IN ('app', 'public')
        AND (routine_name ILIKE '%account%' OR routine_name ILIKE '%user%profile%' OR routine_name ILIKE '%student%profile%')
        ORDER BY routine_name
    """,
    "10_tables_with_on_delete_cascade": """
        SELECT
            tc.table_name AS child_table,
            kcu.column_name AS fk_column,
            ccu.table_name AS parent_table,
            rc.delete_rule
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        JOIN information_schema.referential_constraints rc ON tc.constraint_name = rc.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'app'
        AND (ccu.table_name = 'students' OR ccu.column_name = 'id')
        AND ccu.table_schema = 'app'
        LIMIT 50
    """,
}

results = {}
for label, sql in queries.items():
    print(f"Running: {label}...")
    res = run_sql(sql.strip())
    results[label] = res
    if res:
        if label.endswith("_source"):
            print(f"  -> found ({len(str(res))} chars)")
        else:
            print(f"  -> {len(res)} rows")
    else:
        print(f"  -> FAILED or empty")

out_path = "logs/audit_store_compliance_part2.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)

print(f"\nResults written to {out_path}")

# Print the RPC source directly
for key in ["1_delete_user_account_rpc_source", "2_delete_data_safe_rpc_source"]:
    data = results.get(key)
    if data and isinstance(data, list) and len(data) > 0:
        print(f"\n{'='*60}")
        print(f"=== {key} ===")
        print(f"{'='*60}")
        print(data[0].get("source_code", "N/A"))
