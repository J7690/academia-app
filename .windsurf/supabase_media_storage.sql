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
DROP POLICY IF EXISTS authenticated_write_university_media_insert ON storage.objects;
DROP POLICY IF EXISTS authenticated_write_university_media_update ON storage.objects;
DROP POLICY IF EXISTS authenticated_write_university_media_delete ON storage.objects;

CREATE POLICY authenticated_write_university_media_insert
ON storage.objects
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'university-media'
);

CREATE POLICY authenticated_write_university_media_update
ON storage.objects
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'university-media'
)
WITH CHECK (
  bucket_id = 'university-media'
);

CREATE POLICY authenticated_write_university_media_delete
ON storage.objects
AS PERMISSIVE
FOR DELETE
TO authenticated
USING (
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
DROP POLICY IF EXISTS authenticated_write_landing_media_insert ON storage.objects;
DROP POLICY IF EXISTS authenticated_write_landing_media_update ON storage.objects;
DROP POLICY IF EXISTS authenticated_write_landing_media_delete ON storage.objects;

CREATE POLICY authenticated_write_landing_media_insert
ON storage.objects
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'landing-media'
);

CREATE POLICY authenticated_write_landing_media_update
ON storage.objects
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'landing-media'
)
WITH CHECK (
  bucket_id = 'landing-media'
);

CREATE POLICY authenticated_write_landing_media_delete
ON storage.objects
AS PERMISSIVE
FOR DELETE
TO authenticated
USING (
  bucket_id = 'landing-media'
);

-- 3) Bucket pour les médias des vidéos de challenges
INSERT INTO storage.buckets (id, name, public)
VALUES ('challenge-media', 'challenge-media', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Lecture publique (vidéos de challenges)
DROP POLICY IF EXISTS public_read_challenge_media ON storage.objects;
CREATE POLICY public_read_challenge_media
ON storage.objects
AS PERMISSIVE
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'challenge-media'
);

-- Écriture réservée aux utilisateurs authentifiés (vidéos de challenges)
DROP POLICY IF EXISTS authenticated_write_challenge_media ON storage.objects;
DROP POLICY IF EXISTS authenticated_write_challenge_media_insert ON storage.objects;
DROP POLICY IF EXISTS authenticated_write_challenge_media_update ON storage.objects;
DROP POLICY IF EXISTS authenticated_write_challenge_media_delete ON storage.objects;

CREATE POLICY authenticated_write_challenge_media_insert
ON storage.objects
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'challenge-media'
);

CREATE POLICY authenticated_write_challenge_media_update
ON storage.objects
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'challenge-media'
)
WITH CHECK (
  bucket_id = 'challenge-media'
);

CREATE POLICY authenticated_write_challenge_media_delete
ON storage.objects
AS PERMISSIVE
FOR DELETE
TO authenticated
USING (
  bucket_id = 'challenge-media'
);

-- 4) Bucket pour les médias des communautés (chat de communautés)
INSERT INTO storage.buckets (id, name, public)
VALUES ('community-media', 'community-media', TRUE)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS public_read_community_media ON storage.objects;
CREATE POLICY public_read_community_media
ON storage.objects
AS PERMISSIVE
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'community-media'
);

DROP POLICY IF EXISTS authenticated_write_community_media_insert ON storage.objects;
DROP POLICY IF EXISTS authenticated_write_community_media_update ON storage.objects;
DROP POLICY IF EXISTS authenticated_write_community_media_delete ON storage.objects;

CREATE POLICY authenticated_write_community_media_insert
ON storage.objects
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'community-media'
);

CREATE POLICY authenticated_write_community_media_update
ON storage.objects
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'community-media'
)
WITH CHECK (
  bucket_id = 'community-media'
);

CREATE POLICY authenticated_write_community_media_delete
ON storage.objects
AS PERMISSIVE
FOR DELETE
TO authenticated
USING (
  bucket_id = 'community-media'
);
