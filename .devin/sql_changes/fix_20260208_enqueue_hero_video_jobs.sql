-- Fix A7: enqueuer des jobs VideoAsset pour toutes les vidéos utilisées dans app.hero_playlist
-- Objectif : générer des renditions mp4 + posters pour les héros landing + accueil étudiant

DO $$
DECLARE
  v_id UUID;
BEGIN
  FOR v_id IN (
    SELECT DISTINCT video_asset_id
    FROM app.hero_playlist
    WHERE video_asset_id IS NOT NULL
  ) LOOP
    PERFORM app_videoasset_enqueue_processing(
      v_id,
      ARRAY['generate_mp4', 'generate_thumbs']::TEXT[]
    );
  END LOOP;
END;
$$;
