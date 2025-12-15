-- Étape 7c (cutover non-destructif) : enrichit Student Home avec video_asset_id + playback (best_url/poster_url)
-- AUCUNE suppression legacy (video_url reste)
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_step7_student_home_videoasset.sql

CREATE OR REPLACE FUNCTION app_public_student_home_content()
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

GRANT EXECUTE ON FUNCTION app_public_student_home_content() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_public_student_home_content() TO service_role;


CREATE OR REPLACE FUNCTION app_admin_get_student_home_content()
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

GRANT EXECUTE ON FUNCTION app_admin_get_student_home_content() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_get_student_home_content() TO service_role;
