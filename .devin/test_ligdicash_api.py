"""
Test direct des APIs LigdiCash pour diagnostiquer les erreurs.
1. Récupérer les vrais secrets via Supabase management API
2. Tester debitotp pour Orange Money
3. Tester debitwallet/withotp
"""
import requests, json

# Supabase project config
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

# Step 1: Get LigdiCash secrets from Edge Function environment
# We can't read secrets directly, so let's invoke the Edge Function and check logs
# Instead, let's read them from the .env.local or project secrets

# Try reading .env file for LigdiCash keys
import os

env_paths = [
    r"C:\Users\fasop\AndroidStudioProjects\academia\supabase\.env",
    r"C:\Users\fasop\AndroidStudioProjects\academia\supabase\.env.local",
    r"C:\Users\fasop\AndroidStudioProjects\academia\.env",
    r"C:\Users\fasop\AndroidStudioProjects\academia\.env.local",
]

ligdicash_api_key = None
ligdicash_bearer_token = None

for p in env_paths:
    if os.path.exists(p):
        print(f"Found env file: {p}")
        with open(p) as f:
            for line in f:
                line = line.strip()
                if line.startswith("LIGDICASH_API_KEY="):
                    ligdicash_api_key = line.split("=", 1)[1].strip().strip('"').strip("'")
                elif line.startswith("LIGDICASH_BEARER_TOKEN="):
                    ligdicash_bearer_token = line.split("=", 1)[1].strip().strip('"').strip("'")

if not ligdicash_api_key or not ligdicash_bearer_token:
    print("LigdiCash keys not found in local .env files.")
    print("Trying to call Edge Function directly to check response...")
    
    # Call the Edge Function with a test user auth to see the raw response
    # We need to find a valid user token or use the service role key
    
    # Alternative: Call the Edge Function directly with service role
    print("\n--- Testing Edge Function ligdicash-initiate directly ---")
    
    # First, we need a valid payment_id. Let's get the latest pending one.
    headers = {"Authorization": f"Bearer {SERVICE_KEY}", "apikey": SERVICE_KEY, "Content-Type": "application/json"}
    
    # Get a recent pending credit_purchase payment
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=headers, json={
        "sql_query": "SELECT id, student_id, amount_due, status, payment_reason FROM app.application_payments WHERE payment_reason='credit_purchase' AND status IN ('pending','processing') ORDER BY created_at DESC LIMIT 5"
    })
    print("\nRecent credit_purchase payments:")
    data = r.json()
    if isinstance(data, list):
        for row in data:
            print(json.dumps(row, ensure_ascii=False))
    else:
        print(data)
    
    print("\n--- Cannot test LigdiCash API directly without API keys ---")
    print("Let me create a diagnostic Edge Function call instead...")
    
else:
    print(f"API Key: {ligdicash_api_key[:8]}...{ligdicash_api_key[-4:]}")
    print(f"Bearer Token: {ligdicash_bearer_token[:8]}...{ligdicash_bearer_token[-4:]}")
    
    # Test 1: debitotp
    phone = "22666660538"
    amount = 100
    
    print(f"\n--- TEST 1: debitotp for {phone}/{amount} ---")
    url = f"https://app.ligdicash.com/pay/v02/debitotp/{phone}/{amount}"
    print(f"URL: {url}")
    
    r = requests.get(url, headers={
        "Apikey": ligdicash_api_key,
        "Authorization": f"Bearer {ligdicash_bearer_token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }, timeout=30)
    
    print(f"Status: {r.status_code}")
    print(f"Response: {r.text}")
    
    # Test 2: Try with higher amount (maybe 100 is below minimum)
    amount2 = 500
    print(f"\n--- TEST 2: debitotp for {phone}/{amount2} ---")
    url2 = f"https://app.ligdicash.com/pay/v02/debitotp/{phone}/{amount2}"
    r2 = requests.get(url2, headers={
        "Apikey": ligdicash_api_key,
        "Authorization": f"Bearer {ligdicash_bearer_token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }, timeout=30)
    
    print(f"Status: {r2.status_code}")
    print(f"Response: {r2.text}")

# Also: let's create a diagnostic Edge Function call that returns the raw LigdiCash response
print("\n\n--- Creating diagnostic test via Edge Function ---")
# We'll invoke the edge function with the service role key directly
# But Edge Functions need user auth. Let's check if we can call with service role.

# Actually, let's check supabase logs
print("Check Supabase Edge Function logs at:")
print("https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/functions/ligdicash-initiate/logs")
print("https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/functions/ligdicash-confirm/logs")
