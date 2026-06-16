#!/usr/bin/env python3
"""Fix DM delete RPC to use correct table name (direct_messages)."""
import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def exec_sql(sql_text, label=""):
    clean = " ".join(sql_text.split())
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": clean}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    print(f"  [{'OK' if ok else 'FAIL'}] {label} {body.get('error','') if not ok else ''}")
    return body

# 1. Check direct_messages columns
exec_sql("SELECT column_name FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'direct_messages' ORDER BY ordinal_position", "check direct_messages cols")

# 2. Recreate DM delete RPC with correct table
exec_sql("""
CREATE OR REPLACE FUNCTION app.app_student_delete_dm_message(
  p_message_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $fn$
DECLARE
  v_user_id uuid := auth.uid();
  v_msg_sender uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT sender_id INTO v_msg_sender
  FROM app.direct_messages
  WHERE id = p_message_id;

  IF v_msg_sender IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'message_not_found');
  END IF;

  IF v_msg_sender != v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_owner');
  END IF;

  UPDATE app.direct_messages
  SET content = '[Message supprime]', is_deleted = true
  WHERE id = p_message_id;

  RETURN jsonb_build_object('success', true);
END;
$fn$;
""", "app_student_delete_dm_message (fixed)")

# 3. Add is_deleted column if needed
exec_sql("""
ALTER TABLE app.direct_messages ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false;
""", "add is_deleted to direct_messages")

print("\nDone!")
