-- Ajout d'offres (formations courtes, opportunités, cours en ligne)
-- dans le payload public de la landing via app_public_landing_content().
-- À appliquer via:
--   python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20260113_landing_offers_highlights.sql

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
    v_short_training_highlights JSONB;
    v_opportunity_highlights JSONB;
    v_online_course_highlights JSONB;
BEGIN
    -- Config + hero playback (VideoAsset)
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

    -- Annonces actives
    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(a) ORDER BY a.sort_order, a.created_at),
        '[]'::JSONB
    )
    INTO v_announcements
    FROM app.landing_announcements a
    WHERE a.is_active = TRUE;

    -- Partenaires actifs
    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(p) ORDER BY p.sort_order, p.created_at),
        '[]'::JSONB
    )
    INTO v_partners
    FROM app.landing_partners p
    WHERE p.is_active = TRUE;

    -- Why cards actives
    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(w) ORDER BY w.sort_order, w.created_at),
        '[]'::JSONB
    )
    INTO v_why_cards
    FROM app.landing_why_cards w
    WHERE w.is_active = TRUE;

    -- Vidéos de landing (VideoAsset + playback)
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

    -- Formations courtes mises en avant (sessions publiques à venir)
    SELECT COALESCE(
        JSONB_AGG(x.item ORDER BY x.start_at ASC),
        '[]'::JSONB
    )
    INTO v_short_training_highlights
    FROM (
        SELECT
          JSONB_BUILD_OBJECT(
            'session_id', s.id,
            'title',       t.title,
            'category',    t.category,
            'modality',    t.modality,
            'start_at',    s.start_at,
            'location',    s.location,
            'price',       t.price
          ) AS item,
          s.start_at
        FROM app.short_training_sessions s
        JOIN app.short_trainings t ON t.id = s.training_id
        WHERE s.is_active = TRUE
          AND t.is_active = TRUE
          AND s.status   = 'open'
          AND s.start_at >= NOW()
        ORDER BY s.start_at ASC
        LIMIT 5
    ) AS x;

    -- Opportunités mises en avant (publiées et actives)
    SELECT COALESCE(
        JSONB_AGG(x.item ORDER BY x.is_featured DESC, x.created_at DESC),
        '[]'::JSONB
    )
    INTO v_opportunity_highlights
    FROM (
        SELECT
          JSONB_BUILD_OBJECT(
            'id',                  o.id,
            'title',               o.title,
            'short_description',   o.short_description,
            'type',                o.type,
            'category',            o.category,
            'organization_name',   o.organization_name,
            'country',             o.country,
            'city',                o.city,
            'is_remote_possible',  o.is_remote_possible,
            'application_deadline',o.application_deadline
          ) AS item,
          o.is_featured,
          o.created_at
        FROM app.opportunities o
        WHERE o.is_active = TRUE
          AND o.status = 'published'
          AND o.is_featured = TRUE
          AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE)
        ORDER BY o.is_featured DESC, o.created_at DESC
        LIMIT 5
    ) AS x;

    -- Cours en ligne mis en avant (publics)
    SELECT COALESCE(
        JSONB_AGG(x.item ORDER BY x.created_at DESC),
        '[]'::JSONB
    )
    INTO v_online_course_highlights
    FROM (
        SELECT
          JSONB_BUILD_OBJECT(
            'id',                c.id,
            'title',             c.title,
            'short_description', c.short_description,
            'category',          c.category,
            'level',             c.level,
            'price',             c.price
          ) AS item,
          c.created_at
        FROM app.online_courses c
        WHERE c.is_published = TRUE
        ORDER BY c.created_at DESC
        LIMIT 5
    ) AS x;

    RETURN JSONB_BUILD_OBJECT(
        'success',                   TRUE,
        'config',                    v_config,
        'announcements',             v_announcements,
        'partners',                  v_partners,
        'why_cards',                 v_why_cards,
        'videos',                    v_videos,
        'short_training_highlights', COALESCE(v_short_training_highlights, '[]'::JSONB),
        'opportunity_highlights',    COALESCE(v_opportunity_highlights, '[]'::JSONB),
        'online_course_highlights',  COALESCE(v_online_course_highlights, '[]'::JSONB)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_public_landing_content() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_public_landing_content() TO service_role;
