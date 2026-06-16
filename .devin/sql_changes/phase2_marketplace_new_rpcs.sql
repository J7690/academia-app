-- ============================================================
-- PHASE 2 — Marketplace New RPCs
-- Date: 2026-03-14
-- Description: Reviews CRUD, listing-based social RPCs,
--   detail v2, trigger rating_avg update
-- ============================================================

-- ============================================================
-- 2.3.3 — Reviews RPCs
-- ============================================================

-- Add a review (buyer only, optionally verified purchase)
CREATE OR REPLACE FUNCTION public.app_student_add_listing_review(
  p_listing_id UUID,
  p_order_id UUID DEFAULT NULL,
  p_rating INT DEFAULT 5,
  p_title TEXT DEFAULT NULL,
  p_content TEXT DEFAULT NULL,
  p_media_urls TEXT[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_verified BOOLEAN := FALSE;
  v_review_id UUID;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_rating');
  END IF;

  -- Check listing exists and is active
  IF NOT EXISTS (
    SELECT 1 FROM app.marketplace_listings
    WHERE id = p_listing_id AND is_active = true AND review_status = 'approved'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'listing_not_found');
  END IF;

  -- Check verified purchase
  IF p_order_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM app.marketplace_orders o
      JOIN app.marketplace_order_items oi ON oi.order_id = o.id
      WHERE o.id = p_order_id
        AND o.student_id = v_user
        AND oi.product_id = p_listing_id
        AND o.status IN ('delivered', 'completed')
    ) THEN
      v_verified := TRUE;
    END IF;
  END IF;

  -- Check duplicate
  IF p_order_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM app.marketplace_reviews
    WHERE listing_id = p_listing_id AND buyer_id = v_user AND order_id = p_order_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_reviewed');
  END IF;

  INSERT INTO app.marketplace_reviews (listing_id, buyer_id, order_id, rating, title, content, media_urls, is_verified_purchase)
  VALUES (p_listing_id, v_user, p_order_id, p_rating, p_title, p_content, p_media_urls, v_verified)
  RETURNING id INTO v_review_id;

  -- Update listing rating_avg and rating_count
  UPDATE app.marketplace_listings
  SET rating_avg = COALESCE((
    SELECT ROUND(AVG(rating)::NUMERIC, 1)
    FROM app.marketplace_reviews
    WHERE listing_id = p_listing_id AND is_active = true
  ), 0),
  rating_count = COALESCE((
    SELECT COUNT(*)
    FROM app.marketplace_reviews
    WHERE listing_id = p_listing_id AND is_active = true
  ), 0)
  WHERE id = p_listing_id;

  RETURN jsonb_build_object('success', true, 'review_id', v_review_id);
END;
$$;

-- List reviews for a listing
CREATE OR REPLACE FUNCTION public.app_student_list_listing_reviews(
  p_listing_id UUID,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0,
  p_sort TEXT DEFAULT 'newest'
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_reviews JSONB;
  v_total INT;
  v_order TEXT;
BEGIN
  IF p_sort = 'highest' THEN v_order := 'rating DESC, created_at DESC';
  ELSIF p_sort = 'lowest' THEN v_order := 'rating ASC, created_at DESC';
  ELSE v_order := 'created_at DESC';
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM app.marketplace_reviews
  WHERE listing_id = p_listing_id AND is_active = true;

  EXECUTE format(
    'SELECT COALESCE(jsonb_agg(t), ''[]''::jsonb) FROM (
      SELECT r.id, r.rating, r.title, r.content, r.media_urls,
             r.is_verified_purchase, r.seller_reply, r.seller_replied_at,
             r.created_at,
             s.full_name AS buyer_name,
             s.avatar_url AS buyer_avatar
      FROM app.marketplace_reviews r
      LEFT JOIN app.students s ON s.id = r.buyer_id
      WHERE r.listing_id = %L AND r.is_active = true
      ORDER BY %s
      LIMIT %s OFFSET %s
    ) t', p_listing_id, v_order, p_limit, p_offset
  ) INTO v_reviews;

  RETURN jsonb_build_object(
    'success', true,
    'reviews', v_reviews,
    'total', v_total,
    'has_more', (p_offset + p_limit) < v_total
  );
END;
$$;

-- Merchant reply to a review
CREATE OR REPLACE FUNCTION public.app_merchant_reply_review(
  p_review_id UUID,
  p_reply TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Check merchant owns the listing
  IF NOT EXISTS (
    SELECT 1 FROM app.marketplace_reviews r
    JOIN app.marketplace_listings l ON l.id = r.listing_id
    JOIN app.marketplace_merchants m ON m.id = l.merchant_id
    WHERE r.id = p_review_id AND m.owner_user_id = v_user
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  UPDATE app.marketplace_reviews
  SET seller_reply = p_reply, seller_replied_at = NOW(), updated_at = NOW()
  WHERE id = p_review_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Admin moderate a review
CREATE OR REPLACE FUNCTION public.app_admin_moderate_review(
  p_review_id UUID,
  p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_listing_id UUID;
BEGIN
  SELECT listing_id INTO v_listing_id
  FROM app.marketplace_reviews WHERE id = p_review_id;

  IF v_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'review_not_found');
  END IF;

  UPDATE app.marketplace_reviews
  SET is_active = p_is_active, updated_at = NOW()
  WHERE id = p_review_id;

  -- Recalculate listing rating
  UPDATE app.marketplace_listings
  SET rating_avg = COALESCE((
    SELECT ROUND(AVG(rating)::NUMERIC, 1)
    FROM app.marketplace_reviews
    WHERE listing_id = v_listing_id AND is_active = true
  ), 0),
  rating_count = COALESCE((
    SELECT COUNT(*)
    FROM app.marketplace_reviews
    WHERE listing_id = v_listing_id AND is_active = true
  ), 0)
  WHERE id = v_listing_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- 2.3.4 — Listing-based social RPCs (reactions using listing_id)
-- ============================================================

-- Toggle reaction on a listing (not opportunity)
CREATE OR REPLACE FUNCTION public.app_listing_toggle_reaction(
  p_listing_id UUID,
  p_reaction_type TEXT DEFAULT 'like'
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_existing UUID;
  v_existing_type TEXT;
  v_count INT;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF p_reaction_type NOT IN ('like', 'love') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_reaction_type');
  END IF;

  -- Check if reaction exists
  SELECT id, reaction_type INTO v_existing, v_existing_type
  FROM app.opportunity_reactions
  WHERE listing_id = p_listing_id AND user_id = v_user
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    IF v_existing_type = p_reaction_type THEN
      -- Toggle off
      DELETE FROM app.opportunity_reactions WHERE id = v_existing;
    ELSE
      -- Change type
      UPDATE app.opportunity_reactions SET reaction_type = p_reaction_type WHERE id = v_existing;
    END IF;
  ELSE
    -- Add new
    INSERT INTO app.opportunity_reactions (listing_id, user_id, reaction_type)
    VALUES (p_listing_id, v_user, p_reaction_type);
  END IF;

  -- Count
  SELECT COUNT(*) INTO v_count
  FROM app.opportunity_reactions
  WHERE listing_id = p_listing_id;

  -- Update listing counter
  UPDATE app.marketplace_listings
  SET reactions_count = v_count
  WHERE id = p_listing_id;

  -- Get my reaction
  RETURN jsonb_build_object(
    'success', true,
    'reactions_count', v_count,
    'my_reaction', (SELECT reaction_type FROM app.opportunity_reactions WHERE listing_id = p_listing_id AND user_id = v_user)
  );
END;
$$;

-- Get reactions for a listing
CREATE OR REPLACE FUNCTION public.app_listing_get_reactions(
  p_listing_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_likes INT;
  v_loves INT;
  v_total INT;
  v_my TEXT;
BEGIN
  SELECT COUNT(*) FILTER (WHERE reaction_type = 'like'),
         COUNT(*) FILTER (WHERE reaction_type = 'love'),
         COUNT(*)
  INTO v_likes, v_loves, v_total
  FROM app.opportunity_reactions
  WHERE listing_id = p_listing_id;

  IF v_user IS NOT NULL THEN
    SELECT reaction_type INTO v_my
    FROM app.opportunity_reactions
    WHERE listing_id = p_listing_id AND user_id = v_user;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'likes', v_likes,
    'loves', v_loves,
    'total', v_total,
    'my_reaction', v_my
  );
END;
$$;

-- ============================================================
-- 2.3.5 — Enhanced listing detail (v2)
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_student_get_listing_detail_v2(
  p_listing_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_listing JSONB;
  v_media JSONB;
  v_merchant JSONB;
  v_reviews JSONB;
  v_my_reaction TEXT;
  v_is_bookmarked BOOLEAN := FALSE;
BEGIN
  -- Listing data
  SELECT jsonb_build_object(
    'id', l.id, 'title', l.title, 'short_description', l.short_description,
    'description', l.description, 'type', l.type, 'category', l.category,
    'organization_name', l.organization_name,
    'country', l.country, 'city', l.city,
    'price_from', l.price_from, 'price_to', l.price_to, 'currency', l.currency,
    'min_order_qty', l.min_order_qty, 'lead_time_days', l.lead_time_days,
    'is_ready_to_ship', l.is_ready_to_ship,
    'cover_url', l.cover_url, 'video_url', l.video_url,
    'rating_avg', l.rating_avg, 'rating_count', l.rating_count,
    'sales_count', l.sales_count, 'views_count', l.views_count,
    'reactions_count', l.reactions_count,
    'tags', l.tags, 'specifications', l.specifications, 'variants', l.variants,
    'review_status', l.review_status, 'is_active', l.is_active,
    'merchant_id', l.merchant_id, 'created_at', l.created_at
  ) INTO v_listing
  FROM app.marketplace_listings l
  WHERE l.id = p_listing_id AND l.is_active = true AND l.review_status = 'approved';

  IF v_listing IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'listing_not_found');
  END IF;

  -- Increment views
  UPDATE app.marketplace_listings
  SET views_count = views_count + 1
  WHERE id = p_listing_id;

  -- Media
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', m.id, 'media_type', m.media_type,
      'storage_path', m.storage_path, 'storage_bucket', m.storage_bucket,
      'external_url', m.external_url,
      'sort_order', m.sort_order, 'title', m.title
    ) ORDER BY m.sort_order, m.created_at
  ), '[]'::jsonb) INTO v_media
  FROM app.marketplace_listing_media m
  WHERE m.listing_id = p_listing_id AND m.is_active = true;

  -- Merchant
  SELECT jsonb_build_object(
    'id', mm.id, 'name', mm.name, 'display_name', mm.display_name,
    'logo_url', mm.logo_url, 'country', mm.country, 'city', mm.city,
    'is_verified', mm.is_verified, 'verification_level', mm.verification_level,
    'rating_avg', mm.rating_avg, 'total_products', mm.total_products,
    'total_sales', mm.total_sales
  ) INTO v_merchant
  FROM app.marketplace_merchants mm
  WHERE mm.id = (v_listing->>'merchant_id')::UUID;

  -- Latest 3 reviews
  SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO v_reviews
  FROM (
    SELECT r.id, r.rating, r.title, r.content, r.is_verified_purchase,
           r.seller_reply, r.created_at,
           s.full_name AS buyer_name, s.avatar_url AS buyer_avatar
    FROM app.marketplace_reviews r
    LEFT JOIN app.students s ON s.id = r.buyer_id
    WHERE r.listing_id = p_listing_id AND r.is_active = true
    ORDER BY r.created_at DESC
    LIMIT 3
  ) t;

  -- My reaction
  IF v_user IS NOT NULL THEN
    SELECT reaction_type INTO v_my_reaction
    FROM app.opportunity_reactions
    WHERE listing_id = p_listing_id AND user_id = v_user;

    SELECT EXISTS(
      SELECT 1 FROM app.marketplace_listing_bookmarks
      WHERE listing_id = p_listing_id AND user_id = v_user
    ) INTO v_is_bookmarked;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'listing', v_listing,
    'media', v_media,
    'merchant', v_merchant,
    'reviews', v_reviews,
    'my_reaction', v_my_reaction,
    'is_bookmarked', v_is_bookmarked
  );
END;
$$;

-- ============================================================
-- 2.3.7 — Trigger to auto-update rating on reviews change
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_trigger_update_listing_rating()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_listing_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_listing_id := OLD.listing_id;
  ELSE
    v_listing_id := NEW.listing_id;
  END IF;

  UPDATE app.marketplace_listings
  SET rating_avg = COALESCE((
    SELECT ROUND(AVG(rating)::NUMERIC, 1)
    FROM app.marketplace_reviews
    WHERE listing_id = v_listing_id AND is_active = true
  ), 0),
  rating_count = COALESCE((
    SELECT COUNT(*)
    FROM app.marketplace_reviews
    WHERE listing_id = v_listing_id AND is_active = true
  ), 0)
  WHERE id = v_listing_id;

  IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$$;

-- Drop trigger if exists then create
DROP TRIGGER IF EXISTS trg_marketplace_reviews_rating ON app.marketplace_reviews;
CREATE TRIGGER trg_marketplace_reviews_rating
  AFTER INSERT OR UPDATE OR DELETE ON app.marketplace_reviews
  FOR EACH ROW EXECUTE FUNCTION public.app_trigger_update_listing_rating();

-- ============================================================
-- DONE — Phase 2 RPCs
-- ============================================================
