-- Marketplace : paiement au checkout, statuts de commande, cle marchand.
-- Audit : academia_app/docs/marketplace_etat_des_lieux_2026-10-05.md (B1, B2, B4)
--
-- CONVENTION DE CLE MARCHAND (B4)
--   marketplace_listings.merchant_id  = auth.users.id du marchand (pas de FK)
--   marketplace_orders.merchant_id    = marketplace_merchants.id (FK)
--   marketplace_payments.merchant_id  = marketplace_merchants.id (FK)
--   Passage de l'un a l'autre : marketplace_merchants.owner_user_id.

-- ---------------------------------------------------------------------------
-- B1 : le checkout cree un marketplace_payments par commande et renvoie
--      marketplace_payment_id (attendu par l'ecran panier pour ouvrir LigdiCash).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_student_checkout_create_order_from_cart()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_cart_id uuid;
  v_currency text;
  v_orders jsonb := '[]'::jsonb;
  merchant_rec record;
  v_merchant_name text;
  v_slug text;
  v_rate numeric;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT id INTO v_cart_id
  FROM app.marketplace_carts
  WHERE user_id = v_user AND status = 'open'
  LIMIT 1;

  IF v_cart_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'cart_not_found');
  END IF;

  SELECT max(COALESCE(i.currency, l.currency))
  INTO v_currency
  FROM app.marketplace_cart_items i
  JOIN app.marketplace_listings l ON l.id = i.listing_id
  WHERE i.cart_id = v_cart_id;

  v_currency := COALESCE(v_currency, 'XOF');

  IF NOT EXISTS (SELECT 1 FROM app.marketplace_cart_items WHERE cart_id = v_cart_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'cart_empty');
  END IF;

  SELECT (r->>'percentage')::numeric
  INTO v_rate
  FROM jsonb_array_elements(app_resolve_revenue_split('marketplace_purchase')) r
  WHERE r->>'beneficiary_type' = 'platform'
  LIMIT 1;

  v_rate := COALESCE(v_rate, 0.10);

  FOR merchant_rec IN (
    SELECT
      l.merchant_id AS merchant_owner_user_id,
      COALESCE(sum(COALESCE(i.unit_price, l.price_from, 0) * i.quantity), 0) AS total_amount
    FROM app.marketplace_cart_items i
    JOIN app.marketplace_listings l ON l.id = i.listing_id
    WHERE i.cart_id = v_cart_id
    GROUP BY l.merchant_id
  ) LOOP
    DECLARE
      v_order_id uuid;
      v_merchant_id uuid;
      v_payment_id uuid;
      v_commission numeric;
    BEGIN
      SELECT m.id
      INTO v_merchant_id
      FROM app.marketplace_merchants m
      WHERE m.owner_user_id = merchant_rec.merchant_owner_user_id
        AND m.is_active = true
      LIMIT 1;

      IF v_merchant_id IS NULL THEN
        SELECT COALESCE(NULLIF(mp.display_name, ''), 'Marchand')
        INTO v_merchant_name
        FROM app.merchant_profiles mp
        WHERE mp.user_id = merchant_rec.merchant_owner_user_id
        LIMIT 1;

        v_slug := 'auto-' || replace(gen_random_uuid()::text, '-', '');

        INSERT INTO app.marketplace_merchants(
          owner_user_id,
          name,
          slug,
          status,
          is_active
        )
        VALUES (
          merchant_rec.merchant_owner_user_id,
          COALESCE(v_merchant_name, 'Marchand'),
          v_slug,
          'pending',
          true
        )
        RETURNING id INTO v_merchant_id;
      END IF;

      INSERT INTO app.marketplace_orders(student_id, merchant_id, status, total_amount, currency)
      VALUES (v_user, v_merchant_id, 'pending', merchant_rec.total_amount, v_currency)
      RETURNING id INTO v_order_id;

      INSERT INTO app.marketplace_order_items(order_id, product_id, quantity, unit_price, currency)
      SELECT
        v_order_id,
        i.listing_id,
        i.quantity,
        COALESCE(i.unit_price, l.price_from),
        COALESCE(i.currency, l.currency)
      FROM app.marketplace_cart_items i
      JOIN app.marketplace_listings l ON l.id = i.listing_id
      WHERE i.cart_id = v_cart_id
        AND l.merchant_id = merchant_rec.merchant_owner_user_id;

      IF merchant_rec.total_amount > 0 THEN
        v_commission := ROUND(merchant_rec.total_amount * v_rate, 2);

        INSERT INTO app.marketplace_payments(
          order_id, buyer_id, merchant_id,
          gross_amount, commission_rate, commission_amount, net_amount,
          currency, status
        )
        VALUES (
          v_order_id, v_user, v_merchant_id,
          merchant_rec.total_amount, v_rate, v_commission,
          merchant_rec.total_amount - v_commission,
          v_currency, 'pending'
        )
        RETURNING id INTO v_payment_id;
      END IF;

      v_orders := v_orders || jsonb_build_object(
        'order_id', v_order_id,
        'merchant_id', v_merchant_id,
        'marketplace_payment_id', v_payment_id,
        'total_amount', merchant_rec.total_amount,
        'currency', v_currency
      );
    END;
  END LOOP;

  UPDATE app.marketplace_carts
  SET status = 'checked_out',
      updated_at = now()
  WHERE id = v_cart_id;

  RETURN jsonb_build_object(
    'success', true,
    'orders', v_orders
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- B1 (suite) : payer une commande restee en attente (feuille fermee, echec,
--              commandes anterieures sans paiement). Reutilise le paiement
--              ouvert s'il existe, sinon le cree.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_student_ensure_marketplace_payment(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_order app.marketplace_orders%ROWTYPE;
  v_payment app.marketplace_payments%ROWTYPE;
  v_rate numeric;
  v_commission numeric;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_order
  FROM app.marketplace_orders
  WHERE id = p_order_id AND student_id = v_user
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_payable', 'status', v_order.status);
  END IF;

  IF COALESCE(v_order.total_amount, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  SELECT * INTO v_payment
  FROM app.marketplace_payments
  WHERE order_id = p_order_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND AND v_payment.status IN ('captured', 'paid', 'released') THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_paid');
  END IF;

  IF NOT FOUND OR v_payment.status NOT IN ('pending', 'processing') THEN
    SELECT (r->>'percentage')::numeric
    INTO v_rate
    FROM jsonb_array_elements(app_resolve_revenue_split('marketplace_purchase')) r
    WHERE r->>'beneficiary_type' = 'platform'
    LIMIT 1;

    v_rate := COALESCE(v_rate, 0.10);
    v_commission := ROUND(v_order.total_amount * v_rate, 2);

    INSERT INTO app.marketplace_payments(
      order_id, buyer_id, merchant_id,
      gross_amount, commission_rate, commission_amount, net_amount,
      currency, status
    )
    VALUES (
      v_order.id, v_user, v_order.merchant_id,
      v_order.total_amount, v_rate, v_commission,
      v_order.total_amount - v_commission,
      COALESCE(v_order.currency, 'XOF'), 'pending'
    )
    RETURNING * INTO v_payment;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'marketplace_payment_id', v_payment.id,
    'amount', v_payment.gross_amount,
    'currency', v_payment.currency
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.app_student_ensure_marketplace_payment(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_student_ensure_marketplace_payment(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Detail commande etudiant : ajoute le dernier paiement.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_student_get_marketplace_order_detail(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
    'payment', (
      SELECT jsonb_build_object(
        'id', p.id,
        'status', p.status,
        'gross_amount', p.gross_amount,
        'currency', p.currency
      )
      FROM app.marketplace_payments p
      WHERE p.order_id = p_order_id
      ORDER BY p.created_at DESC
      LIMIT 1
    ),
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
$function$;

-- ---------------------------------------------------------------------------
-- B2 : le marchand peut faire avancer ses commandes.
--   - filtre corrige : orders.merchant_id est un marketplace_merchants.id
--   - machine a etats :
--       pending   -> cancelled          (commande non payee refusee)
--       paid      -> accepted           (paid est pose par la confirmation LigdiCash)
--       confirmed -> accepted           (statut historique)
--       accepted  -> shipped
--       shipped   -> delivered
--     L'annulation d'une commande payee n'est pas ouverte au marchand :
--     aucun circuit de remboursement n'existe encore.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_merchant_update_marketplace_order_status(p_order_id uuid, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_role text;
  v_status text;
  v_current text;
  v_allowed text[];
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

  v_status := lower(btrim(p_status));
  IF v_status = 'canceled' THEN
    v_status := 'cancelled';
  END IF;

  SELECT o.status INTO v_current
  FROM app.marketplace_orders o
  WHERE o.id = p_order_id
    AND o.merchant_id IN (
      SELECT m.id FROM app.marketplace_merchants m WHERE m.owner_user_id = v_user
    )
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  IF v_current = v_status THEN
    RETURN jsonb_build_object('success', true, 'status', v_current, 'unchanged', true);
  END IF;

  v_allowed := CASE v_current
    WHEN 'pending'   THEN ARRAY['cancelled']
    WHEN 'paid'      THEN ARRAY['accepted']
    WHEN 'confirmed' THEN ARRAY['accepted']
    WHEN 'accepted'  THEN ARRAY['shipped']
    WHEN 'shipped'   THEN ARRAY['delivered']
    ELSE ARRAY[]::text[]
  END;

  IF NOT (v_status = ANY (v_allowed)) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_transition',
      'from', v_current,
      'to', v_status,
      'allowed', to_jsonb(v_allowed)
    );
  END IF;

  UPDATE app.marketplace_orders
  SET status = v_status,
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object('success', true, 'status', v_status);
END;
$function$;

-- ---------------------------------------------------------------------------
-- B4 : avis du marchand. listings.merchant_id est l'id utilisateur ;
--      l'ancienne jointure mm.id = l.merchant_id ne trouvait jamais rien.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_merchant_list_my_reviews(p_limit integer DEFAULT 30, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_reviews JSONB;
  v_total INT;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM app.marketplace_reviews r
  JOIN app.marketplace_listings l ON l.id = r.listing_id
  WHERE l.merchant_id = v_user AND r.is_active = true;

  SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO v_reviews
  FROM (
    SELECT r.id, r.listing_id, r.rating, r.title AS review_title, r.content,
           r.is_verified_purchase, r.seller_reply, r.seller_replied_at,
           r.created_at,
           l.title AS listing_title,
           s.full_name AS buyer_name, s.avatar_url AS buyer_avatar
    FROM app.marketplace_reviews r
    JOIN app.marketplace_listings l ON l.id = r.listing_id
    LEFT JOIN app.students s ON s.id = r.buyer_id
    WHERE l.merchant_id = v_user AND r.is_active = true
    ORDER BY r.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN jsonb_build_object(
    'success', true,
    'reviews', v_reviews,
    'total', v_total,
    'has_more', (p_offset + p_limit) < v_total
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- B4 : reponse du marchand a un avis (meme jointure erronee).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_merchant_reply_review(p_review_id uuid, p_reply text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM app.marketplace_reviews r
    JOIN app.marketplace_listings l ON l.id = r.listing_id
    WHERE r.id = p_review_id AND l.merchant_id = v_user
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  UPDATE app.marketplace_reviews
  SET seller_reply = p_reply, seller_replied_at = NOW(), updated_at = NOW()
  WHERE id = p_review_id;

  RETURN jsonb_build_object('success', true);
END;
$function$;
