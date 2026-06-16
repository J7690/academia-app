#!/usr/bin/env python3
import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6"
    "InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ"
    ".U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
)
HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
}
EDGE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/send-phone-otp"

# La signature correcte pour Supabase Auth SMS Hook: retourne jsonb (pas void)
sql = """
DROP FUNCTION IF EXISTS public.send_sms_hook(jsonb);

CREATE OR REPLACE FUNCTION public.send_sms_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $func$
DECLARE
  request_id bigint;
  v_url      text := '""" + EDGE_URL + """';
  v_auth     text := 'Bearer """ + SERVICE_ROLE_KEY + """';
BEGIN
  SELECT net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', v_auth
    ),
    body    := event
  ) INTO request_id;

  RETURN jsonb_build_object('success', true);
END;
$func$;

GRANT EXECUTE ON FUNCTION public.send_sms_hook(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.send_sms_hook(jsonb) FROM authenticated, anon, public;
"""

print("Deploying send_sms_hook (returns jsonb)...")
r = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl",
    headers=HEADERS,
    json={"ddl_query": sql},
    timeout=30,
)
print(f"HTTP {r.status_code}")
print(r.text[:400])

if r.status_code == 200:
    import json
    body = r.json()
    if isinstance(body, dict) and body.get("success"):
        print("\n[OK] send_sms_hook deployee avec signature RETURNS jsonb")
    else:
        print(f"\nReponse: {body}")
