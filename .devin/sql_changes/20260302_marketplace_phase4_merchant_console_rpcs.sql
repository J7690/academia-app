-- ========================================
-- ACADEMIA - MARKETPLACE (ALIBABA-LIKE)
-- PHASE 4: MERCHANT CONSOLE - RPC COMPLEMENTS
--
-- Objectifs:
-- - Permettre au marchand de lister ses propres annonces (draft/pending/rejected/approved)
--   sans dépendre d'un SELECT direct sur app.opportunities (RLS public only).
-- ========================================

CREATE OR REPLACE FUNCTION public.app_merchant_list_my_opportunities(
  p_review_status TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 30,
  p_offset INTEGER DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'opportunities', (
      SELECT COALESCE(jsonb_agg(to_jsonb(o) ORDER BY o.updated_at DESC), '[]'::jsonb)
      FROM app.opportunities o
      WHERE o.merchant_id = v_user_id
        AND (p_review_status IS NULL OR o.review_status = p_review_status)
      LIMIT GREATEST(1, LEAST(p_limit, 100))
      OFFSET GREATEST(0, p_offset)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_list_my_opportunities(TEXT, INTEGER, INTEGER) TO authenticated;
