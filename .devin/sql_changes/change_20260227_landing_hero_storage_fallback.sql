-- Landing Hero fallback storage_path (like university mini-site)
-- Adds hero_video_url + hero_storage_path to landing_config and creates a trigger
-- that automatically links the latest uploaded landing-media hero video to landing_config
-- using a synthetic VideoAsset + MP4 rendition.

-- 1) Schema change: store last uploaded hero video info (optional, for fallback)
ALTER TABLE app.landing_config
  ADD COLUMN IF NOT EXISTS hero_video_url TEXT,
  ADD COLUMN IF NOT EXISTS hero_storage_path TEXT;

-- 2) Helper: build a public URL for landing-media objects
-- NOTE: hardcoded project URL (same as other public_url_hint conventions)
CREATE OR REPLACE FUNCTION app.landing_media_public_url(p_storage_path TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/landing-media/'
         || ltrim(COALESCE(p_storage_path, ''), '/');
$$;

-- 3) Trigger function: when a hero video is uploaded to landing-media, auto-link it
CREATE OR REPLACE FUNCTION app.on_landing_media_object_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_path TEXT;
  v_lower TEXT;
  v_config_id uuid;
  v_asset_id uuid;
  v_public_url TEXT;
  v_playlist_item_id uuid;
BEGIN
  IF NEW.bucket_id <> 'landing-media' THEN
    RETURN NEW;
  END IF;

  v_path := COALESCE(NEW.name, '');
  v_lower := LOWER(v_path);

  -- only hero-video uploads
  IF POSITION('/landing/hero-video/' IN v_lower) = 0 THEN
    RETURN NEW;
  END IF;

  -- only video files
  IF NOT (
    v_lower LIKE '%.mp4' OR v_lower LIKE '%.mov' OR v_lower LIKE '%.webm' OR v_lower LIKE '%.m4v'
  ) THEN
    RETURN NEW;
  END IF;

  SELECT id
  INTO v_config_id
  FROM app.landing_config
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_config_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_asset_id := gen_random_uuid();
  v_public_url := app.landing_media_public_url(v_path);

  INSERT INTO app.video_assets (
    id,
    owner_user_id,
    origin,
    status,
    canonical_type,
    duration_ms,
    width,
    height,
    rotation,
    has_audio,
    created_at,
    updated_at
  ) VALUES (
    v_asset_id,
    NULL,
    'landing-media',
    'ready',
    'video',
    NULL,
    NULL,
    NULL,
    NULL,
    FALSE,
    NOW(),
    NOW()
  );

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

  UPDATE app.landing_config
  SET
    video_asset_id = v_asset_id,
    hero_storage_path = v_path,
    hero_video_url = v_public_url,
    updated_at = NOW()
  WHERE id = v_config_id;

  -- Also keep the landing hero playlist in sync (this is what AuthLandingScreen uses)
  SELECT p.id
  INTO v_playlist_item_id
  FROM app.hero_playlist p
  WHERE p.slot = 'landing_hero_main'
    AND p.is_active = TRUE
  ORDER BY p.sort_order, p.created_at
  LIMIT 1;

  IF v_playlist_item_id IS NULL THEN
    INSERT INTO app.hero_playlist (
      slot,
      title,
      subtitle,
      media_type,
      base_video_url,
      base_image_url,
      video_asset_id,
      sort_order,
      is_active,
      created_at,
      updated_at
    ) VALUES (
      'landing_hero_main',
      'media',
      NULL,
      'video',
      v_public_url,
      NULL,
      v_asset_id,
      1,
      TRUE,
      NOW(),
      NOW()
    )
    RETURNING id INTO v_playlist_item_id;
  ELSE
    UPDATE app.hero_playlist
    SET
      media_type = 'video',
      base_video_url = v_public_url,
      base_image_url = NULL,
      video_asset_id = v_asset_id,
      updated_at = NOW()
    WHERE id = v_playlist_item_id;
  END IF;

  INSERT INTO app.video_asset_contexts (id, video_asset_id, context_type, context_id, role, created_at)
  VALUES (
    gen_random_uuid(),
    v_asset_id,
    'landing_config',
    v_config_id,
    'hero',
    NOW()
  )
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id;

  -- Optional: context for the playlist item as well
  IF v_playlist_item_id IS NOT NULL THEN
    INSERT INTO app.video_asset_contexts (id, video_asset_id, context_type, context_id, role, created_at)
    VALUES (
      gen_random_uuid(),
      v_asset_id,
      'hero_playlist',
      v_playlist_item_id,
      'primary',
      NOW()
    )
    ON CONFLICT (context_type, context_id, role) DO UPDATE
      SET video_asset_id = EXCLUDED.video_asset_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_landing_media_object_insert ON storage.objects;
CREATE TRIGGER trg_on_landing_media_object_insert
AFTER INSERT ON storage.objects
FOR EACH ROW
EXECUTE FUNCTION app.on_landing_media_object_insert();

-- 4) Public/Admin landing content: fallback playback.best_url to hero_video_url when no renditions are ready
CREATE OR REPLACE FUNCTION public.app_public_landing_content()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_config JSONB;
    v_announcements JSONB;
    v_partners JSONB;
    v_why_cards JSONB;
    v_videos JSONB;
BEGIN
    SELECT COALESCE(
      TO_JSONB(c)
      || JSONB_BUILD_OBJECT(
        'playback', JSONB_BUILD_OBJECT(
          'best_url', COALESCE(
            (
              SELECT r.public_url_hint
              FROM app.video_renditions r
              WHERE r.video_asset_id = c.video_asset_id
                AND r.status = 'ready'
                AND r.kind IN ('hls','mp4')
              ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
              LIMIT 1
            ),
            c.hero_video_url
          ),
          'poster_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = c.video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('poster','thumbnail')
            ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          )
        )
      ),
      '{}'::JSONB
    )
    INTO v_config
    FROM app.landing_config c
    ORDER BY c.created_at DESC
    LIMIT 1;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(a) ORDER BY a.sort_order, a.created_at),
        '[]'::JSONB
    )
    INTO v_announcements
    FROM app.landing_announcements a
    WHERE a.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(p) ORDER BY p.sort_order, p.created_at),
        '[]'::JSONB
    )
    INTO v_partners
    FROM app.landing_partners p
    WHERE p.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(w) ORDER BY w.sort_order, w.created_at),
        '[]'::JSONB
    )
    INTO v_why_cards
    FROM app.landing_why_cards w
    WHERE w.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(
          (
            TO_JSONB(v)
            || JSONB_BUILD_OBJECT(
              'playback', JSONB_BUILD_OBJECT(
                'best_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = v.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('hls','mp4')
                  ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                ),
                'poster_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = v.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('poster','thumbnail')
                  ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                )
              )
            )
          )
          ORDER BY v.sort_order, v.created_at
        ),
        '[]'::JSONB
    )
    INTO v_videos
    FROM app.landing_videos v
    WHERE v.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'config', v_config,
        'announcements', v_announcements,
        'partners', v_partners,
        'why_cards', v_why_cards,
        'videos', v_videos
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_public_landing_content() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_public_landing_content() TO service_role;

CREATE OR REPLACE FUNCTION public.app_admin_get_landing_content()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_config JSONB;
    v_announcements JSONB;
    v_partners JSONB;
    v_why_cards JSONB;
    v_videos JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT COALESCE(
      TO_JSONB(c)
      || JSONB_BUILD_OBJECT(
        'playback', JSONB_BUILD_OBJECT(
          'best_url', COALESCE(
            (
              SELECT r.public_url_hint
              FROM app.video_renditions r
              WHERE r.video_asset_id = c.video_asset_id
                AND r.status = 'ready'
                AND r.kind IN ('hls','mp4')
              ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
              LIMIT 1
            ),
            c.hero_video_url
          ),
          'poster_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = c.video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('poster','thumbnail')
            ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          )
        )
      ),
      '{}'::JSONB
    )
    INTO v_config
    FROM app.landing_config c
    ORDER BY c.created_at DESC
    LIMIT 1;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(a) ORDER BY a.sort_order, a.created_at),
        '[]'::JSONB
    )
    INTO v_announcements
    FROM app.landing_announcements a;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(p) ORDER BY p.sort_order, p.created_at),
        '[]'::JSONB
    )
    INTO v_partners
    FROM app.landing_partners p;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(w) ORDER BY w.sort_order, w.created_at),
        '[]'::JSONB
    )
    INTO v_why_cards
    FROM app.landing_why_cards w;

    SELECT COALESCE(
        JSONB_AGG(
          (
            TO_JSONB(v)
            || JSONB_BUILD_OBJECT(
              'playback', JSONB_BUILD_OBJECT(
                'best_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = v.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('hls','mp4')
                  ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                ),
                'poster_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = v.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('poster','thumbnail')
                  ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                )
              )
            )
          )
          ORDER BY v.sort_order, v.created_at
        ),
        '[]'::JSONB
    )
    INTO v_videos
    FROM app.landing_videos v;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'config', v_config,
        'announcements', v_announcements,
        'partners', v_partners,
        'why_cards', v_why_cards,
        'videos', v_videos
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_get_landing_content() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_get_landing_content() TO service_role;
