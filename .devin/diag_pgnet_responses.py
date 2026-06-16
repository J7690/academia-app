#!/usr/bin/env python3
"""
Check pg_net actual columns and recent responses to understand
if send_sms_hook HTTP calls are going through to the Edge Function.
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

# 1. Get actual columns of net._http_response
print("[1] Colonnes de net._http_response...")
data = sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'net' AND table_name = '_http_response'
ORDER BY ordinal_position
""", "columns")
print(f"    {json.dumps(data, indent=2)}")

# 2. Get recent responses with correct columns
print("\n[2] 10 dernieres reponses pg_net...")
data = sql("""
SELECT id, status_code, timed_out, created,
       LEFT(content::text, 200) AS content_preview
FROM net._http_response
ORDER BY created DESC
LIMIT 10
""", "recent responses")
if isinstance(data, list):
    for row in data:
        print(f"    id={row.get('id')} status={row.get('status_code')} timed_out={row.get('timed_out')} at={row.get('created')}")
        print(f"    content={row.get('content_preview','')[:150]}")
        print()

# 3. Check if there's an http_request_queue table
print("\n[3] Colonnes de net.http_request_queue (si existe)...")
data = sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'net' AND table_name = 'http_request_queue'
ORDER BY ordinal_position
""", "queue columns")
print(f"    {json.dumps(data, indent=2)[:500]}")

# 4. Check recent queue entries
print("\n[4] Dernieres entrees dans la queue pg_net...")
data = sql("""
SELECT id, method, url, timeout_milliseconds, added
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 5
""", "queue entries")
if isinstance(data, list):
    for row in data:
        print(f"    id={row.get('id')} method={row.get('method')} url={str(row.get('url',''))[:80]} at={row.get('added')}")
else:
    print(f"    -> {str(data)[:200]}")

# 5. Find responses that match our Edge Function URL (check content for clues)
print("\n[5] Reponses contenant 'send-phone-otp' ou 'twilio'...")
data = sql("""
SELECT id, status_code, created,
       LEFT(content::text, 300) AS content_preview
FROM net._http_response
WHERE content::text LIKE '%send-phone-otp%'
   OR content::text LIKE '%twilio%'
   OR content::text LIKE '%phone%'
ORDER BY created DESC
LIMIT 5
""", "otp-related responses")
if isinstance(data, list):
    if len(data) == 0:
        print("    -> Aucune reponse contenant phone/twilio/otp trouvee")
    for row in data:
        print(f"    id={row.get('id')} status={row.get('status_code')} at={row.get('created')}")
        print(f"    content={row.get('content_preview','')[:250]}")
        print()
else:
    print(f"    -> {str(data)[:300]}")

# 6. Check the most recent responses matching the time of the debug log entries
print("\n[6] Reponses pg_net autour de 14:30-14:32 UTC (moment du test utilisateur)...")
data = sql("""
SELECT id, status_code, timed_out, created,
       LEFT(content::text, 300) AS content_preview
FROM net._http_response
WHERE created >= '2026-04-16T14:29:00Z' AND created <= '2026-04-16T14:35:00Z'
ORDER BY created DESC
LIMIT 10
""", "responses around test time")
if isinstance(data, list):
    if len(data) == 0:
        print("    -> Aucune reponse pg_net dans cette fenetre")
    for row in data:
        print(f"    id={row.get('id')} status={row.get('status_code')} timed_out={row.get('timed_out')} at={row.get('created')}")
        print(f"    content={row.get('content_preview','')[:250]}")
        print()
else:
    print(f"    -> {str(data)[:300]}")

# 7. Check worker status
print("\n[7] pg_net worker status...")
data = sql("SELECT net.check_worker_is_up()", "worker check")
print(f"    -> {data}")
