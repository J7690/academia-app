-- Fix landing hero playlist items that have no base_video_url and no ready renditions
-- Strategy (mini-site-like robustness):
-- 1) Find latest uploaded landing hero video file in landing-media
-- 2) Set base_video_url for ALL active landing_hero_main playlist items to that URL if missing
-- 3) Ensure each item's video_asset_id has at least one ready mp4 rendition pointing to that URL

DO $$
DECLARE
  v_path text;
  v_public_url text;
  r record;
  v_has_rendition boolean;
BEGIN
  SELECT o.name
  INTO v_path
  FROM storage.objects o
  WHERE o.bucket_id = 'landing-media'
    AND lower(o.name) LIKE '%/landing/hero-video/%'
    AND (
      lower(o.name) LIKE '%.mp4' OR lower(o.name) LIKE '%.mov' OR lower(o.name) LIKE '%.webm' OR lower(o.name) LIKE '%.m4v'
    )
  ORDER BY o.created_at DESC
  LIMIT 1;

  IF v_path IS NULL OR length(trim(v_path)) = 0 THEN
    RAISE NOTICE 'No landing hero-video found in landing-media bucket';
    RETURN;
  END IF;

  v_public_url := app.landing_media_public_url(v_path);

  -- Backfill missing base_video_url
  UPDATE app.hero_playlist
  SET base_video_url = v_public_url,
      updated_at = NOW()
  WHERE slot = 'landing_hero_main'
    AND is_active = TRUE
    AND (base_video_url IS NULL OR length(trim(base_video_url)) = 0);

  -- Ensure each playlist item's VideoAsset has a ready mp4 rendition
  FOR r IN
    SELECT p.id, p.video_asset_id
    FROM app.hero_playlist p
    WHERE p.slot = 'landing_hero_main'
      AND p.is_active = TRUE
      AND p.media_type = 'video'
      AND p.video_asset_id IS NOT NULL
  LOOP
    SELECT EXISTS (
      SELECT 1
      FROM app.video_renditions vr
      WHERE vr.video_asset_id = r.video_asset_id
        AND vr.status = 'ready'
        AND vr.kind IN ('mp4','hls')
      LIMIT 1
    )
    INTO v_has_rendition;

    IF NOT v_has_rendition THEN
      INSERT INTO app.video_renditions (
        id,
        video_asset_id,
        rendition_key,
        kind,
        width,
        height,
        bitrate_kbps,
        fps,
        codec,
        storage_bucket,
        storage_path,
        public_url_hint,
        status,
        error,
        created_at
      ) VALUES (
        gen_random_uuid(),
        r.video_asset_id,
        'landing-media:' || v_path,
        'mp4',
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        'landing-media',
        v_path,
        v_public_url,
        'ready',
        NULL,
        NOW()
      );
    END IF;
  END LOOP;

  -- Keep landing_config fallback fields updated too
  UPDATE app.landing_config
  SET hero_storage_path = COALESCE(hero_storage_path, v_path),
      hero_video_url = COALESCE(hero_video_url, v_public_url),
      updated_at = NOW()
  WHERE id = (
    SELECT id FROM app.landing_config ORDER BY created_at DESC LIMIT 1
  );

END $$;
