-- ACADEMIA - ADMIN COMMUNICATION (ANNOUNCEMENTS + ACADEMIC EVENTS)
-- This script defines admin RPCs to manage official_announcements and academic_events.

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) ADMIN RPC - LIST OFFICIAL ANNOUNCEMENTS
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_official_announcements()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_admin');
    END IF;

    SELECT coalesce(
        jsonb_agg(
            jsonb_build_object(
                'id', a.id,
                'title', a.title,
                'body', a.body,
                'summary', a.summary,
                'urgency_level', a.urgency_level,
                'category', a.category,
                'target_roles', a.target_roles,
                'target_countries', a.target_countries,
                'target_study_levels', a.target_study_levels,
                'target_university_ids', a.target_university_ids,
                'is_published', a.is_published,
                'visible_from', a.visible_from,
                'visible_until', a.visible_until,
                'created_by', a.created_by,
                'created_at', a.created_at,
                'updated_at', a.updated_at
            )
            ORDER BY a.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_result
    FROM app.official_announcements a;

    RETURN jsonb_build_object('success', true, 'announcements', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_official_announcements() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_official_announcements() TO service_role;

-- ========================================
-- 2) ADMIN RPC - UPSERT OFFICIAL ANNOUNCEMENT
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_upsert_official_announcement(
    p_announcement_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_summary TEXT,
    p_urgency_level TEXT,
    p_category TEXT,
    p_target_roles TEXT[],
    p_target_countries TEXT[],
    p_target_study_levels TEXT[],
    p_target_university_ids UUID[],
    p_is_published BOOLEAN,
    p_visible_from TIMESTAMPTZ,
    p_visible_until TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
    v_title TEXT := nullif(trim(coalesce(p_title, '')), '');
    v_body TEXT := nullif(trim(coalesce(p_body, '')), '');
    v_urgency TEXT := coalesce(nullif(trim(coalesce(p_urgency_level, '')), ''), 'info');
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_admin');
    END IF;

    IF v_title IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_title');
    END IF;

    IF v_body IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_body');
    END IF;

    IF p_announcement_id IS NULL THEN
        INSERT INTO app.official_announcements (
            title,
            body,
            summary,
            urgency_level,
            category,
            target_roles,
            target_countries,
            target_study_levels,
            target_university_ids,
            is_published,
            visible_from,
            visible_until,
            created_by
        )
        VALUES (
            v_title,
            v_body,
            p_summary,
            v_urgency,
            p_category,
            p_target_roles,
            p_target_countries,
            p_target_study_levels,
            p_target_university_ids,
            coalesce(p_is_published, false),
            p_visible_from,
            p_visible_until,
            v_user_id
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.official_announcements
        SET
            title = v_title,
            body = v_body,
            summary = p_summary,
            urgency_level = v_urgency,
            category = p_category,
            target_roles = p_target_roles,
            target_countries = p_target_countries,
            target_study_levels = p_target_study_levels,
            target_university_ids = p_target_university_ids,
            is_published = coalesce(p_is_published, is_published),
            visible_from = coalesce(p_visible_from, visible_from),
            visible_until = coalesce(p_visible_until, visible_until),
            updated_at = now()
        WHERE id = p_announcement_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'announcement_not_found');
    END IF;

    RETURN jsonb_build_object('success', true, 'announcement_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_official_announcement(
    UUID,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT[],
    TEXT[],
    TEXT[],
    UUID[],
    BOOLEAN,
    TIMESTAMPTZ,
    TIMESTAMPTZ
) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_official_announcement(
    UUID,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT[],
    TEXT[],
    TEXT[],
    UUID[],
    BOOLEAN,
    TIMESTAMPTZ,
    TIMESTAMPTZ
) TO service_role;

-- ========================================
-- 3) ADMIN RPC - DELETE OFFICIAL ANNOUNCEMENT
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_delete_official_announcement(
    p_announcement_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_deleted INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_admin');
    END IF;

    DELETE FROM app.official_announcements
    WHERE id = p_announcement_id;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    IF v_deleted = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'announcement_not_found');
    END IF;

    RETURN jsonb_build_object('success', true, 'deleted_count', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_official_announcement(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_official_announcement(UUID) TO service_role;

-- ========================================
-- 4) ADMIN RPC - LIST ACADEMIC EVENTS
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_academic_events()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_admin');
    END IF;

    SELECT coalesce(
        jsonb_agg(
            jsonb_build_object(
                'id', e.id,
                'title', e.title,
                'description', e.description,
                'event_type', e.event_type,
                'country', e.country,
                'city', e.city,
                'location', e.location,
                'university_id', e.university_id,
                'program_id', e.program_id,
                'level', e.level,
                'tags', e.tags,
                'is_all_day', e.is_all_day,
                'start_at', e.start_at,
                'end_at', e.end_at,
                'registration_open_at', e.registration_open_at,
                'registration_deadline_at', e.registration_deadline_at,
                'is_published', e.is_published,
                'is_highlighted', e.is_highlighted,
                'created_by', e.created_by,
                'created_at', e.created_at,
                'updated_at', e.updated_at
            )
            ORDER BY e.start_at NULLS LAST, e.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_result
    FROM app.academic_events e;

    RETURN jsonb_build_object('success', true, 'events', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_academic_events() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_academic_events() TO service_role;

-- ========================================
-- 5) ADMIN RPC - UPSERT ACADEMIC EVENT
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_upsert_academic_event(
    p_event_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_event_type TEXT,
    p_country TEXT,
    p_city TEXT,
    p_location TEXT,
    p_university_id UUID,
    p_program_id UUID,
    p_level TEXT,
    p_tags TEXT[],
    p_is_all_day BOOLEAN,
    p_start_at TIMESTAMPTZ,
    p_end_at TIMESTAMPTZ,
    p_registration_open_at TIMESTAMPTZ,
    p_registration_deadline_at TIMESTAMPTZ,
    p_is_published BOOLEAN,
    p_is_highlighted BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
    v_title TEXT := nullif(trim(coalesce(p_title, '')), '');
    v_event_type TEXT := coalesce(nullif(trim(coalesce(p_event_type, '')), ''), 'other');
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_admin');
    END IF;

    IF v_title IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_title');
    END IF;

    IF p_event_id IS NULL THEN
        INSERT INTO app.academic_events (
            title,
            description,
            event_type,
            country,
            city,
            location,
            university_id,
            program_id,
            level,
            tags,
            is_all_day,
            start_at,
            end_at,
            registration_open_at,
            registration_deadline_at,
            is_published,
            is_highlighted,
            created_by
        )
        VALUES (
            v_title,
            p_description,
            v_event_type,
            p_country,
            p_city,
            p_location,
            p_university_id,
            p_program_id,
            p_level,
            p_tags,
            coalesce(p_is_all_day, false),
            p_start_at,
            p_end_at,
            p_registration_open_at,
            p_registration_deadline_at,
            coalesce(p_is_published, false),
            coalesce(p_is_highlighted, false),
            v_user_id
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.academic_events
        SET
            title = v_title,
            description = p_description,
            event_type = v_event_type,
            country = p_country,
            city = p_city,
            location = p_location,
            university_id = p_university_id,
            program_id = p_program_id,
            level = p_level,
            tags = p_tags,
            is_all_day = coalesce(p_is_all_day, is_all_day),
            start_at = coalesce(p_start_at, start_at),
            end_at = coalesce(p_end_at, end_at),
            registration_open_at = coalesce(p_registration_open_at, registration_open_at),
            registration_deadline_at = coalesce(p_registration_deadline_at, registration_deadline_at),
            is_published = coalesce(p_is_published, is_published),
            is_highlighted = coalesce(p_is_highlighted, is_highlighted),
            updated_at = now()
        WHERE id = p_event_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'event_not_found');
    END IF;

    RETURN jsonb_build_object('success', true, 'event_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_academic_event(
    UUID,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    UUID,
    UUID,
    TEXT,
    TEXT[],
    BOOLEAN,
    TIMESTAMPTZ,
    TIMESTAMPTZ,
    TIMESTAMPTZ,
    TIMESTAMPTZ,
    BOOLEAN,
    BOOLEAN
) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_academic_event(
    UUID,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    UUID,
    UUID,
    TEXT,
    TEXT[],
    BOOLEAN,
    TIMESTAMPTZ,
    TIMESTAMPTZ,
    TIMESTAMPTZ,
    TIMESTAMPTZ,
    BOOLEAN,
    BOOLEAN
) TO service_role;

-- ========================================
-- 6) ADMIN RPC - DELETE ACADEMIC EVENT
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_delete_academic_event(
    p_event_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_deleted INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_admin');
    END IF;

    DELETE FROM app.academic_events
    WHERE id = p_event_id;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    IF v_deleted = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'event_not_found');
    END IF;

    RETURN jsonb_build_object('success', true, 'deleted_count', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_academic_event(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_academic_event(UUID) TO service_role;
