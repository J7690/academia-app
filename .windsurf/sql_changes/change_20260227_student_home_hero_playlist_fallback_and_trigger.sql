-- Align student home hero playlist with landing hero robustness
-- 1) Backfill base_video_url for active student_home_hero_main items from ready video_renditions
-- 2) Trigger: when a new ready rendition appears, auto-fill hero_playlist.base_video_url

DO $$
DECLARE
  r record;
  v_url text;
BEGIN
  FOR r IN
    SELECT p.id, p.video_asset_id
    FROM app.hero_playlist p
    WHERE p.slot = 'student_home_hero_main'
      AND p.is_active = TRUE
      AND lower(p.media_type) = 'video'
      AND p.video_asset_id IS NOT NULL
      AND (p.base_video_url IS NULL OR length(trim(p.base_video_url)) = 0)
  LOOP
    SELECT vr.public_url_hint
    INTO v_url
    FROM app.video_renditions vr
    WHERE vr.video_asset_id = r.video_asset_id
      AND vr.status = 'ready'
      AND vr.public_url_hint IS NOT NULL
      AND length(trim(vr.public_url_hint)) > 0
    ORDER BY vr.created_at DESC
    LIMIT 1;

    IF v_url IS NOT NULL AND length(trim(v_url)) > 0 THEN
      UPDATE app.hero_playlist
      SET base_video_url = v_url,
          updated_at = NOW()
      WHERE id = r.id;
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION app.fn_hero_playlist_autofill_base_video_url_from_rendition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_url text;
BEGIN
  IF NEW.status <> 'ready' THEN
    RETURN NEW;
  END IF;

  v_url := COALESCE(NULLIF(trim(NEW.public_url_hint), ''), NULL);
  IF v_url IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE app.hero_playlist p
  SET base_video_url = COALESCE(NULLIF(trim(p.base_video_url), ''), v_url),
      updated_at = NOW()
  WHERE p.video_asset_id = NEW.video_asset_id
    AND lower(p.media_type) = 'video'
    AND p.is_active = TRUE
    AND (p.base_video_url IS NULL OR length(trim(p.base_video_url)) = 0);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_hero_playlist_autofill_from_rendition ON app.video_renditions;
CREATE TRIGGER trg_hero_playlist_autofill_from_rendition
AFTER INSERT OR UPDATE OF status, public_url_hint
ON app.video_renditions
FOR EACH ROW
EXECUTE FUNCTION app.fn_hero_playlist_autofill_base_video_url_from_rendition();
