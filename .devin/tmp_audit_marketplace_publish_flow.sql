SELECT
  l.id,
  l.title,
  l.merchant_id,
  l.review_status,
  l.status,
  l.is_active,
  l.submitted_at,
  l.reviewed_at,
  l.reviewed_by,
  l.created_at,
  l.updated_at
FROM app.marketplace_listings l
ORDER BY l.updated_at DESC;

SELECT
  l.id,
  l.title,
  l.review_status,
  l.status,
  l.is_active,
  (l.is_active = TRUE AND l.status = 'published' AND l.review_status = 'approved') AS matches_student_base_filters
FROM app.marketplace_listings l
ORDER BY l.updated_at DESC;

SELECT
  l.id,
  l.title,
  l.review_status,
  l.status,
  l.is_active,
  l.type,
  l.category_id,
  l.sub_category_id,
  l.organization_name,
  l.country,
  l.city,
  l.price_from,
  l.price_to,
  l.currency,
  l.min_order_qty,
  l.lead_time_days,
  l.is_ready_to_ship
FROM app.marketplace_listings l
WHERE l.is_active = TRUE
  AND l.status = 'published'
  AND l.review_status = 'approved'
ORDER BY l.updated_at DESC;

SELECT
  mp.user_id,
  mp.is_active,
  mp.is_verified,
  mp.verification_level,
  mp.updated_at
FROM app.merchant_profiles mp
ORDER BY mp.updated_at DESC;

SELECT
  l.id,
  l.title,
  (
    SELECT COUNT(*)::int
    FROM app.marketplace_listing_media ml
    WHERE ml.listing_id = l.id
      AND ml.is_active = TRUE
  ) AS media_count
FROM app.marketplace_listings l
WHERE l.is_active = TRUE
  AND l.status = 'published'
  AND l.review_status = 'approved'
ORDER BY l.updated_at DESC;
