-- VideoAsset storage bucket RLS policies
-- A appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py \
--   sql_changes/change_20251229_videoassets_storage_policies.sql

-- 1) S'assurer que le bucket "video-assets" existe (idempotent)
INSERT INTO storage.buckets (id, name, public)
VALUES ('video-assets', 'video-assets', TRUE)
ON CONFLICT (id) DO NOTHING;

-- 2) Policies RLS sur storage.objects pour le bucket video-assets

-- Lecture publique (comme landing-media / challenge-media)
DROP POLICY IF EXISTS public_read_video_assets ON storage.objects;
CREATE POLICY public_read_video_assets
ON storage.objects
AS PERMISSIVE
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'video-assets'
);

-- Ecriture reservee aux utilisateurs authentifies
DROP POLICY IF EXISTS authenticated_write_video_assets_insert ON storage.objects;
DROP POLICY IF EXISTS authenticated_write_video_assets_update ON storage.objects;
DROP POLICY IF EXISTS authenticated_write_video_assets_delete ON storage.objects;

CREATE POLICY authenticated_write_video_assets_insert
ON storage.objects
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'video-assets'
);

CREATE POLICY authenticated_write_video_assets_update
ON storage.objects
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'video-assets'
)
WITH CHECK (
  bucket_id = 'video-assets'
);

CREATE POLICY authenticated_write_video_assets_delete
ON storage.objects
AS PERMISSIVE
FOR DELETE
TO authenticated
USING (
  bucket_id = 'video-assets'
);
