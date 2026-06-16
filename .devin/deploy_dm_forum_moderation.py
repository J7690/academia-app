#!/usr/bin/env python3
"""Deploy DM delete + Forum delete/report RPCs for Google Play compliance."""
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
    status = "OK" if ok else "FAIL"
    err = body.get("error", "") if not ok else ""
    print(f"  [{status}] {label} {err}")
    return body

# 1. DM: Delete own message RPC
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
  FROM app.dm_messages
  WHERE id = p_message_id;

  IF v_msg_sender IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'message_not_found');
  END IF;

  IF v_msg_sender != v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_owner');
  END IF;

  UPDATE app.dm_messages
  SET content = '[Message supprime]', message_type = 'deleted'
  WHERE id = p_message_id;

  RETURN jsonb_build_object('success', true);
END;
$fn$;
""", "app_student_delete_dm_message")

# 2. Forum: Delete own message RPC
exec_sql("""
CREATE OR REPLACE FUNCTION app.app_student_delete_forum_message(
  p_message_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $fn$
DECLARE
  v_user_id uuid := auth.uid();
  v_msg_author uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT user_id INTO v_msg_author
  FROM app.online_course_forum_messages
  WHERE id = p_message_id;

  IF v_msg_author IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'message_not_found');
  END IF;

  IF v_msg_author != v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_owner');
  END IF;

  UPDATE app.online_course_forum_messages
  SET content = '[Message supprime]', is_deleted = true
  WHERE id = p_message_id;

  RETURN jsonb_build_object('success', true);
END;
$fn$;
""", "app_student_delete_forum_message")

# 3. Add is_deleted column to forum messages if not exists
exec_sql("""
ALTER TABLE app.online_course_forum_messages
ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false;
""", "add is_deleted column to forum_messages")

# 4. Add message_type to dm_messages if not exists (for soft-delete display)
exec_sql("""
DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'dm_messages' AND column_name = 'message_type'
  ) THEN
    ALTER TABLE app.dm_messages ADD COLUMN message_type text DEFAULT 'text';
  END IF;
END;
$do$;
""", "ensure message_type column on dm_messages")

print("\nDone!")
