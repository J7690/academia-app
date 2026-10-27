-- Marketplace (27/10/2026) : modération des avis côté admin.
--
-- Trouvé en préparant l'écran : `app_admin_moderate_review` n'avait AUCUN
-- contrôle d'identité et s'exécutait pour `anon` — n'importe qui pouvait
-- masquer (ou rétablir) un avis et faire varier la note d'une annonce. Garde
-- `app.est_admin()` ajoutée (même garde que `app_admin_list_marketplace_payments`
-- depuis l'audit B4 du 03/09), accès anonyme retiré.
--
-- `app_admin_list_marketplace_reviews` : la liste qui manquait à l'écran
-- (annonce, acheteur, marchand, note, texte, réponse, visibilité).

CREATE OR REPLACE FUNCTION public.app_admin_moderate_review(p_review_id uuid, p_is_active boolean)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_listing_id uuid;
BEGIN
  IF NOT app.est_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  SELECT listing_id INTO v_listing_id FROM app.marketplace_reviews WHERE id = p_review_id;
  IF v_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'review_not_found');
  END IF;

  UPDATE app.marketplace_reviews
     SET is_active = p_is_active, updated_at = now()
   WHERE id = p_review_id;

  -- La note de l'annonce ne compte que les avis visibles.
  UPDATE app.marketplace_listings
     SET rating_avg = COALESCE((SELECT round(avg(rating)::numeric, 1) FROM app.marketplace_reviews
                                WHERE listing_id = v_listing_id AND is_active = true), 0),
         rating_count = COALESCE((SELECT count(*) FROM app.marketplace_reviews
                                  WHERE listing_id = v_listing_id AND is_active = true), 0)
   WHERE id = v_listing_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.app_admin_moderate_review(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_moderate_review(uuid, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_admin_list_marketplace_reviews(
  p_filter text    DEFAULT 'all',
  p_limit  integer DEFAULT 100,
  p_offset integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_items jsonb;
  v_total int;
BEGIN
  IF NOT app.est_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  SELECT count(*) INTO v_total
  FROM app.marketplace_reviews r
  WHERE p_filter = 'all'
     OR (p_filter = 'visible' AND r.is_active)
     OR (p_filter = 'hidden' AND NOT r.is_active);

  SELECT COALESCE(jsonb_agg(t ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_items
  FROM (
    SELECT r.id, r.listing_id, r.order_id, r.rating, r.title, r.content,
           r.is_verified_purchase, r.seller_reply, r.seller_replied_at,
           r.is_active, r.created_at,
           l.title AS listing_title,
           s.full_name AS buyer_name,
           COALESCE(mp.display_name, mm.name) AS merchant_name
    FROM app.marketplace_reviews r
    LEFT JOIN app.marketplace_listings l ON l.id = r.listing_id
    LEFT JOIN app.students s ON s.id = r.buyer_id
    LEFT JOIN app.merchant_profiles mp ON mp.user_id = l.merchant_id
    LEFT JOIN app.marketplace_merchants mm ON mm.owner_user_id = l.merchant_id
    WHERE p_filter = 'all'
       OR (p_filter = 'visible' AND r.is_active)
       OR (p_filter = 'hidden' AND NOT r.is_active)
    ORDER BY r.created_at DESC
    LIMIT GREATEST(COALESCE(p_limit, 100), 1) OFFSET GREATEST(COALESCE(p_offset, 0), 0)
  ) t;

  RETURN jsonb_build_object('success', true, 'items', v_items, 'total', v_total);
END;
$$;

REVOKE ALL ON FUNCTION public.app_admin_list_marketplace_reviews(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_list_marketplace_reviews(text, integer, integer) TO authenticated;
