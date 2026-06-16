#!/usr/bin/env python3
"""
Diagnostic pg_net + fix: verifier pourquoi net.http_post ne fonctionne pas
dans send_sms_hook, puis corriger.
"""

import requests, json, time

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6"
    "InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ"
    ".U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
)
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

def sql(query, label=""):
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": query},
        timeout=30,
    )
    try:
        data = r.json()
    except:
        data = r.text[:500]
    if label:
        ok = r.status_code == 200
        print(f"  {'[OK]' if ok else '[ERR]'} {label}")
        if not ok:
            print(f"       {str(data)[:300]}")
    return data

def ddl(query, label=""):
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl",
        headers=HEADERS,
        json={"ddl_query": query},
        timeout=30,
    )
    try:
        data = r.json()
    except:
        data = r.text[:300]
    ok = r.status_code == 200
    if label:
        print(f"  {'[OK]' if ok else '[ERR]'} {label}: {str(data)[:200]}")
    return ok, data


print("=" * 65)
print("  DIAGNOSTIC pg_net + CORRECTION send_sms_hook")
print("=" * 65)

# 1. Extension pg_net activee?
print("\n[1] Extension pg_net activee?")
data = sql("SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_net'", "pg_net extension")
print(f"       -> {data}")

# 2. Fonction net.http_post existe?
print("\n[2] Fonction net.http_post existe?")
data = sql("""
SELECT p.proname, n.nspname, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'http_post' AND n.nspname = 'net'
""", "net.http_post lookup")
print(f"       -> {json.dumps(data, indent=2)[:500]}")

# 3. Compter les lignes dans net._http_response
print("\n[3] Nombre total d'entrees dans net._http_response...")
data = sql("SELECT COUNT(*) AS cnt FROM net._http_response", "count _http_response")
print(f"       -> {data}")

# 4. Tester net.http_post directement
print("\n[4] Test direct de net.http_post (appel test vers Edge Function)...")
data = sql("""
SELECT net.http_post(
    url     := 'https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/send-phone-otp',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer """ + SERVICE_KEY + """"}',
    body    := '{"phone": "+22670000099", "otp": "999999"}'
) AS request_id
""", "net.http_post direct test")
print(f"       -> {data}")
if isinstance(data, list) and len(data) > 0:
    req_id = data[0].get("request_id")
    print(f"       request_id = {req_id}")
    if req_id:
        print("       Attente 5s pour que pg_net traite la requete...")
        time.sleep(5)
        resp = sql(f"""
        SELECT id, status_code, url, created,
               LEFT(content::text, 300) AS content_preview,
               LEFT(response_body::text, 300) AS resp_body
        FROM net._http_response
        WHERE id = {req_id}
        """, f"response for request {req_id}")
        print(f"       -> {json.dumps(resp, indent=2, default=str)[:500]}")

# 5. Verifier le format des headers dans send_sms_hook
print("\n[5] Verifier le format exact de l'appel net.http_post dans send_sms_hook...")
data = sql("""
SELECT pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'send_sms_hook' AND n.nspname = 'public'
""", "full definition")
if isinstance(data, list) and len(data) > 0:
    defn = data[0].get("definition", "")
    print(f"\n--- DEFINITION COMPLETE ---")
    print(defn)
    print("--- FIN DEFINITION ---\n")

# 6. Verifier si le probleme est le format des headers (text vs jsonb)
print("\n[6] Verifier la signature exacte de net.http_post attendue...")
data = sql("""
SELECT p.proname, pg_get_function_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS result
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'http_post' AND n.nspname = 'net'
""", "net.http_post signatures")
print(f"       -> {json.dumps(data, indent=2)[:600]}")

# 7. Verifier si net.http_post existe avec le bon type de params
print("\n[7] Toutes les fonctions net.*...")
data = sql("""
SELECT p.proname, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'net'
ORDER BY p.proname
""", "all net.* functions")
print(f"       -> {json.dumps(data, indent=2)[:800]}")

print("\n" + "=" * 65)
print("  FIN DIAGNOSTIC pg_net")
print("=" * 65)
