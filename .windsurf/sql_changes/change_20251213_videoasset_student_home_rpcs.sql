-- Student Home RPCs (VideoAsset-only)
-- À appliquer via admin_execute_sql (script .windsurf/apply_one_sql_via_admin_rpc.py)

-- 1) Admin upsert student home video : VideoAsset-only (p_video_asset_id, p_playback)

-- On supprime tous les anciens shims legacy (p_video_url)
DROP FUNCTION IF EXISTS public.app_admin_upsert_student_home_video(
  p_video_id uuid,
  p_video_url text,
  p_title text,
  p_sort_order integer,
  p_is_active boolean
) CASCADE;

DROP FUNCTION IF EXISTS public.app_admin_upsert_student_home_video(
  p_video_id uuid,
  p_video_url text,
  p_title text,
  p_sort_order integer,
  p_is_active boolean,
  p_media_type text
) CASCADE;

CREATE OR REPLACE FUNCTION public.app_admin_upsert_student_home_video(
  p_video_id UUID,
  p_video_asset_id UUID,
  p_playback JSONB,
  p_title TEXT,
  p_sort_order INTEGER,
  p_is_active BOOLEAN,
  p_media_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_role       TEXT;
  v_id         UUID;
  v_media_type TEXT;
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

  v_media_type := LOWER(TRIM(COALESCE(p_media_type, 'video')));
  IF v_media_type NOT IN ('video', 'image') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_media_type');
  END IF;

  IF p_video_asset_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_asset_id');
  END IF;

  IF p_video_id IS NULL THEN
    INSERT INTO app.student_home_videos (
      video_asset_id,
      title,
      sort_order,
      is_active,
      media_type
    ) VALUES (
      p_video_asset_id,
      p_title,
      p_sort_order,
      COALESCE(p_is_active, TRUE),
      v_media_type
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE app.student_home_videos
    SET
      video_asset_id = p_video_asset_id,
      title          = p_title,
      sort_order     = p_sort_order,
      is_active      = COALESCE(p_is_active, is_active),
      media_type     = v_media_type,
      updated_at     = NOW()
    WHERE id = p_video_id
    RETURNING id INTO v_id;
  END IF;

  IF v_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_saved');
  END IF;

  -- Contexte VideoAsset pour l'item Student Home
  INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
  VALUES (p_video_asset_id, 'student_home_video', v_id, 'primary')
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'video_id', v_id,
    'video_asset_id', p_video_asset_id,
    'media_type', v_media_type,
    'playback', JSONB_BUILD_OBJECT(
      'best_url',   p_playback->>'best_url',
      'poster_url', p_playback->>'poster_url'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_upsert_student_home_video(
  UUID, UUID, JSONB, TEXT, INTEGER, BOOLEAN, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_upsert_student_home_video(
  UUID, UUID, JSONB, TEXT, INTEGER, BOOLEAN, TEXT
) TO service_role;


-- 2) RPC publiques/admin de lecture Student Home : version VideoAsset-aware (aucun fallback legacy)

CREATE OR REPLACE FUNCTION public.app_public_student_home_content()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_announcements JSONB;
    v_videos JSONB;
BEGIN
    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(a) ORDER BY a.sort_order, a.created_at),
        '[]'::JSONB
    )
    INTO v_announcements
    FROM app.student_home_announcements a
    WHERE a.is_active = TRUE;

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
    FROM app.student_home_videos v
    WHERE v.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'announcements', v_announcements,
        'videos', v_videos
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_public_student_home_content() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_public_student_home_content() TO service_role;


CREATE OR REPLACE FUNCTION public.app_admin_get_student_home_content()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_announcements JSONB;
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
        JSONB_AGG(TO_JSONB(a) ORDER BY a.sort_order, a.created_at),
        '[]'::JSONB
    )
    INTO v_announcements
    FROM app.student_home_announcements a;

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
    FROM app.student_home_videos v;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'announcements', v_announcements,
        'videos', v_videos
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_get_student_home_content() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_get_student_home_content() TO service_role;
