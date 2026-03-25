-- ============================================================================
-- Migration: Account Deletion Compliance (Google Play + App Store)
-- Date: 2026-03-16
-- Description:
--   1. Add pending deletion columns to user_admin_status
--   2. Create self-service RPC app_student_request_account_deletion
--   3. Create purge RPC app_admin_purge_deleted_accounts (called by pg_cron)
--   4. Schedule daily purge cron job
-- ============================================================================

-- ============================================================================
-- 1. ALTER user_admin_status: add deletion workflow columns
-- ============================================================================
ALTER TABLE app.user_admin_status
  ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS purge_due_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deletion_method TEXT DEFAULT 'self_service';

-- ============================================================================
-- 2. RPC: Self-service account deletion request (student calls this)
-- ============================================================================
CREATE OR REPLACE FUNCTION app.app_student_request_account_deletion()
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
  -- Must be authenticated
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Get role
  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  -- Only students can self-delete (admins/university use admin RPC)
  IF v_role IS NOT NULL AND v_role NOT IN ('student', 'commercial', 'merchant') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'role_not_eligible',
      'message', 'Contactez le support pour supprimer ce type de compte.');
  END IF;

  -- Check if already pending deletion
  IF EXISTS (
    SELECT 1 FROM app.user_admin_status
    WHERE user_id = v_user_id AND is_deleted = TRUE
  ) THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'already_pending_deletion');
  END IF;

  -- =============================================
  -- Mark account as deleted / pending purge
  -- =============================================
  INSERT INTO app.user_admin_status (
    user_id, is_suspended, suspended_reason, suspended_at,
    is_deleted, deleted_reason, deleted_at,
    deletion_requested_at, purge_due_at, deletion_method,
    updated_at
  ) VALUES (
    v_user_id, TRUE, 'account_deletion_requested', v_now,
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

  -- =============================================
  -- Block reconnection: ban until far future
  -- =============================================
  UPDATE auth.users
  SET banned_until = '2099-12-31 23:59:59+00'::TIMESTAMPTZ,
      updated_at = v_now
  WHERE id = v_user_id;

  -- =============================================
  -- Invalidate all active sessions
  -- =============================================
  DELETE FROM auth.sessions WHERE user_id = v_user_id;
  DELETE FROM auth.refresh_tokens WHERE session_id IN (
    SELECT id FROM auth.sessions WHERE user_id = v_user_id
  );

  -- =============================================
  -- Deactivate FCM tokens
  -- =============================================
  UPDATE app.user_device_tokens
  SET is_active = FALSE
  WHERE user_id = v_user_id;

  -- =============================================
  -- Log the action
  -- =============================================
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
    'message', 'Votre demande de suppression a été prise en compte.',
    'purge_due_at', v_purge_at
  );
END;
$$;

-- Grant to authenticated users
GRANT EXECUTE ON FUNCTION app.app_student_request_account_deletion() TO authenticated;

-- ============================================================================
-- 3. RPC: Purge deleted accounts (called by pg_cron daily)
-- ============================================================================
CREATE OR REPLACE FUNCTION app.app_admin_purge_deleted_accounts()
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
      AND deletion_method IS NOT NULL
  LOOP
    BEGIN
      -- =============================================
      -- 1. Delete from NO ACTION FK tables first
      -- =============================================
      -- Direct messages
      DELETE FROM app.direct_message_read_states
        WHERE user_id = v_user.user_id;
      DELETE FROM app.direct_messages
        WHERE sender_id = v_user.user_id;
      DELETE FROM app.direct_conversations
        WHERE user_a = v_user.user_id OR user_b = v_user.user_id;

      -- Support
      DELETE FROM app.support_read_states
        WHERE user_id = v_user.user_id;
      DELETE FROM app.support_messages
        WHERE conversation_id IN (
          SELECT id FROM app.support_conversations
          WHERE requester_user_id = v_user.user_id
        );
      DELETE FROM app.support_conversations
        WHERE requester_user_id = v_user.user_id;

      -- Commercial
      DELETE FROM app.commercial_milestone_claims
        WHERE commercial_user_id = v_user.user_id;

      -- Prep concours (NO ACTION tables)
      DELETE FROM app.prep_ai_messages
        WHERE conversation_id IN (
          SELECT id FROM app.prep_ai_conversations
          WHERE student_id = v_user.user_id
        );
      DELETE FROM app.prep_ai_conversations
        WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_ai_corrections
        WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_assignment_submissions
        WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_flashcard_progress
        WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_live_participants
        WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_psychotech_profiles
        WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_psychotech_results
        WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_quiz_attempts
        WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_student_badges
        WHERE student_id = v_user.user_id;
      DELETE FROM app.prep_student_progress
        WHERE student_id = v_user.user_id;

      -- TD (NO ACTION tables)
      DELETE FROM app.td_ai_messages
        WHERE conversation_id IN (
          SELECT id FROM app.td_ai_conversations
          WHERE student_id = v_user.user_id
        );
      DELETE FROM app.td_ai_conversations
        WHERE student_id = v_user.user_id;
      DELETE FROM app.td_flashcard_progress
        WHERE student_id = v_user.user_id;
      DELETE FROM app.td_quiz_attempts
        WHERE student_id = v_user.user_id;
      DELETE FROM app.td_student_badges
        WHERE student_id = v_user.user_id;
      DELETE FROM app.td_student_progress
        WHERE student_id = v_user.user_id;
      DELETE FROM app.td_daily_goals
        WHERE student_id = v_user.user_id;
      DELETE FROM app.td_streaks
        WHERE student_id = v_user.user_id;
      DELETE FROM app.td_xp_log
        WHERE student_id = v_user.user_id;

      -- Video assets owned by user
      DELETE FROM app.video_comments WHERE user_id = v_user.user_id;
      DELETE FROM app.video_favorites WHERE user_id = v_user.user_id;
      DELETE FROM app.video_likes WHERE user_id = v_user.user_id;
      DELETE FROM app.video_reports WHERE user_id = v_user.user_id;

      -- Marketplace bookmarks & cart
      DELETE FROM app.marketplace_listing_bookmarks
        WHERE user_id = v_user.user_id;
      DELETE FROM app.marketplace_cart_items
        WHERE cart_id IN (
          SELECT id FROM app.marketplace_carts WHERE user_id = v_user.user_id
        );
      DELETE FROM app.marketplace_carts
        WHERE user_id = v_user.user_id;

      -- Opportunity interactions
      DELETE FROM app.opportunity_bookmarks WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_comments WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_reactions WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_views WHERE user_id = v_user.user_id;
      DELETE FROM app.opportunity_inquiry_messages
        WHERE sender_id = v_user.user_id;

      -- =============================================
      -- 2. Anonymize PII in students table
      --    (CASCADE will delete child rows)
      -- =============================================
      UPDATE app.students SET
        full_name = 'Utilisateur supprimé',
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
      WHERE id = v_user_id;

      -- =============================================
      -- 3. Mark auth.users as soft-deleted
      -- =============================================
      UPDATE auth.users SET
        email = 'deleted_' || v_user.user_id::TEXT || '@deleted.academia.app',
        encrypted_password = '',
        raw_user_meta_data = JSONB_BUILD_OBJECT('role', 'deleted', 'purged_at', NOW()::TEXT),
        phone = NULL,
        deleted_at = NOW(),
        updated_at = NOW()
      WHERE id = v_user.user_id;

      -- =============================================
      -- 4. Update purge status
      -- =============================================
      UPDATE app.user_admin_status SET
        deletion_method = 'purged',
        updated_at = NOW()
      WHERE user_id = v_user.user_id;

      -- Log
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

-- ============================================================================
-- 4. Schedule daily purge cron job (3 AM UTC)
-- ============================================================================
SELECT cron.schedule(
  'purge_deleted_accounts',
  '0 3 * * *',
  $$SELECT app.app_admin_purge_deleted_accounts()$$
);

-- ============================================================================
-- 5. RPC: Check if account is pending deletion (for auth_wrapper)
-- ============================================================================
CREATE OR REPLACE FUNCTION app.app_check_account_status()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public, auth
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_status RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('active', FALSE, 'reason', 'not_authenticated');
  END IF;

  SELECT is_deleted, is_suspended, deleted_at, purge_due_at, deletion_method
  INTO v_status
  FROM app.user_admin_status
  WHERE user_id = v_user_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('active', TRUE);
  END IF;

  IF v_status.is_deleted THEN
    RETURN JSONB_BUILD_OBJECT(
      'active', FALSE,
      'reason', 'account_deleted',
      'deleted_at', v_status.deleted_at,
      'purge_due_at', v_status.purge_due_at
    );
  END IF;

  IF v_status.is_suspended THEN
    RETURN JSONB_BUILD_OBJECT(
      'active', FALSE,
      'reason', 'account_suspended'
    );
  END IF;

  RETURN JSONB_BUILD_OBJECT('active', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app.app_check_account_status() TO authenticated;
