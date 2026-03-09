-- Option 2 (ISTAPEM): hard-delete inactive university_media rows + delete storage objects
-- Only delete storage objects that are NOT referenced by any ACTIVE university_media row.

-- 0) Preview what will be deleted
WITH uni AS (
  SELECT id AS university_id
  FROM app.universities
  WHERE slug = 'istapem'
  LIMIT 1
), inactive AS (
  SELECT m.id, NULLIF(TRIM(COALESCE(m.storage_path, '')), '') AS storage_path
  FROM app.university_media m
  JOIN uni u ON u.university_id = m.university_id
  WHERE m.is_active IS FALSE
)
SELECT
  (SELECT COUNT(*) FROM inactive) AS inactive_media_rows,
  (SELECT COUNT(DISTINCT storage_path) FROM inactive WHERE storage_path IS NOT NULL) AS inactive_distinct_storage_paths,
  (SELECT COUNT(*)
   FROM storage.objects o
   WHERE o.bucket_id = 'university-media'
     AND o.name IN (SELECT storage_path FROM inactive WHERE storage_path IS NOT NULL)
  ) AS matching_storage_objects,
  (SELECT COUNT(*)
   FROM storage.objects o
   WHERE o.bucket_id = 'university-media'
     AND o.name IN (SELECT storage_path FROM inactive WHERE storage_path IS NOT NULL)
     AND NOT EXISTS (
       SELECT 1
       FROM app.university_media m2
       JOIN uni u2 ON u2.university_id = m2.university_id
       WHERE NULLIF(TRIM(COALESCE(m2.storage_path, '')), '') = o.name
     )
  ) AS storage_objects_safe_to_delete
;

-- 1) Cleanup (atomic): snapshot ISTAPEM inactive storage paths -> delete inactive DB rows -> delete safe storage objects
-- IMPORTANT: we only touch object names that were present in ISTAPEM inactive rows (pre-delete snapshot).
WITH uni AS (
  SELECT id AS university_id
  FROM app.universities
  WHERE slug = 'istapem'
  LIMIT 1
), inactive_paths AS (
  SELECT DISTINCT NULLIF(TRIM(COALESCE(m.storage_path, '')), '') AS storage_path
  FROM app.university_media m
  JOIN uni u ON u.university_id = m.university_id
  WHERE m.is_active IS FALSE
    AND NULLIF(TRIM(COALESCE(m.storage_path, '')), '') IS NOT NULL
), deleted_rows AS (
  DELETE FROM app.university_media m
  USING uni u
  WHERE m.university_id = u.university_id
    AND m.is_active IS FALSE
  RETURNING NULLIF(TRIM(COALESCE(m.storage_path, '')), '') AS storage_path
), safe_names AS (
  SELECT p.storage_path
  FROM inactive_paths p
  WHERE NOT EXISTS (
    SELECT 1
    FROM app.university_media m2
    JOIN uni u2 ON u2.university_id = m2.university_id
    WHERE NULLIF(TRIM(COALESCE(m2.storage_path, '')), '') = p.storage_path
  )
), deleted_objects AS (
  DELETE FROM storage.objects o
  USING safe_names s
  WHERE o.bucket_id = 'university-media'
    AND o.name = s.storage_path
  RETURNING o.name
)
SELECT
  (SELECT COUNT(*) FROM deleted_rows) AS deleted_media_rows,
  (SELECT COUNT(DISTINCT storage_path) FROM deleted_rows WHERE storage_path IS NOT NULL) AS deleted_distinct_storage_paths,
  (SELECT COUNT(*) FROM safe_names) AS storage_objects_targeted,
  (SELECT COUNT(*) FROM deleted_objects) AS storage_objects_deleted
;
