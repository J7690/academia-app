#!/usr/bin/env python3
"""
Correction du RPC app_student_request_account_deletion:
- Remplacer 'self_delete_request' par 'delete' (valeur autorisee par CHECK constraint)
"""
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=60)
    return r.json()

# Recreate the function with fixed action value
res = rpc_sql("""
CREATE OR REPLACE FUNCTION public.app_student_request_account_deletion()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public, auth
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_now TIMESTAMPTZ := NOW();
  v_purge_at TIMESTAMPTZ := v_now + INTERVAL '60 days';
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role IS NOT NULL AND v_role NOT IN ('student', 'commercial', 'merchant') THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'error', 'role_not_eligible',
      'message', 'Contactez le support pour supprimer ce type de compte.'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM app.user_admin_status
    WHERE user_id = v_user_id AND is_deleted = TRUE
  ) THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'already_pending_deletion');
  END IF;

  INSERT INTO app.user_admin_status (
    user_id,
    is_suspended, suspended_reason, suspended_at,
    is_deleted, deleted_reason, deleted_at,
    deletion_requested_at, purge_due_at, deletion_method,
    updated_at
  ) VALUES (
    v_user_id,
    TRUE, 'account_deletion_requested', v_now,
    TRUE, 'user_self_service_deletion', v_now,
    v_now, v_purge_at, 'self_service',
    v_now
  )
  ON CONFLICT (user_id) DO UPDATE SET
    is_suspended = TRUE,
    suspended_reason = 'account_deletion_requested',
    suspended_at = v_now,
    is_deleted = TRUE,
    deleted_reason = 'user_self_service_deletion',
    deleted_at = v_now,
    deletion_requested_at = v_now,
    purge_due_at = v_purge_at,
    deletion_method = 'self_service',
    updated_at = v_now;

  UPDATE auth.users
  SET banned_until = '2099-12-31 23:59:59+00'::TIMESTAMPTZ,
      updated_at = v_now
  WHERE id = v_user_id;

  DELETE FROM auth.sessions WHERE user_id = v_user_id;
  DELETE FROM auth.refresh_tokens WHERE session_id IN (
    SELECT id FROM auth.sessions WHERE user_id = v_user_id
  );

  UPDATE app.user_device_tokens
  SET is_active = FALSE
  WHERE user_id = v_user_id;

  INSERT INTO app.admin_user_action_logs (
    performed_by, target_user, action, reason, meta
  ) VALUES (
    v_user_id, v_user_id, 'delete',
    'user_self_service_deletion',
    JSONB_BUILD_OBJECT(
      'method', 'self_service',
      'requested_at', v_now,
      'purge_due_at', v_purge_at
    )
  );

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'message', 'Votre demande de suppression a ete prise en compte.',
    'purge_due_at', v_purge_at
  );
END;
$$;
""")
print(json.dumps(res, indent=2))
