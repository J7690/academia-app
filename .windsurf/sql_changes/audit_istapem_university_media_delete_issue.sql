-- Audit ISTAPEM media deletion issue
-- Goal: list active/inactive media, and spot recently inactivated items.

-- 1) Find ISTAPEM university id
SELECT id, slug, name
FROM app.universities
WHERE slug = 'istapem'
LIMIT 1
 ;

-- 2) List all media for ISTAPEM with status
SELECT
  id,
  media_type,
  title,
  is_active,
  sort_order,
  url,
  storage_path,
  video_asset_id,
  created_at,
  updated_at
FROM app.university_media
WHERE university_id = (SELECT id FROM app.universities WHERE slug='istapem' LIMIT 1)
ORDER BY updated_at DESC NULLS LAST, created_at DESC
LIMIT 200
 ;

-- 3) Count active vs inactive
SELECT
  COUNT(*) FILTER (WHERE is_active IS TRUE) AS active_count,
  COUNT(*) FILTER (WHERE is_active IS FALSE) AS inactive_count,
  COUNT(*) AS total_count
FROM app.university_media
WHERE university_id = (SELECT id FROM app.universities WHERE slug='istapem' LIMIT 1)
 ;

-- 4) List inactive media only
SELECT
  id,
  media_type,
  title,
  is_active,
  sort_order,
  storage_path,
  created_at,
  updated_at
FROM app.university_media
WHERE university_id = (SELECT id FROM app.universities WHERE slug='istapem' LIMIT 1)
  AND is_active IS FALSE
ORDER BY updated_at DESC NULLS LAST, created_at DESC
LIMIT 200
 ;
