-- ========================================
-- ACADEMIA - MARKETPLACE (ALIBABA-LIKE)
-- PHASE 7: HARDENING
-- - Notifications push: new inquiry messages + admin review decision
-- - Merchant profile: public fetch for buyer
-- ========================================

-- 1) RPC: fetch merchant profile (public but only if active+verified)
CREATE OR REPLACE FUNCTION public.app_get_public_merchant_profile(
  p_merchant_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF p_merchant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_id_required');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'profile', (
      SELECT to_jsonb(mp)
      FROM app.merchant_profiles mp
      WHERE mp.user_id = p_merchant_id
        AND mp.is_active = TRUE
        AND mp.is_verified = TRUE
      LIMIT 1
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_get_public_merchant_profile(UUID) TO anon, authenticated;

-- 2) Helper: enqueue notification event
CREATE OR REPLACE FUNCTION app.fn_enqueue_notification_event(
  p_user_id UUID,
  p_domain TEXT,
  p_event_type TEXT,
  p_payload JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO app.notification_events(user_id, domain, event_type, payload, created_at, processed_at, attempt_count, last_error)
  VALUES (
    p_user_id,
    p_domain,
    p_event_type,
    COALESCE(p_payload, '{}'::jsonb),
    now(),
    NULL,
    0,
    NULL
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app.fn_enqueue_notification_event(UUID, TEXT, TEXT, JSONB) TO service_role;

-- 3) Trigger: on new inquiry message -> notify other participant
CREATE OR REPLACE FUNCTION app.trg_notify_inquiry_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_buyer UUID;
  v_merchant UUID;
  v_target UUID;
BEGIN
  SELECT buyer_id, merchant_id
  INTO v_buyer, v_merchant
  FROM app.opportunity_inquiries
  WHERE id = NEW.inquiry_id;

  IF v_buyer IS NULL OR v_merchant IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.sender_id = v_buyer THEN
    v_target := v_merchant;
  ELSE
    v_target := v_buyer;
  END IF;

  PERFORM app.fn_enqueue_notification_event(
    v_target,
    'marketplace_inquiries',
    'message',
    jsonb_build_object(
      'inquiry_id', NEW.inquiry_id,
      'sender_id', NEW.sender_id
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_inquiry_message ON app.opportunity_inquiry_messages;
CREATE TRIGGER trg_notify_inquiry_message
AFTER INSERT ON app.opportunity_inquiry_messages
FOR EACH ROW
EXECUTE FUNCTION app.trg_notify_inquiry_message();

-- 4) Trigger: when admin reviews opportunity -> notify merchant
CREATE OR REPLACE FUNCTION app.trg_notify_opportunity_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_merchant UUID;
BEGIN
  IF NEW.merchant_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF OLD.review_status IS DISTINCT FROM NEW.review_status
     AND NEW.review_status IN ('approved', 'rejected') THEN
    v_merchant := NEW.merchant_id;

    PERFORM app.fn_enqueue_notification_event(
      v_merchant,
      'marketplace_opportunities',
      'review',
      jsonb_build_object(
        'opportunity_id', NEW.id,
        'review_status', NEW.review_status,
        'review_reason', NEW.review_reason
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_opportunity_review ON app.opportunities;
CREATE TRIGGER trg_notify_opportunity_review
AFTER UPDATE OF review_status ON app.opportunities
FOR EACH ROW
EXECUTE FUNCTION app.trg_notify_opportunity_review();
