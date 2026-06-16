#!/usr/bin/env python3
"""Deploy account deletion compliance SQL migration."""

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

def run_sql(sql, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": sql}, timeout=60)
    if r.status_code == 200:
        print(f"  OK: {label}")
        return True
    else:
        print(f"  FAIL [{r.status_code}]: {label}")
        print(f"  {r.text[:500]}")
        return False

# Read the SQL file
sql_path = "sql_changes/change_20260316_account_deletion_compliance.sql"
with open(sql_path, "r", encoding="utf-8") as f:
    full_sql = f.read()

# Split into individual statements (by semicolon at end of line, excluding comments)
# We'll deploy in logical blocks instead
blocks = [
    (
        "1. ALTER user_admin_status",
        """ALTER TABLE app.user_admin_status
           ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ,
           ADD COLUMN IF NOT EXISTS purge_due_at TIMESTAMPTZ,
           ADD COLUMN IF NOT EXISTS deletion_method TEXT DEFAULT 'self_service'"""
    ),
    (
        "2. CREATE RPC app_student_request_account_deletion",
        # Read from the file between the markers
        None  # will be filled below
    ),
    (
        "3. GRANT on app_student_request_account_deletion",
        "GRANT EXECUTE ON FUNCTION app.app_student_request_account_deletion() TO authenticated"
    ),
    (
        "4. CREATE RPC app_admin_purge_deleted_accounts",
        None  # will be filled below
    ),
    (
        "5. Schedule cron job",
        "SELECT cron.schedule('purge_deleted_accounts', '0 3 * * *', $$SELECT app.app_admin_purge_deleted_accounts()$$)"
    ),
    (
        "6. CREATE RPC app_check_account_status",
        None  # will be filled below
    ),
    (
        "7. GRANT on app_check_account_status",
        "GRANT EXECUTE ON FUNCTION app.app_check_account_status() TO authenticated"
    ),
]

# Extract function bodies from the SQL file
import re

# Find CREATE OR REPLACE FUNCTION blocks
func_pattern = re.compile(
    r'(CREATE OR REPLACE FUNCTION\s+\S+.*?\$\$\s*;)',
    re.DOTALL
)
functions = func_pattern.findall(full_sql)

if len(functions) >= 3:
    blocks[1] = ("2. CREATE RPC app_student_request_account_deletion", functions[0])
    blocks[3] = ("4. CREATE RPC app_admin_purge_deleted_accounts", functions[1])
    blocks[5] = ("6. CREATE RPC app_check_account_status", functions[2])
else:
    print(f"ERROR: Expected 3 functions, found {len(functions)}")
    sys.exit(1)

print(f"Deploying {len(blocks)} blocks...\n")
success_count = 0
fail_count = 0

for label, sql in blocks:
    if sql is None:
        print(f"  SKIP: {label} (no SQL)")
        continue
    print(f"Deploying: {label}")
    ok = run_sql(sql, label)
    if ok:
        success_count += 1
    else:
        fail_count += 1

print(f"\n{'='*50}")
print(f"Results: {success_count} OK, {fail_count} FAILED")

# Verify deployment
print("\nVerifying...")
verify_queries = {
    "columns_added": (
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='user_admin_status' "
        "AND column_name IN ('deletion_requested_at','purge_due_at','deletion_method') "
        "ORDER BY column_name"
    ),
    "rpcs_created": (
        "SELECT routine_name FROM information_schema.routines "
        "WHERE routine_schema IN ('app','public') "
        "AND routine_name IN ('app_student_request_account_deletion','app_admin_purge_deleted_accounts','app_check_account_status') "
        "ORDER BY routine_name"
    ),
    "cron_jobs": (
        "SELECT jobid, schedule, command FROM cron.job ORDER BY jobid"
    ),
}

for label, sql in verify_queries.items():
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": sql}, timeout=30)
    if r.status_code == 200:
        data = r.json()
        print(f"  {label}: {json.dumps(data, indent=2)}")
    else:
        print(f"  {label}: FAILED - {r.text[:200]}")
