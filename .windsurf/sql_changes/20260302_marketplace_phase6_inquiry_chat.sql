-- ========================================
-- ACADEMIA - MARKETPLACE (ALIBABA-LIKE)
-- PHASE 6: POLISH - INQUIRY CHAT (STUDENT + MERCHANT)
--
-- Objectifs:
-- - RPC pour lister les messages d'une inquiry (participants only)
-- - RPC pour permettre à l'étudiant (buyer) de répondre à une inquiry
-- ========================================

CREATE OR REPLACE FUNCTION public.app_list_opportunity_inquiry_messages(
  p_inquiry_id UUID,
  p_limit INTEGER DEFAULT 50,
  p_before TIMESTAMPTZ DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_ok BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT TRUE
  INTO v_ok
  FROM app.opportunity_inquiries i
  WHERE i.id = p_inquiry_id
    AND (i.buyer_id = v_user_id OR i.merchant_id = v_user_id);

  IF v_ok IS DISTINCT FROM TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'inquiry_not_found');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'messages', (
      SELECT COALESCE(
        jsonb_agg(to_jsonb(m) ORDER BY m.created_at ASC),
        '[]'::jsonb
      )
      FROM (
        SELECT id, inquiry_id, sender_id, content, created_at
        FROM app.opportunity_inquiry_messages
        WHERE inquiry_id = p_inquiry_id
          AND (p_before IS NULL OR created_at < p_before)
        ORDER BY created_at DESC
        LIMIT GREATEST(1, LEAST(p_limit, 200))
      ) m
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_list_opportunity_inquiry_messages(UUID, INTEGER, TIMESTAMPTZ) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_student_reply_opportunity_inquiry(
  p_inquiry_id UUID,
  p_message TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_ok BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_message IS NULL OR length(trim(p_message)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'message_required');
  END IF;

  SELECT TRUE
  INTO v_ok
  FROM app.opportunity_inquiries i
  WHERE i.id = p_inquiry_id
    AND i.buyer_id = v_user_id;

  IF v_ok IS DISTINCT FROM TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'inquiry_not_found');
  END IF;

  INSERT INTO app.opportunity_inquiry_messages(inquiry_id, sender_id, content, created_at)
  VALUES (p_inquiry_id, v_user_id, trim(p_message), now());

  UPDATE app.opportunity_inquiries
  SET
    status = 'open',
    last_message_at = now()
  WHERE id = p_inquiry_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_reply_opportunity_inquiry(UUID, TEXT) TO authenticated;
