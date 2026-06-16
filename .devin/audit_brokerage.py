import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def rpc(name, params={}):
    r = requests.post(f"{URL}/rest/v1/rpc/{name}",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json=params)
    return r.json()

# 1. Columns of app.programs
print("=== COLUMNS app.programs ===")
cols = rpc("admin_execute_sql", {"p_sql": "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='programs' ORDER BY ordinal_position"})
if isinstance(cols, list):
    for c in cols:
        print(f"  {c.get('column_name','?'):30s} {c.get('data_type','?'):20s} default={c.get('column_default','')}")
else:
    print(cols)

# 2. Check if tuition_fees or brokerage_fee exists
print("\n=== TUITION/BROKERAGE columns ===")
cols2 = rpc("admin_execute_sql", {"p_sql": "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='programs' AND column_name IN ('tuition_fees','brokerage_fee','application_fee','platform_fee')"})
print(cols2)

# 3. RPC app_admin_list_programs_pricing source
print("\n=== RPC app_admin_list_programs_pricing ===")
src = rpc("admin_execute_sql", {"p_sql": "SELECT LEFT(prosrc, 2000) as src FROM pg_proc WHERE proname='app_admin_list_programs_pricing'"})
if isinstance(src, list) and src:
    print(src[0].get('src','')[:2000])
else:
    print(src)

# 4. RPC app_admin_update_program_fees source
print("\n=== RPC app_admin_update_program_fees ===")
src2 = rpc("admin_execute_sql", {"p_sql": "SELECT LEFT(prosrc, 2000) as src FROM pg_proc WHERE proname='app_admin_update_program_fees'"})
if isinstance(src2, list) and src2:
    print(src2[0].get('src','')[:2000])
else:
    print(src2)

# 5. RPC app_create_application_payment source (student creates payment)
print("\n=== RPC app_create_application_payment ===")
src3 = rpc("admin_execute_sql", {"p_sql": "SELECT LEFT(prosrc, 2000) as src FROM pg_proc WHERE proname='app_create_application_payment'"})
if isinstance(src3, list) and src3:
    print(src3[0].get('src','')[:2000])
else:
    print(src3)

# 6. Sample programs with fees
print("\n=== SAMPLE PROGRAMS (fees) ===")
progs = rpc("admin_execute_sql", {"p_sql": "SELECT id, title, tuition_fees, is_active FROM app.programs LIMIT 10"})
if isinstance(progs, list):
    for p in progs:
        print(f"  {p.get('title','?')[:40]:40s} tuition={p.get('tuition_fees','NULL'):>10s} active={p.get('is_active','?')}")
else:
    print(progs)

# 7. Check what the student payment flow uses
print("\n=== RECENT APPLICATION PAYMENTS (application_fee) ===")
pays = rpc("admin_execute_sql", {"p_sql": "SELECT id, application_id, amount_due, amount_paid, payment_reason, status FROM app.application_payments WHERE payment_reason='application_fee' ORDER BY created_at DESC LIMIT 5"})
if isinstance(pays, list):
    for p in pays:
        print(f"  id={p.get('id','?')[:8]}... amount_due={p.get('amount_due','?')} reason={p.get('payment_reason','?')} status={p.get('status','?')}")
else:
    print(pays)
