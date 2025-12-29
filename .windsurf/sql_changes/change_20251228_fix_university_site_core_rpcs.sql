-- 2025-12-28: Réactivation des RPC coeur mini-site université (lecture / gestion)
-- Objectif : remplacer d'éventuels shims ou implémentations incomplètes
-- pour app_public_university_site, app_list_university_site_for_management
-- et app_admin_get_university_site, avec les versions complètes
-- compatibles VideoAsset (video_asset_id + playback).

-- 0) Nettoyage préalable : on supprime les versions existantes en public
--    afin de garantir que les implémentations ci-dessous soient bien actives.

DROP FUNCTION IF EXISTS public.app_public_university_site(p_slug TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.app_list_university_site_for_management() CASCADE;
DROP FUNCTION IF EXISTS public.app_admin_get_university_site(p_university_id UUID) CASCADE;


-- 1) RPC PUBLIC (étudiant) : app_public_university_site(p_slug TEXT)
--    Version enrichie avec playback à partir de app.video_renditions.

CREATE OR REPLACE FUNCTION public.app_public_university_site(
    p_slug TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_university_id UUID;
    v_university JSONB;
    v_config JSONB;
    v_blocks JSONB;
    v_media JSONB;
    v_programs JSONB;
    v_courses JSONB;
    v_banners JSONB;
    v_events JSONB;
    v_news JSONB;
    v_staff JSONB;
BEGIN
    SELECT u.id
    INTO v_university_id
    FROM app.universities u
    WHERE u.slug = p_slug
      AND u.is_active = TRUE
    LIMIT 1;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_found');
    END IF;

    SELECT JSONB_BUILD_OBJECT(
        'id', u.id,
        'name', u.name,
        'slug', u.slug,
        'logo_url', u.logo_url,
        'country', u.country,
        'city', u.city,
        'website_url', u.website_url,
        'description', u.description,
        'tagline', u.tagline,
        'banner_image_url', u.banner_image_url,
        'contact_email', u.contact_email,
        'contact_phone', u.contact_phone,
        'address', u.address,
        'social_links', u.social_links,
        'mission', u.mission,
        'vision', u.vision,
        'key_figures', u.key_figures
    )
    INTO v_university
    FROM app.universities u
    WHERE u.id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(b) ORDER BY b.sort_order, b.created_at),
        '[]'::JSONB
    )
    INTO v_blocks
    FROM app.university_site_blocks b
    WHERE b.university_id = v_university_id
      AND b.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(
          (
            TO_JSONB(m)
            || JSONB_BUILD_OBJECT(
              'playback', JSONB_BUILD_OBJECT(
                'best_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = m.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('hls','mp4')
                  ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                ),
                'poster_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = m.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('poster','thumbnail')
                  ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                )
              )
            )
          )
          ORDER BY m.sort_order, m.created_at
        ),
        '[]'::JSONB
    )
    INTO v_media
    FROM app.university_media m
    WHERE m.university_id = v_university_id
      AND m.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', p.id,
                'title', p.title,
                'description', p.description,
                'degree_level', p.degree_level,
                'mode', p.mode,
                'duration_months', p.duration_months,
                'tuition_fees', p.tuition_fees,
                'highlighted', p.highlighted,
                'is_active', p.is_active,
                'created_at', p.created_at,
                'updated_at', p.updated_at
            ) ORDER BY p.highlighted DESC, p.created_at DESC
        ),
        '[]'::JSONB
    )
    INTO v_programs
    FROM app.programs p
    WHERE p.university_id = v_university_id
      AND p.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'program_id', c.program_id,
                'title', c.title,
                'description', c.description,
                'credits', c.credits,
                'prerequisites', c.prerequisites,
                'instructor', c.instructor,
                'is_active', c.is_active,
                'created_at', c.created_at,
                'updated_at', c.updated_at
            ) ORDER BY c.created_at DESC
        ),
        '[]'::JSONB
    )
    INTO v_courses
    FROM app.courses c
    JOIN app.programs p2 ON p2.id = c.program_id
    WHERE p2.university_id = v_university_id
      AND c.is_active = TRUE;

    SELECT COALESCE(TO_JSONB(c), '{}'::JSONB)
    INTO v_config
    FROM app.university_site_config c
    WHERE c.university_id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(ban) ORDER BY ban.sort_order, ban.created_at),
        '[]'::JSONB
    )
    INTO v_banners
    FROM app.university_site_banners ban
    WHERE ban.university_id = v_university_id
      AND ban.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(e) ORDER BY e.start_at NULLS LAST, e.created_at DESC),
        '[]'::JSONB
    )
    INTO v_events
    FROM app.university_events e
    WHERE e.university_id = v_university_id
      AND e.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(n) ORDER BY n.published_at DESC NULLS LAST, n.created_at DESC),
        '[]'::JSONB
    )
    INTO v_news
    FROM app.university_news n
    WHERE n.university_id = v_university_id
      AND n.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(s) ORDER BY s.sort_order, s.created_at),
        '[]'::JSONB
    )
    INTO v_staff
    FROM app.university_staff s
    WHERE s.university_id = v_university_id
      AND s.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'university', v_university,
        'config', v_config,
        'blocks', v_blocks,
        'media', v_media,
        'programs', v_programs,
        'courses', v_courses,
        'banners', v_banners,
        'events', v_events,
        'news', v_news,
        'staff', v_staff
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_public_university_site(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_public_university_site(TEXT) TO service_role;


-- 2) RPC ADMIN (gestion d'une université par l'admin) : app_admin_get_university_site

CREATE OR REPLACE FUNCTION public.app_admin_get_university_site(
    p_university_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university JSONB;
    v_blocks JSONB;
    v_media JSONB;
    v_events JSONB;
    v_news JSONB;
    v_staff JSONB;
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

    SELECT JSONB_BUILD_OBJECT(
        'id', u.id,
        'name', u.name,
        'slug', u.slug,
        'logo_url', u.logo_url,
        'country', u.country,
        'city', u.city,
        'website_url', u.website_url,
        'description', u.description
    )
    INTO v_university
    FROM app.universities u
    WHERE u.id = p_university_id;

    IF v_university IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(b) ORDER BY b.sort_order, b.created_at),
        '[]'::JSONB
    )
    INTO v_blocks
    FROM app.university_site_blocks b
    WHERE b.university_id = p_university_id;

    SELECT COALESCE(
        JSONB_AGG(
          (
            TO_JSONB(m)
            || JSONB_BUILD_OBJECT(
              'playback', JSONB_BUILD_OBJECT(
                'best_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = m.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('hls','mp4')
                  ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                ),
                'poster_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = m.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('poster','thumbnail')
                  ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                )
              )
            )
          )
          ORDER BY m.sort_order, m.created_at
        ),
        '[]'::JSONB
    )
    INTO v_media
    FROM app.university_media m
    WHERE m.university_id = p_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(e) ORDER BY e.start_at NULLS LAST, e.created_at DESC),
        '[]'::JSONB
    )
    INTO v_events
    FROM app.university_events e
    WHERE e.university_id = p_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(n) ORDER BY n.published_at DESC NULLS LAST, n.created_at DESC),
        '[]'::JSONB
    )
    INTO v_news
    FROM app.university_news n
    WHERE n.university_id = p_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(s) ORDER BY s.sort_order, s.created_at),
        '[]'::JSONB
    )
    INTO v_staff
    FROM app.university_staff s
    WHERE s.university_id = p_university_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'university', v_university,
        'blocks', v_blocks,
        'media', v_media,
        'events', v_events,
        'news', v_news,
        'staff', v_staff
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_get_university_site(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_get_university_site(UUID) TO service_role;


-- 3) RPC UNIVERSITÉ (gestion du mini-site par l'université connectée) :
--    app_list_university_site_for_management()

CREATE OR REPLACE FUNCTION public.app_list_university_site_for_management()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_university JSONB;
    v_config JSONB;
    v_blocks JSONB;
    v_media JSONB;
    v_banners JSONB;
    v_events JSONB;
    v_news JSONB;
    v_staff JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    SELECT TO_JSONB(u)
    INTO v_university
    FROM app.universities u
    WHERE u.id = v_university_id;

    IF v_university IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(b) ORDER BY b.sort_order, b.created_at),
        '[]'::JSONB
    )
    INTO v_blocks
    FROM app.university_site_blocks b
    WHERE b.university_id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(
          (
            TO_JSONB(m)
            || JSONB_BUILD_OBJECT(
              'playback', JSONB_BUILD_OBJECT(
                'best_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = m.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('hls','mp4')
                  ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                ),
                'poster_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = m.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('poster','thumbnail')
                  ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                )
              )
            )
          )
          ORDER BY m.sort_order, m.created_at
        ),
        '[]'::JSONB
    )
    INTO v_media
    FROM app.university_media m
    WHERE m.university_id = v_university_id;

    SELECT COALESCE(TO_JSONB(c), '{}'::JSONB)
    INTO v_config
    FROM app.university_site_config c
    WHERE c.university_id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(ban) ORDER BY ban.sort_order, ban.created_at),
        '[]'::JSONB
    )
    INTO v_banners
    FROM app.university_site_banners ban
    WHERE ban.university_id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(e) ORDER BY e.start_at NULLS LAST, e.created_at DESC),
        '[]'::JSONB
    )
    INTO v_events
    FROM app.university_events e
    WHERE e.university_id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(n) ORDER BY n.published_at DESC NULLS LAST, n.created_at DESC),
        '[]'::JSONB
    )
    INTO v_news
    FROM app.university_news n
    WHERE n.university_id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(s) ORDER BY s.sort_order, s.created_at),
        '[]'::JSONB
    )
    INTO v_staff
    FROM app.university_staff s
    WHERE s.university_id = v_university_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'university', v_university,
        'config', v_config,
        'blocks', v_blocks,
        'media', v_media,
        'banners', v_banners,
        'events', v_events,
        'news', v_news,
        'staff', v_staff
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_list_university_site_for_management() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_list_university_site_for_management() TO service_role;
