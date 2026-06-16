#!/usr/bin/env python3
"""Déploie le pg_cron pour le bonus hebdomadaire de crédits + la RPC d'auto-distribution."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def execute_ddl(sql):
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl",
        headers=HEADERS,
        json={"ddl_query": sql},
        timeout=30,
    )
    return r.status_code, r.text[:300]

# 1. Create the auto-distribute RPC
rpc_sql = """
CREATE OR REPLACE FUNCTION app_student_auto_weekly_bonus()
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
  v_count INTEGER := 0;
  v_rec RECORD;
  v_new_balance INTEGER;
BEGIN
  -- Give 15 credits to all students who haven't received this week's bonus
  FOR v_rec IN
    SELECT student_id FROM app.student_credits
    WHERE last_weekly_bonus IS NULL
       OR last_weekly_bonus < NOW() - INTERVAL '6 days'
  LOOP
    UPDATE app.student_credits SET
      balance = balance + 15,
      total_gifted = total_gifted + 15,
      last_weekly_bonus = NOW(),
      updated_at = NOW()
    WHERE student_id = v_rec.student_id
    RETURNING balance INTO v_new_balance;

    INSERT INTO app.credit_transactions (student_id, amount, balance_after, transaction_type, description)
    VALUES (v_rec.student_id, 15, v_new_balance, 'weekly_bonus', 'Bonus hebdomadaire automatique — 15 crédits offerts');

    v_count := v_count + 1;
  END LOOP;

  RAISE LOG 'weekly_credit_bonus: distributed to % students', v_count;
  RETURN v_count;
END;
$fn$;
"""

print("1. Creating RPC app_student_auto_weekly_bonus...")
status, text = execute_ddl(rpc_sql)
print(f"   Status: {status} — {text}")

# 2. Create the pg_cron job (every Monday at 00:00 UTC)
cron_sql = """
SELECT cron.schedule(
  'weekly_credit_bonus',
  '0 0 * * 1',
  'SELECT app_student_auto_weekly_bonus()'
);
"""

print("\n2. Creating pg_cron job weekly_credit_bonus...")
status2, text2 = execute_ddl(cron_sql)
print(f"   Status: {status2} — {text2}")

# 3. Verify
print("\n3. Verifying...")
r = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
    headers=HEADERS,
    json={"sql_query": "SELECT jobid, schedule, command FROM cron.job WHERE jobname = 'weekly_credit_bonus'"},
    timeout=15,
)
if r.status_code == 200:
    jobs = r.json()
    if jobs:
        for j in jobs:
            print(f"   ✅ Job #{j.get('jobid')}: {j.get('schedule')} → {str(j.get('command',''))[:80]}")
    else:
        print("   ⚠️ Job not found in cron.job")
else:
    print(f"   Error: {r.status_code} {r.text[:200]}")

print("\nDone.")
