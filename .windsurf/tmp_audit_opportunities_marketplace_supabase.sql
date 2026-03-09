SELECT
  table_schema,
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE column_name ILIKE '%click_at%'
ORDER BY table_schema, table_name, column_name;

SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%click_at%'
ORDER BY p.proname, args;

SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'app_student_list_marketplace_listings',
    'app_student_get_marketplace_listing_detail',
    'app_admin_list_published_marketplace_listings',
    'app_admin_list_pending_marketplace_listings',
    'app_admin_review_marketplace_listing',
    'app_merchant_upsert_marketplace_listing',
    'app_merchant_submit_marketplace_listing_for_review'
  )
ORDER BY p.proname, args;

SELECT
  l.id,
  l.title,
  l.review_status,
  l.status,
  l.is_active,
  l.updated_at
FROM app.marketplace_listings l
ORDER BY l.updated_at DESC;

SELECT
  l.id,
  l.title
FROM app.marketplace_listings l
WHERE l.is_active = TRUE
  AND l.status = 'published'
  AND l.review_status = 'approved'
ORDER BY l.updated_at DESC;
