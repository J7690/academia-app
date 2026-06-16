#!/usr/bin/env python3
"""
Execution controlee du script change_20260604_account_deletion_final.sql
via admin_execute_sql RPC
"""
import requests, json, time

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
headers = {'apikey': key, 'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'}

results = []

def exec_sql(label, sql):
    print(f"\n>>> EXECUTING: {label}")
    try:
        r = requests.post(
            f'{url}/rest/v1/rpc/admin_execute_sql',
            headers=headers,
            json={'p_sql': sql},
            timeout=60
        )
        data = r.json()
        status = data.get('ok', False)
        print(f"    Status: {'OK' if status else 'FAIL'} | {json.dumps(data, indent=2)[:300]}")
        results.append({'label': label, 'status': 'OK' if status else 'FAIL', 'response': data})
        return status, data
    except Exception as e:
        print(f"    ERROR: {e}")
        results.append({'label': label, 'status': 'ERROR', 'error': str(e)})
        return False, str(e)

# Bloc 1: ALTER TABLE
exec_sql("ALTER TABLE add columns", """
ALTER TABLE app.user_admin_status
  ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS purge_due_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deletion_method TEXT;
""")

# Bloc 2: CREATE FUNCTION public.app_student_request_account_deletion
exec_sql("CREATE FUNCTION public.app_student_request_account_deletion", """
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
    v_user_id, v_user_id, 'self_delete_request',
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

# Bloc 3: GRANT
exec_sql("GRANT EXECUTE ON public.app_student_request_account_deletion", """
GRANT EXECUTE ON FUNCTION public.app_student_request_account_deletion() TO authenticated;
""")

# Bloc 4: CREATE FUNCTION public.app_admin_purge_deleted_accounts
exec_sql("CREATE FUNCTION public.app_admin_purge_deleted_accounts", """
CREATE OR REPLACE FUNCTION public.app_admin_purge_deleted_accounts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public, auth
AS $$
DECLARE
  v_user RECORD;
  v_count INTEGER := 0;
  v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
  FOR v_user IN
    SELECT user_id, purge_due_at
    FROM app.user_admin_status
    WHERE is_deleted = TRUE
      AND purge_due_at IS NOT NULL
      AND purge_due_at <= NOW()
      AND deletion_method = 'self_service'
  LOOP
    BEGIN
      DELETE FROM app.direct_message_read_states WHERE user_id = v_user.user_id;
      DELETE FROM app.direct_messages WHERE sender_id = v_user.user_id;
      DELETE FROM app.direct_conversations
        WHERE user_a = v_user.user_id OR user_b = v_user.user_id;

      DELETE FROM app.support_read_states WHERE user_id = v_user.user_id;
      DELETE FROM app.support_messages
        WHERE conversation_id IN (
          SELECT id FROM app.support_conversations
          WHERE requester_user_id = v_user.user_id
        );
      DELETE FROM app.support_conversations
        WHERE requester_user_id = v_user.user_id;

      DELETE FROM app.commercial_milestone_claims
        WHERE commercial_user_id = v_user.user_id;

      DELETE FROM app.prep_ai_messages
        WHERE conversation_id IN (
          SELECT id FROM app.prep_ai_conversations
          WHERE student_id = v_user.user_id
        );
      DELETE FROM app.prep_ai_conversations WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_ai_corrections WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_assignment_submissions WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_flashcard_progress WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_live_participants WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_psychotech_profiles WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_psychotech_results WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_quiz_attempts WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_student_badges WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_student_progress WHERE student_id = v_user.user_id;

      DELETE FROM app.td_ai_messages
        WHERE conversation_id IN (
          SELECT id FROM app.td_ai_conversations WHERE student_id = v_user.user_id
        );
      DELETE FROM app.td_ai_conversations WHERE student_id = v_user.user_id;
      DELETE FROM app.td_flashcard_progress WHERE student_id = v_user.user_id;
      DELETE FROM app.td_quiz_attempts WHERE student_id = v_user.user_id;
      DELETE FROM app.td_student_badges WHERE student_id = v_user.user_id;
      DELETE FROM app.td_student_progress WHERE student_id = v_user.user_id;
      DELETE FROM app.td_daily_goals WHERE student_id = v_user.user_id;
      DELETE FROM app.td_streaks WHERE student_id = v_user.user_id;
      DELETE FROM app.td_xp_log WHERE student_id = v_user.user_id;

      DELETE FROM app.video_comments WHERE user_id = v_user.user_id;
      DELETE FROM app.video_favorites WHERE user_id = v_user.user_id;
      DELETE FROM app.video_likes WHERE user_id = v_user.user_id;
      DELETE FROM app.video_reports WHERE user_id = v_user.user_id;

      DELETE FROM app.marketplace_listing_bookmarks WHERE user_id = v_user.user_id;
      DELETE FROM app.marketplace_cart_items
        WHERE cart_id IN (
          SELECT id FROM app.marketplace_carts WHERE user_id = v_user.user_id
        );
      DELETE FROM app.marketplace_carts WHERE user_id = v_user.user_id;

      DELETE FROM app.opportunity_bookmarks WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_comments WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_reactions WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_views WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_inquiry_messages WHERE sender_id = v_user.user_id;

      UPDATE app.students SET
        full_name = 'Utilisateur supprime',
        phone = NULL,
        country = NULL,
        city = NULL,
        date_of_birth = NULL,
        avatar_url = NULL,
        bio = NULL,
        website_url = NULL,
        timezone = NULL,
        geo_latitude = NULL,
        geo_longitude = NULL,
        bepc_year = NULL,
        bepc_institution = NULL,
        bepc_country = NULL,
        bepc_mention = NULL,
        bac_year = NULL,
        bac_series = NULL,
        bac_mention = NULL,
        bac_institution = NULL,
        bac_country = NULL,
        study_project_text = NULL,
        updated_at = NOW()
      WHERE id = v_user.user_id;

      UPDATE auth.users SET
        email = 'deleted_' || v_user.user_id::TEXT || '@deleted.academia.app',
        encrypted_password = '',
        raw_user_meta_data = JSONB_BUILD_OBJECT('role', 'deleted', 'purged_at', NOW()::TEXT),
        phone = NULL,
        deleted_at = NOW(),
        updated_at = NOW()
      WHERE id = v_user.user_id;

      UPDATE app.user_admin_status SET
        deletion_method = 'purged',
        updated_at = NOW()
      WHERE user_id = v_user.user_id;

      INSERT INTO app.admin_user_action_logs (
        performed_by, target_user, action, reason, meta
      ) VALUES (
        v_user.user_id, v_user.user_id, 'account_purged',
        'automatic_purge_60_days',
        JSONB_BUILD_OBJECT('purged_at', NOW())
      );

      v_count := v_count + 1;

    EXCEPTION WHEN OTHERS THEN
      v_errors := array_append(v_errors,
        v_user.user_id::TEXT || ': ' || SQLERRM);
    END;
  END LOOP;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'purged_count', v_count,
    'errors', v_errors
  );
END;
$$;
""")

# Bloc 5: cron.unschedule
exec_sql("cron.unschedule purge_deleted_accounts", """
SELECT cron.unschedule('purge_deleted_accounts');
""")

# Bloc 6: cron.schedule
exec_sql("cron.schedule purge_deleted_accounts", """
SELECT cron.schedule(
  'purge_deleted_accounts',
  '0 3 * * *',
  $$SELECT public.app_admin_purge_deleted_accounts()$$
);
""")

# Summary
print("\n" + "="*60)
print("SUMMARY")
print("="*60)
for r in results:
    print(f"  {r['status']:6s} | {r['label']}")

with open('exec_correction_results.json', 'w', encoding='utf-8') as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print("\nResults saved to exec_correction_results.json")
