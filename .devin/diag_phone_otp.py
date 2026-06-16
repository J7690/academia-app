#!/usr/bin/env python3
"""
Diagnostic complet du flux OTP telephone dans Supabase.
Verifie: Phone Provider, SMS Hook, Edge Function, Twilio secrets, debug logs, pg_net.
"""

import requests, json, sys, time

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6"
    "InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ"
    ".U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
)
ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6"
    "ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0"
    ".8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"
)
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}
EDGE_URL = f"{SUPABASE_URL}/functions/v1/send-phone-otp"

results = {}

def sql(query, label=""):
    """Execute SQL via execute_sql RPC."""
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
            print(f"       Status={r.status_code} Body={str(data)[:200]}")
    return data

def ddl(query, label=""):
    """Execute DDL via execute_ddl RPC."""
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
        print(f"  {'[OK]' if ok else '[ERR]'} {label}: {str(data)[:150]}")
    return ok, data


# ============================================================
print("=" * 65)
print("  DIAGNOSTIC OTP TELEPHONE - SUPABASE")
print("=" * 65)

# ============================================================
# 1. Verifier que la fonction send_sms_hook existe
# ============================================================
print("\n[1/8] Fonction send_sms_hook existe ?")
data = sql("""
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'send_sms_hook' AND n.nspname = 'public'
""", "send_sms_hook lookup")
results["send_sms_hook_exists"] = data
if isinstance(data, list) and len(data) > 0:
    print(f"       -> Fonction trouvee!")
    defn = str(data[0].get("definition", ""))[:300] if isinstance(data[0], dict) else ""
    print(f"       Definition (debut): {defn}")
else:
    print(f"       -> FONCTION ABSENTE! C'est un probleme majeur.")

# ============================================================
# 2. Verifier les hooks dans auth.flow_state / auth.mfa_factors / config
# ============================================================
print("\n[2/8] Config auth hooks dans la DB...")
# Check if supabase_auth has hooks configured in auth schema
data = sql("""
SELECT key, value FROM auth.config
WHERE key LIKE '%sms%' OR key LIKE '%phone%' OR key LIKE '%hook%'
LIMIT 20
""", "auth.config sms/phone/hook")
results["auth_config"] = data

# Also check auth.schema_migrations to see if hooks are available
data2 = sql("""
SELECT * FROM auth.schema_migrations ORDER BY version DESC LIMIT 5
""", "auth.schema_migrations (latest)")

# ============================================================
# 3. Verifier la table sms_hook_debug_log
# ============================================================
print("\n[3/8] Table sms_hook_debug_log - derniers appels...")
data = sql("""
SELECT id, phone_extracted, otp_extracted, created_at,
       LEFT(event_raw::text, 200) AS event_preview
FROM public.sms_hook_debug_log
ORDER BY created_at DESC
LIMIT 5
""", "sms_hook_debug_log")
results["debug_log"] = data
if isinstance(data, list):
    if len(data) == 0:
        print("       -> AUCUN LOG! Le hook n'a jamais ete appele.")
        print("       -> Cela signifie que Supabase Auth ne declenche PAS le hook.")
    else:
        print(f"       -> {len(data)} entree(s) trouvee(s):")
        for row in data:
            print(f"          phone={row.get('phone_extracted')} otp_len={len(str(row.get('otp_extracted','')))} at={row.get('created_at')}")
            print(f"          event_preview={row.get('event_preview','')[:150]}")

# ============================================================
# 4. Verifier pg_net - requetes HTTP sortantes
# ============================================================
print("\n[4/8] pg_net HTTP requests recentes (appels Edge Function)...")
data = sql("""
SELECT id, method, url, status_code, created, 
       LEFT(response_body::text, 200) AS resp_preview
FROM net._http_response
ORDER BY created DESC
LIMIT 5
""", "net._http_response")
results["pg_net_responses"] = data
if isinstance(data, list) and len(data) > 0:
    for row in data:
        print(f"       id={row.get('id')} status={row.get('status_code')} url={str(row.get('url',''))[:80]}")
        print(f"       resp={row.get('resp_preview','')[:120]}")
elif isinstance(data, dict) and "message" in str(data):
    # Try alternative table name
    print("       -> Table net._http_response inaccessible, essai alternatif...")
    data = sql("""
    SELECT * FROM net.http_request_queue ORDER BY id DESC LIMIT 3
    """, "net.http_request_queue")
    results["pg_net_queue"] = data

# ============================================================
# 5. Tester directement l'Edge Function send-phone-otp
# ============================================================
print("\n[5/8] Test direct Edge Function send-phone-otp...")
test_payload = {
    "phone": "+22670000000",
    "otp": "123456"
}
try:
    r = requests.post(
        EDGE_URL,
        headers={
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json",
        },
        json=test_payload,
        timeout=30,
    )
    print(f"  Status: {r.status_code}")
    try:
        resp_json = r.json()
        print(f"  Response: {json.dumps(resp_json, indent=2)[:300]}")
        results["edge_function_test"] = {"status": r.status_code, "body": resp_json}
    except:
        print(f"  Raw response: {r.text[:300]}")
        results["edge_function_test"] = {"status": r.status_code, "body": r.text[:300]}
except Exception as e:
    print(f"  ERREUR: {e}")
    results["edge_function_test"] = {"error": str(e)}

# ============================================================
# 6. Verifier les secrets Twilio dans les Edge Functions
# ============================================================
print("\n[6/8] Verification secrets Edge Function (via invocation test)...")
# On essaie avec un payload minimal pour voir si les secrets sont configures
test_payload2 = {
    "phone": "+22600000000",
    "otp": "000000"
}
try:
    r = requests.post(
        EDGE_URL,
        headers={
            "Authorization": f"Bearer {ANON_KEY}",
            "Content-Type": "application/json",
        },
        json=test_payload2,
        timeout=30,
    )
    print(f"  Status (anon key): {r.status_code}")
    try:
        resp = r.json()
        print(f"  Response: {json.dumps(resp)[:200]}")
        if resp.get("error") == "missing_twilio_config":
            print("  --> PROBLEME: Les secrets TWILIO ne sont PAS configures dans l'Edge Function!")
            print("      Il faut les configurer avec:")
            print("      supabase secrets set TWILIO_ACCOUNT_SID=xxx TWILIO_AUTH_TOKEN=xxx TWILIO_VERIFY_SERVICE_SID=xxx")
        elif resp.get("error") == "twilio_error":
            print(f"  --> Twilio a repondu avec une erreur. Code: {resp.get('code')}")
        elif resp.get("success"):
            print("  --> Edge Function + Twilio fonctionnent!")
    except:
        print(f"  Raw: {r.text[:200]}")
except Exception as e:
    print(f"  ERREUR: {e}")

# ============================================================
# 7. Simuler un signInWithOtp via l'API Auth de Supabase
# ============================================================
print("\n[7/8] Simulation signInWithOtp (phone) via Supabase Auth API...")
TEST_PHONE = "+22670000000"
try:
    r = requests.post(
        f"{SUPABASE_URL}/auth/v1/otp",
        headers={
            "apikey": ANON_KEY,
            "Content-Type": "application/json",
        },
        json={
            "phone": TEST_PHONE,
        },
        timeout=30,
    )
    print(f"  Status: {r.status_code}")
    try:
        resp = r.json()
        print(f"  Response: {json.dumps(resp)[:300]}")
        results["auth_otp_test"] = {"status": r.status_code, "body": resp}
        if r.status_code == 200:
            print("  --> Supabase Auth a ACCEPTE la requete OTP!")
            print("      Verifier maintenant si le hook a ete declenche...")
        elif "Phone logins are disabled" in str(resp):
            print("  --> PROBLEME: Phone Provider DESACTIVE dans Supabase Auth!")
            print("      Aller dans Dashboard > Authentication > Providers > Phone")
            print("      et l'activer.")
        elif "sms send" in str(resp).lower() or "hook" in str(resp).lower():
            print("  --> Erreur liee au SMS Hook ou a l'envoi.")
        else:
            print(f"  --> Erreur inattendue: {resp}")
    except:
        print(f"  Raw: {r.text[:300]}")
        results["auth_otp_test"] = {"status": r.status_code, "body": r.text[:300]}
except Exception as e:
    print(f"  ERREUR: {e}")
    results["auth_otp_test"] = {"error": str(e)}

# Petit delai pour que le hook ait le temps de s'executer
time.sleep(3)

# ============================================================
# 8. Re-verifier les logs apres le test
# ============================================================
print("\n[8/8] Re-check debug log apres simulation OTP...")
data = sql("""
SELECT id, phone_extracted, otp_extracted, created_at,
       LEFT(event_raw::text, 300) AS event_preview
FROM public.sms_hook_debug_log
ORDER BY created_at DESC
LIMIT 3
""", "sms_hook_debug_log (post-test)")
results["debug_log_post"] = data
if isinstance(data, list):
    if len(data) == 0:
        print("       -> TOUJOURS AUCUN LOG apres simulation!")
        print("       -> CONCLUSION: Le Send SMS Hook N'EST PAS CONFIGURE dans Supabase Auth.")
        print("       -> Il faut aller dans Dashboard > Authentication > Hooks > Send SMS")
        print("          et configurer: Schema=public, Function=send_sms_hook")
    else:
        latest = data[0]
        print(f"       -> Dernier log: phone={latest.get('phone_extracted')} otp_len={len(str(latest.get('otp_extracted','')))}")
        print(f"          event={latest.get('event_preview','')[:200]}")

# ============================================================
# Aussi verifier pg_net apres le test
# ============================================================
print("\n[BONUS] pg_net apres simulation...")
data = sql("""
SELECT id, status_code, url, created,
       LEFT(response_body::text, 200) AS resp_body
FROM net._http_response
WHERE url LIKE '%send-phone-otp%'
ORDER BY created DESC
LIMIT 3
""", "pg_net send-phone-otp calls")
if isinstance(data, list) and len(data) > 0:
    for row in data:
        print(f"       id={row.get('id')} status={row.get('status_code')} at={row.get('created')}")
        print(f"       body={row.get('resp_body','')[:150]}")
else:
    print("       -> Aucun appel pg_net vers send-phone-otp trouve.")

# ============================================================
print("\n" + "=" * 65)
print("  RESUME DIAGNOSTIC")
print("=" * 65)

# Sauvegarder le rapport
report_path = "logs/diag_phone_otp_report.json"
import os
os.makedirs("logs", exist_ok=True)
with open(report_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, default=str)
print(f"\nRapport sauvegarde: .windsurf/{report_path}")
