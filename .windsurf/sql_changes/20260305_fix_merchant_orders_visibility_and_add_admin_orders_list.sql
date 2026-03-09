-- Fix merchant order visibility: marketplace_orders.merchant_id references app.marketplace_merchants.id
-- but merchant RPCs were filtering with auth.uid() (user id).

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
  v_merchant_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  SELECT m.id
  INTO v_merchant_id
  FROM app.marketplace_merchants m
  WHERE m.owner_user_id = v_user
    AND m.is_active = true
  ORDER BY m.created_at
  LIMIT 1;

  IF v_merchant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_not_found');
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
            'delivery_mode', o.delivery_mode,
            'shipping_address', o.shipping_address,
            'student_notes', o.student_notes,
            'created_at', o.created_at,
            'updated_at', o.updated_at
          )
          ORDER BY o.created_at DESC
        ),
        '[]'::jsonb
      )
      FROM app.marketplace_orders o
      WHERE o.merchant_id = v_merchant_id
        AND (p_status IS NULL OR o.status = p_status)
      LIMIT GREATEST(1, LEAST(p_limit, 200))
      OFFSET GREATEST(0, p_offset)
    )
  );
END;
$$;


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
  v_merchant_id uuid;
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

  SELECT m.id
  INTO v_merchant_id
  FROM app.marketplace_merchants m
  WHERE m.owner_user_id = v_user
    AND m.is_active = true
  ORDER BY m.created_at
  LIMIT 1;

  IF v_merchant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_not_found');
  END IF;

  SELECT * INTO v_order
  FROM app.marketplace_orders o
  WHERE o.id = p_order_id
    AND o.merchant_id = v_merchant_id
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


-- Admin: list marketplace orders (control tower baseline)
CREATE OR REPLACE FUNCTION public.app_admin_list_marketplace_orders(
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
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
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
            'merchant_name', m.name,
            'status', o.status,
            'total_amount', o.total_amount,
            'currency', o.currency,
            'delivery_mode', o.delivery_mode,
            'shipping_address', o.shipping_address,
            'student_notes', o.student_notes,
            'created_at', o.created_at,
            'updated_at', o.updated_at
          )
          ORDER BY o.created_at DESC
        ),
        '[]'::jsonb
      )
      FROM app.marketplace_orders o
      LEFT JOIN app.marketplace_merchants m ON m.id = o.merchant_id
      WHERE (p_status IS NULL OR o.status = p_status)
      LIMIT GREATEST(1, LEAST(p_limit, 200))
      OFFSET GREATEST(0, p_offset)
    )
  );
END;
$$;
