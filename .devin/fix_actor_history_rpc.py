import requests, json, time
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q})
    j = r.json()
    print(f"  -> ok={j.get('ok')}")
    return j

print("### Redeploy app_admin_finance_actor_history ###")
# Drop and recreate to force schema cache refresh
sql("DROP FUNCTION IF EXISTS public.app_admin_finance_actor_history(UUID, INT, INT);")
time.sleep(1)

sql("""
CREATE OR REPLACE FUNCTION public.app_admin_finance_actor_history(
  p_actor_id UUID DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_payouts JSONB;
  v_ledger JSONB;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_uid;
  IF v_role <> 'admin' THEN RETURN jsonb_build_object('success', false, 'error', 'not_admin'); END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(pq)::jsonb ORDER BY pq.created_at DESC), '[]'::jsonb)
  INTO v_payouts
  FROM (
    SELECT id, beneficiary_type, amount, currency, reason, status, error_message, retry_count, processed_at, created_at
    FROM app.payout_queue WHERE beneficiary_user_id = p_actor_id
    ORDER BY created_at DESC LIMIT p_limit OFFSET p_offset
  ) pq;

  SELECT COALESCE(jsonb_agg(row_to_json(pl)::jsonb ORDER BY pl.created_at DESC), '[]'::jsonb)
  INTO v_ledger
  FROM (
    SELECT id, transaction_type, amount, currency, direction, description, created_at
    FROM app.platform_ledger WHERE counterpart_id = p_actor_id
    ORDER BY created_at DESC LIMIT p_limit OFFSET p_offset
  ) pl;

  RETURN jsonb_build_object('success', true, 'payouts', v_payouts, 'ledger', v_ledger);
END; $fn$;
""")

# Notify PostgREST to refresh schema cache
print("\n### Notify schema cache refresh ###")
sql("NOTIFY pgrst, 'reload schema';")

time.sleep(3)

# Verify
print("\n### Verify ###")
r = requests.post(f"{URL}/rest/v1/rpc/app_admin_finance_actor_history", headers=H, json={})
body = r.json()
if isinstance(body, dict):
    if body.get('error') == 'not_authenticated' or body.get('success') is not None:
        print(f"  ✅ app_admin_finance_actor_history — EXISTS")
    else:
        print(f"  ❌ {body}")
