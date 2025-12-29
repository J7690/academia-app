-- Hero playlist: forcer l'utilisation des rendus Hero encodés (final.mp4)
-- pour les slots landing_hero_main et student_home_hero_main.
--
-- ATTENTION: cette migration calcule directement l'URL publique basée sur
-- le pattern de Storage utilisé par le backend Hero Studio:
--   hero-renders/<slot>/<playlist_item_id>/final.mp4
-- et sur le proxy Supabase côté backend:
--   https://academia-app-production.up.railway.app/supabase/storage/v1/object/public/landing-media/
--
-- À appliquer via :
--   python .windsurf/apply_one_sql_via_admin_rpc.py \
--     sql_changes/change_20251215_hero_playlist_use_renders_direct_urls.sql

DO $$
DECLARE
  v_base_proxy_url TEXT := 'https://academia-app-production.up.railway.app/supabase/storage/v1/object/public/landing-media/';
BEGIN
  -- On ne recâble que les items héros principaux actifs dont l'URL vidéo de base est
  -- vide ou ne pointe manifestement pas déjà vers un hero-renders/final.mp4.
  UPDATE app.hero_playlist hp
  SET base_video_url =
    v_base_proxy_url || 'hero-renders/' || hp.slot || '/' || hp.id::TEXT || '/final.mp4'
  WHERE hp.slot IN ('landing_hero_main', 'student_home_hero_main')
    AND hp.media_type = 'video'
    AND hp.is_active = TRUE
    AND (
      COALESCE(NULLIF(TRIM(hp.base_video_url), ''), '') = ''
      OR POSITION('hero-renders/' IN hp.base_video_url) = 0
      OR POSITION('/final.mp4' IN hp.base_video_url) = 0
    );

  RAISE NOTICE 'hero_playlist_use_renders_direct_urls: URLs recabl\u00e9es pour les slots Hero principaux lorsque n\u00e9cessaire.';
END;
$$;
