import requests, json
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

# Call each new RPC directly — they'll return not_authenticated (which PROVES they exist)
for rpc in ['app_admin_finance_overview', 'app_admin_finance_live_feed', 'app_admin_finance_payout_feed', 'app_admin_finance_actor_history']:
    r = requests.post(f"{URL}/rest/v1/rpc/{rpc}", headers=H, json={})
    body = r.json()
    if isinstance(body, dict):
        # not_authenticated = RPC EXISTS but auth.uid() is null (expected with service_role)
        if body.get('error') == 'not_authenticated' or body.get('success') is not None:
            print(f"  ✅ {rpc} — EXISTS (returns: {body.get('error') or body.get('success')})")
        elif 'PGRST202' in str(body.get('code', '')):
            print(f"  ❌ {rpc} — NOT FOUND in PostgREST cache")
        else:
            print(f"  ⚠️ {rpc} — {json.dumps(body)[:120]}")
    else:
        print(f"  ❌ {rpc} — unexpected: {body}")
