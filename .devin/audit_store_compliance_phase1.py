#!/usr/bin/env python3
"""Phase 1 deep audit for account deletion backend."""

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

queries = {}

queries["1_user_admin_status_columns"] = (
    "SELECT column_name, data_type, column_default, is_nullable "
    "FROM information_schema.columns "
    "WHERE table_schema = 'app' AND table_name = 'user_admin_status' "
    "ORDER BY ordinal_position"
)

queries["2_user_admin_status_constraints"] = (
    "SELECT tc.constraint_name, tc.constraint_type, kcu.column_name "
    "FROM information_schema.table_constraints tc "
    "JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name "
    "WHERE tc.table_schema = 'app' AND tc.table_name = 'user_admin_status'"
)

queries["3_tables_user_fk_no_cascade"] = (
    "SELECT tc.table_name AS child_table, kcu.column_name AS fk_column, "
    "ccu.table_name AS parent_table, rc.delete_rule "
    "FROM information_schema.table_constraints tc "
    "JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name "
    "JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name "
    "JOIN information_schema.referential_constraints rc ON tc.constraint_name = rc.constraint_name "
    "WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'app' "
    "AND rc.delete_rule <> 'CASCADE' "
    "AND (kcu.column_name LIKE '%user_id%' OR kcu.column_name LIKE '%student_id%' "
    "OR kcu.column_name LIKE '%author_id%' OR kku.column_name LIKE '%sender_id%') "
    "ORDER BY tc.table_name"
)

queries["4_pg_cron_exists"] = (
    "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') AS has_pg_cron"
)

queries["5_auth_sessions_columns"] = (
    "SELECT column_name, data_type "
    "FROM information_schema.columns "
    "WHERE table_schema = 'auth' AND table_name = 'sessions' "
    "ORDER BY ordinal_position"
)

queries["6_admin_user_action_logs_columns"] = (
    "SELECT column_name, data_type "
    "FROM information_schema.columns "
    "WHERE table_schema = 'app' AND table_name = 'admin_user_action_logs' "
    "ORDER BY ordinal_position"
)

queries["7_all_user_fk_with_delete_rule"] = (
    "SELECT tc.table_name, kcu.column_name, rc.delete_rule "
    "FROM information_schema.table_constraints tc "
    "JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name "
    "JOIN information_schema.referential_constraints rc ON tc.constraint_name = rc.constraint_name "
    "WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'app' "
    "AND kcu.column_name IN ('user_id','student_id','author_id','sender_id','commercial_user_id','owner_user_id','created_by_user_id','requester_user_id') "
    "ORDER BY tc.table_name"
)

queries["8_existing_cron_jobs"] = (
    "SELECT jobid, schedule, command FROM cron.job ORDER BY jobid"
)

queries["9_rpc_app_admin_delete_user_params"] = (
    "SELECT proargnames, proargtypes::text "
    "FROM pg_proc WHERE proname = 'app_admin_delete_user_account' LIMIT 1"
)

queries["10_direct_conv_user_columns"] = (
    "SELECT tc.table_name, kcu.column_name, rc.delete_rule "
    "FROM information_schema.table_constraints tc "
    "JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name "
    "JOIN information_schema.referential_constraints rc ON tc.constraint_name = rc.constraint_name "
    "WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'app' "
    "AND tc.table_name IN ('direct_conversations','direct_messages','direct_message_read_states') "
    "ORDER BY tc.table_name, kcu.column_name"
)

results = {}
for label, sql in queries.items():
    print(f"Running: {label}...")
    res = run_sql(sql.strip())
    results[label] = res
    if res is not None:
        print(f"  -> {len(res)} rows")
    else:
        print(f"  -> FAILED")

out_path = "logs/audit_store_compliance_phase1.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)

print(f"\nResults written to {out_path}")
