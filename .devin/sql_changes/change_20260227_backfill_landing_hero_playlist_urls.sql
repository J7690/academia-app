-- Backfill landing hero playlist URLs from latest landing-media hero-video upload
-- Ensures AuthLandingScreen can resolve a URL: best_url (via renditions) OR base_video_url.

DO $$
DECLARE
  v_path text;
  v_public_url text;
  v_item_id uuid;
  v_asset_id uuid;
  v_has_rendition boolean;
BEGIN
  -- Latest uploaded hero video in landing-media
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

  -- Pick the active playlist item for landing hero
  SELECT p.id, p.video_asset_id
  INTO v_item_id, v_asset_id
  FROM app.hero_playlist p
  WHERE p.slot = 'landing_hero_main'
    AND p.is_active = true
  ORDER BY p.sort_order, p.created_at
  LIMIT 1;

  IF v_item_id IS NULL THEN
    RAISE NOTICE 'No active hero_playlist item found for slot landing_hero_main';
    RETURN;
  END IF;

  -- Ensure fallback URL for the client (AuthLandingScreen uses best_url else base_video_url)
  UPDATE app.hero_playlist
  SET base_video_url = COALESCE(NULLIF(trim(base_video_url), ''), v_public_url),
      updated_at = NOW()
  WHERE id = v_item_id;

  -- Also ensure landing_config fallback fields (even if UI not using it right now)
  UPDATE app.landing_config
  SET hero_storage_path = COALESCE(hero_storage_path, v_path),
      hero_video_url = COALESCE(hero_video_url, v_public_url),
      updated_at = NOW()
  WHERE id = (
    SELECT id FROM app.landing_config ORDER BY created_at DESC LIMIT 1
  );

  -- If the playlist item has a video_asset_id but no ready mp4/hls rendition, insert a ready mp4 rendition
  IF v_asset_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM app.video_renditions r
      WHERE r.video_asset_id = v_asset_id
        AND r.status = 'ready'
        AND r.kind IN ('mp4','hls')
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
        v_asset_id,
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
  END IF;
END $$;
