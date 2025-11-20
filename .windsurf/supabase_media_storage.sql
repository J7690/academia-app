-- ========================================
-- ACADEMIA - STORAGE MEDIAS
-- Buckets et policies pour les médias du mini-site université
-- et les médias de la landing admin.
-- ========================================

-- 1) Bucket pour les médias du mini-site université
INSERT INTO storage.buckets (id, name, public)
VALUES ('university-media', 'university-media', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Lecture publique (mini-site / offres)
DROP POLICY IF EXISTS public_read_university_media ON storage.objects;
CREATE POLICY public_read_university_media
ON storage.objects
AS PERMISSIVE
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'university-media'
);

-- Écriture par les utilisateurs authentifiés (universités, admin)
DROP POLICY IF EXISTS authenticated_write_university_media ON storage.objects;
CREATE POLICY authenticated_write_university_media
ON storage.objects
AS PERMISSIVE
FOR INSERT, UPDATE, DELETE
TO authenticated
USING (
  bucket_id = 'university-media'
)
WITH CHECK (
  bucket_id = 'university-media'
);

-- 2) Bucket pour les médias de la landing admin
INSERT INTO storage.buckets (id, name, public)
VALUES ('landing-media', 'landing-media', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Lecture publique (landing / home)
DROP POLICY IF EXISTS public_read_landing_media ON storage.objects;
CREATE POLICY public_read_landing_media
ON storage.objects
AS PERMISSIVE
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'landing-media'
);

-- Écriture réservée aux utilisateurs authentifiés (admin)
DROP POLICY IF EXISTS authenticated_write_landing_media ON storage.objects;
CREATE POLICY authenticated_write_landing_media
ON storage.objects
AS PERMISSIVE
FOR INSERT, UPDATE, DELETE
TO authenticated
USING (
  bucket_id = 'landing-media'
)
WITH CHECK (
  bucket_id = 'landing-media'
);
