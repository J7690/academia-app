-- Étape 7 (cutover non-destructif) : enrichit les RPC Landing avec video_asset_id + playback (best_url/poster_url)
-- AUCUNE suppression legacy (video_url, etc. restent)
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_step7_landing_videoasset.sql

CREATE OR REPLACE FUNCTION app_public_landing_content()
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
          'best_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = c.video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('hls','mp4')
            ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
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

GRANT EXECUTE ON FUNCTION app_public_landing_content() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_public_landing_content() TO service_role;


CREATE OR REPLACE FUNCTION app_admin_get_landing_content()
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
          'best_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = c.video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('hls','mp4')
            ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
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

GRANT EXECUTE ON FUNCTION app_admin_get_landing_content() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_get_landing_content() TO service_role;
