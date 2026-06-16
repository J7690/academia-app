#!/usr/bin/env python3
"""Deploy admin audit log table + RPC for tracking moderation actions."""
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

# 1. Create admin_audit_log table + indexes
exec_sql("""
CREATE TABLE IF NOT EXISTS app.admin_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL,
  action_type text NOT NULL,
  target_type text,
  target_id text,
  target_user_id uuid,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
)
""", "create admin_audit_log table")

exec_sql("CREATE INDEX IF NOT EXISTS idx_audit_log_admin ON app.admin_audit_log(admin_id)", "idx admin")
exec_sql("CREATE INDEX IF NOT EXISTS idx_audit_log_action ON app.admin_audit_log(action_type)", "idx action")
exec_sql("CREATE INDEX IF NOT EXISTS idx_audit_log_created ON app.admin_audit_log(created_at DESC)", "idx created")

# 2. RPC to log admin action
exec_sql("""
CREATE OR REPLACE FUNCTION app.app_admin_log_action(
  p_action_type text,
  p_target_type text DEFAULT NULL,
  p_target_id text DEFAULT NULL,
  p_target_user_id uuid DEFAULT NULL,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $fn$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  INSERT INTO app.admin_audit_log (admin_id, action_type, target_type, target_id, target_user_id, details)
  VALUES (v_admin_id, p_action_type, p_target_type, p_target_id, p_target_user_id, p_details);
  RETURN jsonb_build_object('success', true);
END;
$fn$;
""", "app_admin_log_action RPC")

# 3. RPC to list audit log (admin only)
exec_sql("""
CREATE OR REPLACE FUNCTION app.app_admin_list_audit_log(
  p_limit int DEFAULT 50,
  p_action_type text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $fn$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t))
  INTO v_result
  FROM (
    SELECT al.id, al.action_type, al.target_type, al.target_id,
           al.target_user_id, al.details, al.created_at,
           al.admin_id
    FROM app.admin_audit_log al
    WHERE (p_action_type IS NULL OR al.action_type = p_action_type)
    ORDER BY al.created_at DESC
    LIMIT p_limit
  ) t;
  RETURN jsonb_build_object('success', true, 'logs', COALESCE(v_result, '[]'::jsonb));
END;
$fn$;
""", "app_admin_list_audit_log RPC")

# 4. Update existing moderation RPCs to log actions automatically
# Patch resolve_content_report to also log
exec_sql("""
CREATE OR REPLACE FUNCTION app.app_admin_resolve_content_report(
  p_report_id uuid,
  p_status text,
  p_admin_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $fn$
DECLARE
  v_admin_id uuid := auth.uid();
  v_report record;
BEGIN
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_report FROM app.content_reports WHERE id = p_report_id;
  IF v_report IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'report_not_found');
  END IF;

  UPDATE app.content_reports
  SET status = p_status, resolved_by = v_admin_id, resolved_at = now(), admin_notes = p_admin_notes
  WHERE id = p_report_id;

  INSERT INTO app.admin_audit_log (admin_id, action_type, target_type, target_id, target_user_id, details)
  VALUES (v_admin_id, 'resolve_report', v_report.content_type, v_report.content_id, v_report.target_user_id,
          jsonb_build_object('report_id', p_report_id, 'status', p_status, 'reason', v_report.reason));

  RETURN jsonb_build_object('success', true);
END;
$fn$;
""", "patch app_admin_resolve_content_report with audit log")

# 5. Patch suspend_user to also log
exec_sql("""
CREATE OR REPLACE FUNCTION app.app_admin_suspend_user(
  p_user_id uuid,
  p_reason text,
  p_duration_hours int DEFAULT 24
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $fn$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  UPDATE app.user_admin_status
  SET is_suspended = true, suspension_reason = p_reason,
      suspended_until = now() + (p_duration_hours || ' hours')::interval,
      suspended_by = v_admin_id
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    INSERT INTO app.user_admin_status (user_id, is_suspended, suspension_reason, suspended_until, suspended_by)
    VALUES (p_user_id, true, p_reason, now() + (p_duration_hours || ' hours')::interval, v_admin_id);
  END IF;

  INSERT INTO app.admin_audit_log (admin_id, action_type, target_type, target_id, target_user_id, details)
  VALUES (v_admin_id, 'suspend_user', 'user', p_user_id::text, p_user_id,
          jsonb_build_object('reason', p_reason, 'duration_hours', p_duration_hours));

  RETURN jsonb_build_object('success', true);
END;
$fn$;
""", "patch app_admin_suspend_user with audit log")

print("\nDone!")
