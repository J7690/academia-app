#!/usr/bin/env python3
"""
Fix send_sms_hook: extraire phone/otp depuis tous les formats possibles
et construire un payload propre pour l'Edge Function.
Aussi creer une table de debug pour logger le payload brut recu.
"""

import requests

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
EDGE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/send-phone-otp"


def ddl(sql, label=""):
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl",
        headers=HEADERS,
        json={"ddl_query": sql},
        timeout=30,
    )
    ok = r.status_code == 200
    try:
        body = r.json()
        success = isinstance(body, dict) and body.get("success")
    except Exception:
        success = False
    print(f"  {'OK' if (ok and success) else 'ERR'} [{label}]: {'' if (ok and success) else r.text[:200]}")
    return ok


# 1. Creer table de debug pour voir le payload brut
print("[1] Creer table debug sms_hook_log...")
ddl("""
CREATE TABLE IF NOT EXISTS public.sms_hook_debug_log (
  id SERIAL PRIMARY KEY,
  event_raw JSONB,
  phone_extracted TEXT,
  otp_extracted TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
""", "create debug table")

# 2. Remplacer send_sms_hook avec extraction robuste + debug log
print("[2] Mise a jour send_sms_hook avec extraction robuste...")

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
  v_url  text := '""" + EDGE_URL + """';
  v_auth text := 'Bearer """ + SERVICE_KEY + """';
  v_phone text;
  v_otp   text;
  v_payload jsonb;
BEGIN
  -- Extraire phone depuis tous les formats possibles
  v_phone := COALESCE(
    event->>'phone',
    event->'user'->>'phone',
    event->'data'->>'phone'
  );

  -- Extraire otp depuis tous les formats possibles
  v_otp := COALESCE(
    event->>'otp',
    event->'sms'->>'otp',
    event->'email_data'->>'token',
    event->'data'->>'otp'
  );

  -- Log pour debug (on peut supprimer apres validation)
  INSERT INTO public.sms_hook_debug_log (event_raw, phone_extracted, otp_extracted)
  VALUES (event, v_phone, v_otp);

  -- Construire un payload propre pour l'Edge Function
  v_payload := jsonb_build_object(
    'phone', v_phone,
    'otp',   v_otp
  );

  SELECT net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', v_auth
    ),
    body    := v_payload
  ) INTO request_id;

  RETURN jsonb_build_object('success', true);
END;
$func$;

GRANT EXECUTE ON FUNCTION public.send_sms_hook(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.send_sms_hook(jsonb) FROM authenticated, anon, public;
"""

ddl(sql, "update send_sms_hook")

print("\n[3] Verification...")
import json
r = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
    headers=HEADERS,
    json={"sql_query": "SELECT proname FROM pg_proc WHERE proname='send_sms_hook' AND pronamespace::regnamespace::text='public'"},
    timeout=20,
)
print(f"  Fonction: {r.json()}")

print("\nDone. Maintenant envoyer un OTP et verifier sms_hook_debug_log.")
