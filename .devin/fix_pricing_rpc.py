import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def rpc(name, params={}):
    r = requests.post(f"{URL}/rest/v1/rpc/{name}",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json=params)
    return r.json()

# Update RPC to include university_name for admin pricing
print("=== UPDATE RPC app_admin_list_programs_pricing with university_name ===")
r = rpc("admin_execute_sql", {"p_sql": """
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
      'university_id', p.university_id,
      'university_name', COALESCE(u.name, 'Inconnue')
    ) ORDER BY u.name, p.title)
    FROM app.programs p
    LEFT JOIN app.universities u ON u.id = p.university_id
  ));
END;
$fn$;
"""})
print(r)
