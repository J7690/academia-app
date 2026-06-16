-- fix_20260210_hero_videoassets_enqueue_processing.sql
--
-- Objectif :
--  - Ré-enfiler pour traitement (generate_mp4, generate_thumbs, etc.)
--    tous les VideoAssets actuellement utilisés dans app.hero_playlist
--    qui n'ont PAS encore de rendition vidéo prête (mp4 ou hls).
--  - Ceci permet de corriger les vidéos du hero qui ont un video_asset_id
--    mais pas encore de playback.best_url / poster_url dans les RPC publics.
--
-- Hypothèses :
--  - La fonction app_videoasset_enqueue_processing(video_asset_id uuid)
--    existe déjà et se charge de créer les jobs nécessaires.
--  - Le schéma app.video_renditions contient les renditions avec :
--      video_asset_id, kind (mp4/hls/poster/thumbnail), status.
--
-- Cette migration est idempotente :
--  - On ne touche qu'aux assets actifs référencés dans app.hero_playlist.
--  - On n'envoie en traitement que ceux qui n'ont pas encore de mp4/hls ready.

DO $$
DECLARE
  v_rec RECORD;
  v_enqueued INTEGER := 0;
BEGIN
  -- On parcourt tous les VideoAssets référencés dans le hero,
  -- en se concentrant sur les médias vidéo actifs.
  FOR v_rec IN
    SELECT DISTINCT hp.video_asset_id
    FROM app.hero_playlist AS hp
    WHERE hp.video_asset_id IS NOT NULL
      AND hp.media_type = 'video'
      AND COALESCE(hp.is_active, TRUE) = TRUE
  LOOP
    -- On ne ré-enfile que les assets qui n'ont aucun mp4/hls en status=ready.
    IF NOT EXISTS (
      SELECT 1
      FROM app.video_renditions AS r
      WHERE r.video_asset_id = v_rec.video_asset_id
        AND r.status = 'ready'
        AND r.kind IN ('mp4', 'hls')
    ) THEN
      PERFORM app_videoasset_enqueue_processing(v_rec.video_asset_id);
      v_enqueued := v_enqueued + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'fix_20260210_hero_videoassets_enqueue_processing: enqueued % video assets for processing', v_enqueued;
END $$;
