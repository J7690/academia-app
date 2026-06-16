import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q})
    return r.json()

# Use REST API with Accept-Profile to get columns via SELECT *
for table in ['platform_ledger', 'payout_queue']:
    print(f"\n### app.{table} — COLUMNS (via REST) ###")
    r = requests.get(f"{URL}/rest/v1/{table}?limit=0",
        headers={**H, "Accept-Profile": "app", "Prefer": "count=exact"})
    # The column names are in the response if we get 1 row
    r2 = requests.get(f"{URL}/rest/v1/{table}?limit=1",
        headers={**H, "Accept-Profile": "app"})
    data = r2.json()
    if isinstance(data, list) and data:
        for col, val in data[0].items():
            typ = type(val).__name__ if val is not None else "null"
            print(f"  {col:40s} sample={str(val)[:60]}")
    elif isinstance(data, list) and not data:
        print("  (empty table, trying column names via SQL)")
        # Fallback: create+call+drop
        sql(f"""
            CREATE OR REPLACE FUNCTION public._tmp_cols_{table}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
            DECLARE v JSONB;
            BEGIN
              SELECT jsonb_agg(jsonb_build_object('c', column_name, 't', data_type) ORDER BY ordinal_position) INTO v
              FROM information_schema.columns WHERE table_schema='app' AND table_name='{table}';
              RETURN v;
            END; $fn$;
        """)
        import time; time.sleep(2)
        r3 = requests.post(f"{URL}/rest/v1/rpc/_tmp_cols_{table}", headers=H, json={})
        cols = r3.json()
        sql(f"DROP FUNCTION IF EXISTS public._tmp_cols_{table}();")
        if isinstance(cols, list):
            for c in cols:
                print(f"  {c['c']:40s} {c['t']}")
        else:
            print(f"  {cols}")
    else:
        print(f"  {data}")
