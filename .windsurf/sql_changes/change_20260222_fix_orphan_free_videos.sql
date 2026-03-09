-- Réparer les free_videos orphelines (créées sans video_asset_id).
-- Pour chaque free_video sans video_asset_id, on cherche le fichier Storage
-- correspondant via le user_id et on crée un video_asset + video_rendition.
--
-- On utilise une approche par corrélation: pour chaque free_video orpheline,
-- on cherche le fichier Storage uploadé juste avant la création de la free_video
-- par le même utilisateur dans le bucket challenge-media/free_videos.

DO $$
DECLARE
  rec RECORD;
  v_asset_id UUID;
  v_storage_url TEXT;
  v_count INT := 0;
BEGIN
  FOR rec IN
    SELECT fv.id AS fv_id, fv.user_id, fv.created_at AS fv_created
    FROM app.free_videos fv
    WHERE fv.video_asset_id IS NULL
      AND fv.is_active = TRUE
    ORDER BY fv.created_at DESC
  LOOP
    -- Chercher le fichier Storage uploadé juste avant la création de la free_video
    SELECT
      'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/'
        || o.bucket_id || '/' || o.name
    INTO v_storage_url
    FROM storage.objects o
    WHERE o.bucket_id = 'challenge-media'
      AND o.name LIKE rec.user_id::TEXT || '/free_videos/%'
      AND o.created_at <= rec.fv_created + INTERVAL '10 seconds'
      AND o.created_at >= rec.fv_created - INTERVAL '60 seconds'
    ORDER BY ABS(EXTRACT(EPOCH FROM (o.created_at - rec.fv_created)))
    LIMIT 1;

    IF v_storage_url IS NOT NULL THEN
      -- Créer le video_asset
      INSERT INTO app.video_assets (
        owner_user_id, origin, status, has_audio,
        canonical_type, created_at, updated_at
      ) VALUES (
        rec.user_id, 'free_video_upload', 'ready', TRUE,
        'video', rec.fv_created, rec.fv_created
      )
      RETURNING id INTO v_asset_id;

      -- Créer la video_rendition
      INSERT INTO app.video_renditions (
        video_asset_id, rendition_key, kind, status,
        public_url_hint, storage_bucket, storage_path, created_at
      ) VALUES (
        v_asset_id, 'legacy_primary', 'mp4', 'ready',
        v_storage_url, 'challenge-media', 'legacy/external', rec.fv_created
      );

      -- Mettre à jour la free_video
      UPDATE app.free_videos
      SET video_asset_id = v_asset_id, updated_at = NOW()
      WHERE id = rec.fv_id;

      -- Contexte VideoAsset
      INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
      VALUES (v_asset_id, 'free_video', rec.fv_id, 'primary')
      ON CONFLICT (context_type, context_id, role) DO UPDATE
        SET video_asset_id = EXCLUDED.video_asset_id;

      v_count := v_count + 1;
      RAISE NOTICE 'Fixed free_video % with asset % url %', rec.fv_id, v_asset_id, v_storage_url;
    ELSE
      RAISE NOTICE 'No storage match for free_video % (user=%, created=%)', rec.fv_id, rec.user_id, rec.fv_created;
    END IF;
  END LOOP;

  RAISE NOTICE 'Total fixed: %', v_count;
END;
$$;
