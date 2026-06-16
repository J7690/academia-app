-- Marketplace student path audit (Opportunités > Marketplace)

SELECT
  p.oid,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'app_student_list_marketplace_listings',
    'app_student_get_marketplace_listing_detail',
    'app_list_marketplace_categories',
    'app_marketplace_listing_toggle_bookmark',
    'app_student_list_bookmarked_marketplace_listings',
    'app_student_create_marketplace_listing_inquiry'
  )
ORDER BY p.proname, args;

SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args,
  LEFT(pg_get_functiondef(p.oid), 4000) AS function_def_prefix
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'app_student_list_marketplace_listings',
    'app_student_get_marketplace_listing_detail'
  )
ORDER BY p.proname, args;

SELECT
  n.nspname AS schema,
  c.relname AS relation,
  c.relkind AS kind,
  a.attname AS column,
  pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE a.attnum > 0
  AND NOT a.attisdropped
  AND a.attname IN ('click_at', 'l_click_at')
ORDER BY n.nspname, c.relname, a.attname;

SELECT
  schemaname,
  viewname
FROM pg_views
WHERE definition ILIKE '%click_at%'
ORDER BY schemaname, viewname;

SELECT
  l.id,
  l.title,
  l.review_status,
  l.status,
  l.is_active,
  l.created_at,
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
