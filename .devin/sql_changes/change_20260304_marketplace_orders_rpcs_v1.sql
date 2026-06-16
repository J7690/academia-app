-- Marketplace Orders: Student + Merchant RPCs

-- 1) Student: list my orders
CREATE OR REPLACE FUNCTION public.app_student_list_my_marketplace_orders(
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', o.id,
            'merchant_id', o.merchant_id,
            'status', o.status,
            'total_amount', o.total_amount,
            'currency', o.currency,
            'created_at', o.created_at,
            'updated_at', o.updated_at
          )
          ORDER BY o.created_at DESC
        ),
        '[]'::jsonb
      )
      FROM app.marketplace_orders o
      WHERE o.student_id = v_user
      LIMIT GREATEST(1, LEAST(p_limit, 200))
      OFFSET GREATEST(0, p_offset)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_my_marketplace_orders(integer, integer) TO authenticated;

-- 2) Student: get order detail (with items)
CREATE OR REPLACE FUNCTION public.app_student_get_marketplace_order_detail(
  p_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_order record;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_order_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_order_id');
  END IF;

  SELECT * INTO v_order
  FROM app.marketplace_orders o
  WHERE o.id = p_order_id
    AND o.student_id = v_user
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order', to_jsonb(v_order),
    'items', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', i.id,
            'product_id', i.product_id,
            'quantity', i.quantity,
            'unit_price', i.unit_price,
            'currency', i.currency,
            'title', l.title
          )
          ORDER BY i.id
        ),
        '[]'::jsonb
      )
      FROM app.marketplace_order_items i
      JOIN app.marketplace_listings l ON l.id = i.product_id
      WHERE i.order_id = p_order_id
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_get_marketplace_order_detail(uuid) TO authenticated;

-- 3) Merchant: list my orders
CREATE OR REPLACE FUNCTION public.app_merchant_list_my_marketplace_orders(
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0,
  p_status text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_role text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', o.id,
            'student_id', o.student_id,
            'merchant_id', o.merchant_id,
            'status', o.status,
            'total_amount', o.total_amount,
            'currency', o.currency,
            'created_at', o.created_at,
            'updated_at', o.updated_at
          )
          ORDER BY o.created_at DESC
        ),
        '[]'::jsonb
      )
      FROM app.marketplace_orders o
      WHERE o.merchant_id = v_user
        AND (p_status IS NULL OR o.status = p_status)
      LIMIT GREATEST(1, LEAST(p_limit, 200))
      OFFSET GREATEST(0, p_offset)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_list_my_marketplace_orders(integer, integer, text) TO authenticated;

-- 4) Merchant: get order detail (with items)
CREATE OR REPLACE FUNCTION public.app_merchant_get_marketplace_order_detail(
  p_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_role text;
  v_order record;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_order_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_order_id');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  SELECT * INTO v_order
  FROM app.marketplace_orders o
  WHERE o.id = p_order_id
    AND o.merchant_id = v_user
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order', to_jsonb(v_order),
    'items', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', i.id,
            'product_id', i.product_id,
            'quantity', i.quantity,
            'unit_price', i.unit_price,
            'currency', i.currency,
            'title', l.title
          )
          ORDER BY i.id
        ),
        '[]'::jsonb
      )
      FROM app.marketplace_order_items i
      JOIN app.marketplace_listings l ON l.id = i.product_id
      WHERE i.order_id = p_order_id
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_get_marketplace_order_detail(uuid) TO authenticated;

-- 5) Merchant: update status
CREATE OR REPLACE FUNCTION public.app_merchant_update_marketplace_order_status(
  p_order_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_role text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_order_id IS NULL OR p_status IS NULL OR btrim(p_status) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_params');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  UPDATE app.marketplace_orders
  SET status = p_status,
      updated_at = now()
  WHERE id = p_order_id
    AND merchant_id = v_user;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_update_marketplace_order_status(uuid, text) TO authenticated;
