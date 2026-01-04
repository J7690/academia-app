-- ============================================================
-- POLICIES RLS POUR LE BUCKET community-media
-- À exécuter dans le SQL Editor du Dashboard Supabase
-- https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/sql/new
-- ============================================================

-- 1. Policy SELECT (lecture publique)
DROP POLICY IF EXISTS public_read_community_media ON storage.objects;
CREATE POLICY public_read_community_media
ON storage.objects
AS PERMISSIVE
FOR SELECT
TO anon, authenticated
USING (bucket_id = 'community-media');

-- 2. Policy INSERT (écriture pour authenticated)
DROP POLICY IF EXISTS authenticated_write_community_media_insert ON storage.objects;
CREATE POLICY authenticated_write_community_media_insert
ON storage.objects
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'community-media');

-- 3. Policy UPDATE (mise à jour pour authenticated)
DROP POLICY IF EXISTS authenticated_write_community_media_update ON storage.objects;
CREATE POLICY authenticated_write_community_media_update
ON storage.objects
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (bucket_id = 'community-media')
WITH CHECK (bucket_id = 'community-media');

-- 4. Policy DELETE (suppression pour authenticated)
DROP POLICY IF EXISTS authenticated_write_community_media_delete ON storage.objects;
CREATE POLICY authenticated_write_community_media_delete
ON storage.objects
AS PERMISSIVE
FOR DELETE
TO authenticated
USING (bucket_id = 'community-media');

-- Vérification
SELECT polname, polcmd 
FROM pg_policy 
WHERE polrelid = 'storage.objects'::regclass
  AND polname LIKE '%community%';
