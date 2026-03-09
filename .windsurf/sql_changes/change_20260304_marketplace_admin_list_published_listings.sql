-- Admin: list published/approved marketplace listings

CREATE OR REPLACE FUNCTION public.app_admin_list_published_marketplace_listings(
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_role text;
  v_total integer;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM app.marketplace_listings l
  WHERE l.is_active = true
    AND l.review_status = 'approved'
    AND (l.status = 'published' OR l.status = 'active');

  RETURN jsonb_build_object(
    'success', true,
    'total', v_total,
    'items', (
      SELECT COALESCE(
        jsonb_agg(to_jsonb(x) ORDER BY x.updated_at DESC),
        '[]'::jsonb
      )
      FROM (
        SELECT l.*
        FROM app.marketplace_listings l
        WHERE l.is_active = true
          AND l.review_status = 'approved'
          AND (l.status = 'published' OR l.status = 'active')
        ORDER BY l.updated_at DESC
        LIMIT GREATEST(1, LEAST(p_limit, 200))
        OFFSET GREATEST(0, p_offset)
      ) x
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_list_published_marketplace_listings(integer, integer) TO authenticated;
