-- Hero playlist: rendre les vidéos Hero (landing + home étudiant)
-- lisibles sur téléphones d'ancienne génération.
--
-- Objectif : si un rendu Hero Studio existe (app.hero_renders.render_url),
-- on recâble base_video_url sur ce rendu encodé "MediaTek-friendly".
--
-- À appliquer via :
--   python .windsurf/apply_one_sql_via_admin_rpc.py \
--     sql_changes/change_20251215_hero_playlist_low_end_compat.sql

DO $$
DECLARE
  v_updated_landing INTEGER := 0;
  v_updated_home    INTEGER := 0;
BEGIN
  -- Landing public : slot = 'landing_hero_main'
  UPDATE app.hero_playlist hp
  SET base_video_url = hr.render_url
  FROM app.hero_renders hr
  WHERE hr.playlist_item_id = hp.id
    AND hr.status = 'done'
    AND hr.render_url IS NOT NULL
    AND hp.slot = 'landing_hero_main'
  RETURNING 1 INTO v_updated_landing;

  -- Accueil étudiant : slot = 'student_home_hero_main'
  UPDATE app.hero_playlist hp
  SET base_video_url = hr.render_url
  FROM app.hero_renders hr
  WHERE hr.playlist_item_id = hp.id
    AND hr.status = 'done'
    AND hr.render_url IS NOT NULL
    AND hp.slot = 'student_home_hero_main'
  RETURNING 1 INTO v_updated_home;

  RAISE NOTICE 'hero_playlist_low_end_compat: landing_hero_main mis à jour, lignes=%', v_updated_landing;
  RAISE NOTICE 'hero_playlist_low_end_compat: student_home_hero_main mis à jour, lignes=%', v_updated_home;
END;
$$;
