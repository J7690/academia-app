import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def rpc(name, params={}):
    r = requests.post(f"{URL}/rest/v1/rpc/{name}",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json=params)
    return r.json()

# 1. Add brokerage_fee column to app.programs
print("=== 1. ADD brokerage_fee column ===")
r1 = rpc("admin_execute_sql", {"p_sql": """
ALTER TABLE app.programs ADD COLUMN IF NOT EXISTS brokerage_fee NUMERIC DEFAULT 0;
COMMENT ON COLUMN app.programs.brokerage_fee IS 'Frais de courtage plateforme (XOF) - ce que la plateforme facture pour le programme';
"""})
print(r1)

# 2. Replace RPC app_admin_list_programs_pricing to include brokerage_fee
print("\n=== 2. UPDATE RPC app_admin_list_programs_pricing ===")
r2 = rpc("admin_execute_sql", {"p_sql": """
CREATE OR REPLACE FUNCTION public.app_admin_list_programs_pricing()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_role TEXT;
BEGIN
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_admin'); END IF;
  RETURN JSONB_BUILD_OBJECT('success',TRUE,'programs',(
    SELECT JSONB_AGG(JSONB_BUILD_OBJECT(
      'id', p.id, 'title', p.title, 'degree_level', p.degree_level,
      'tuition_fees', p.tuition_fees,
      'brokerage_fee', COALESCE(p.brokerage_fee, 0),
      'is_active', p.is_active,
      'university_id', p.university_id
    ) ORDER BY p.title)
    FROM app.programs p
  ));
END;
$fn$;
"""})
print(r2)

# 3. Replace RPC app_admin_update_program_fees to support brokerage_fee
print("\n=== 3. UPDATE RPC app_admin_update_program_fees ===")
r3 = rpc("admin_execute_sql", {"p_sql": """
CREATE OR REPLACE FUNCTION public.app_admin_update_program_fees(
  p_program_id UUID,
  p_tuition_fees NUMERIC DEFAULT NULL,
  p_brokerage_fee NUMERIC DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_role TEXT;
BEGIN
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_admin'); END IF;
  UPDATE app.programs SET
    tuition_fees = COALESCE(p_tuition_fees, tuition_fees),
    brokerage_fee = COALESCE(p_brokerage_fee, brokerage_fee),
    is_active = COALESCE(p_is_active, is_active),
    updated_at = NOW()
  WHERE id = p_program_id;
  IF NOT FOUND THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_found'); END IF;
  RETURN JSONB_BUILD_OBJECT('success',TRUE);
END;
$fn$;
"""})
print(r3)

# 4. Create RPC for students to get brokerage fee for a program (via application)
print("\n=== 4. CREATE RPC app_get_program_brokerage_fee ===")
r4 = rpc("admin_execute_sql", {"p_sql": """
CREATE OR REPLACE FUNCTION public.app_get_program_brokerage_fee(p_application_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
  v_user_id UUID := auth.uid();
  v_app RECORD;
  v_program RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT a.id, a.student_id, a.program_id
  INTO v_app
  FROM app.applications a
  WHERE a.id = p_application_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
  END IF;

  IF v_app.student_id <> v_user_id THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  SELECT p.id, p.title, p.brokerage_fee, p.tuition_fees
  INTO v_program
  FROM app.programs p
  WHERE p.id = v_app.program_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'program_not_found');
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'program_id', v_program.id,
    'program_title', v_program.title,
    'brokerage_fee', COALESCE(v_program.brokerage_fee, 0),
    'currency', 'XOF'
  );
END;
$fn$;
"""})
print(r4)

# 5. Verify
print("\n=== 5. VERIFY brokerage_fee column ===")
r5 = rpc("admin_execute_sql", {"p_sql": "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='programs' AND column_name='brokerage_fee'"})
print(r5)

print("\n=== 6. VERIFY sample programs with brokerage_fee ===")
r6 = rpc("admin_execute_sql", {"p_sql": "SELECT id, title, tuition_fees, brokerage_fee, is_active FROM app.programs WHERE is_active=true LIMIT 5"})
print(r6)
