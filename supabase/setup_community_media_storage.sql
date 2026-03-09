-- ============================================================
-- ACADEMIA — Setup bucket community-media + RLS policies
-- Exécuter dans : Supabase Dashboard > SQL Editor
-- https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/sql/new
--
-- Ce script est IDEMPOTENT : il peut être exécuté plusieurs fois
-- sans risque de doublon ni d'erreur.
-- ============================================================

-- ─── 1. Créer le bucket (public, pour que les URLs publiques marchent) ───
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'community-media',
  'community-media',
  TRUE,
  52428800, -- 50 MB max par fichier
  ARRAY[
    'image/jpeg', 'image/png', 'image/gif', 'image/webp',
    'audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/wav', 'audio/ogg', 'audio/m4a',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/octet-stream'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = TRUE,
  file_size_limit = 52428800;

-- ─── 2. Policy SELECT — lecture publique (anon + authenticated) ─────────
DROP POLICY IF EXISTS public_read_community_media ON storage.objects;
CREATE POLICY public_read_community_media
ON storage.objects
AS PERMISSIVE
FOR SELECT
TO anon, authenticated
USING (bucket_id = 'community-media');

-- ─── 3. Policy INSERT — upload pour les utilisateurs connectés ──────────
--    Chaque user upload dans son propre dossier : {user_id}/communities/...
DROP POLICY IF EXISTS authenticated_write_community_media_insert ON storage.objects;
CREATE POLICY authenticated_write_community_media_insert
ON storage.objects
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'community-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ─── 4. Policy UPDATE — upsert pour les utilisateurs connectés ──────────
DROP POLICY IF EXISTS authenticated_write_community_media_update ON storage.objects;
CREATE POLICY authenticated_write_community_media_update
ON storage.objects
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'community-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'community-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ─── 5. Policy DELETE — suppression de ses propres fichiers ─────────────
DROP POLICY IF EXISTS authenticated_write_community_media_delete ON storage.objects;
CREATE POLICY authenticated_write_community_media_delete
ON storage.objects
AS PERMISSIVE
FOR DELETE
TO authenticated
USING (
  bucket_id = 'community-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ─── 6. Vérification ────────────────────────────────────────────────────
SELECT '--- Bucket ---' AS section;
SELECT id, name, public, file_size_limit
FROM storage.buckets
WHERE id = 'community-media';

SELECT '--- Policies ---' AS section;
SELECT polname, polcmd, polroles::text
FROM pg_policy
WHERE polrelid = 'storage.objects'::regclass
  AND polname LIKE '%community_media%'
ORDER BY polname;
