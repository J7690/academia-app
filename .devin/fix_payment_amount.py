import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def rpc(name, params={}):
    r = requests.post(f"{URL}/rest/v1/rpc/{name}",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json=params)
    return r.json()

def sql(query):
    r = rpc("admin_execute_sql", {"p_sql": query})
    if isinstance(r, dict) and r.get('ok'):
        return r.get('rows', [])
    return r

# 1. Find the stuck 25000 payment for Agro
print("=== 1. All pending application_fee payments ===")
rows = sql("""
  SELECT ap.id, ap.application_id, ap.amount_due, ap.status, 
         p.title, p.brokerage_fee, p.id as program_id
  FROM app.application_payments ap
  JOIN app.applications a ON a.id = ap.application_id  
  JOIN app.programs p ON p.id = a.program_id
  WHERE ap.status = 'pending' AND ap.payment_reason = 'application_fee'
  ORDER BY ap.created_at DESC
""")
for r in rows:
    mismatch = " *** MISMATCH" if float(r['amount_due']) != float(r['brokerage_fee']) else ""
    print(f"  pay={r['id'][:8]}... amount={r['amount_due']} brokerage={r['brokerage_fee']} prog={r['title']}{mismatch}")

# 2. Create RPC to update payment amount when brokerage changes
print("\n=== 2. CREATE RPC app_update_payment_amount_from_brokerage ===")
r2 = rpc("admin_execute_sql", {"p_sql": """
CREATE OR REPLACE FUNCTION public.app_update_payment_amount_from_brokerage(
  p_payment_id UUID
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
  v_user_id UUID := auth.uid();
  v_payment RECORD;
  v_program RECORD;
  v_app RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_payment FROM app.application_payments WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_not_found');
  END IF;

  -- Only update pending payments
  IF v_payment.status <> 'pending' THEN
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'amount_due', v_payment.amount_due, 'unchanged', TRUE);
  END IF;

  -- Verify ownership
  IF v_payment.student_id <> v_user_id THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  -- Get application and program
  SELECT a.program_id INTO v_app FROM app.applications a WHERE a.id = v_payment.application_id;
  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
  END IF;

  SELECT p.brokerage_fee INTO v_program FROM app.programs p WHERE p.id = v_app.program_id;
  IF NOT FOUND OR COALESCE(v_program.brokerage_fee, 0) <= 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'brokerage_fee_not_defined');
  END IF;

  -- Update amount_due to match current brokerage_fee
  UPDATE app.application_payments
  SET amount_due = v_program.brokerage_fee, updated_at = NOW()
  WHERE id = p_payment_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'amount_due', v_program.brokerage_fee,
    'updated', v_payment.amount_due <> v_program.brokerage_fee
  );
END;
$fn$;
"""})
print(r2)

# 3. Fix the stuck 25000 payment manually
print("\n=== 3. Fix stuck payments where amount != brokerage ===")
stuck = sql("""
  UPDATE app.application_payments ap
  SET amount_due = p.brokerage_fee, updated_at = NOW()
  FROM app.applications a
  JOIN app.programs p ON p.id = a.program_id
  WHERE ap.application_id = a.id
    AND ap.status = 'pending'
    AND ap.payment_reason = 'application_fee'
    AND p.brokerage_fee > 0
    AND ap.amount_due <> p.brokerage_fee
  RETURNING ap.id, ap.amount_due, p.title
""")
print(stuck)
