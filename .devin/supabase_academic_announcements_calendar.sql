-- ========================================
-- ACADEMIA - MODULES ANNONCES OFFICIELLES & CALENDRIER ACADÉMIQUE
-- + EXTENSION PROFIL ÉTUDIANT POUR MÉTÉO
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE ANNONCES OFFICIELLES GLOBALES
-- ========================================

CREATE TABLE IF NOT EXISTS app.official_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    summary TEXT,
    urgency_level TEXT NOT NULL DEFAULT 'info', -- info | important | critical
    category TEXT, -- ex: system, finance, exam, scholarship, event
    target_roles TEXT[] DEFAULT ARRAY['student'], -- ex: student, admin, university
    target_countries TEXT[],
    target_study_levels TEXT[], -- ex: lycee, licence, master, concours
    target_university_ids UUID[], -- référence logique vers app.universities.id
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    visible_from TIMESTAMPTZ,
    visible_until TIMESTAMPTZ,
    created_by UUID, -- auth.users.id (admin)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.official_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_published_official_announcements ON app.official_announcements;
CREATE POLICY public_select_published_official_announcements
ON app.official_announcements FOR SELECT
USING (
    is_published = TRUE
    AND (visible_from IS NULL OR visible_from <= NOW())
    AND (visible_until IS NULL OR visible_until >= NOW())
);

GRANT SELECT ON app.official_announcements TO anon, authenticated;
GRANT ALL ON app.official_announcements TO service_role;

CREATE INDEX IF NOT EXISTS idx_official_announcements_published
ON app.official_announcements (is_published, visible_from DESC);

CREATE INDEX IF NOT EXISTS idx_official_announcements_urgency
ON app.official_announcements (urgency_level);

-- ========================================
-- 2) TABLE LECTURES D'ANNONCES PAR UTILISATEUR
-- ========================================

CREATE TABLE IF NOT EXISTS app.user_announcement_reads (
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    announcement_id UUID NOT NULL REFERENCES app.official_announcements (id) ON DELETE CASCADE,
    first_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (user_id, announcement_id)
);

ALTER TABLE app.user_announcement_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_announcement_reads ON app.user_announcement_reads;
CREATE POLICY student_select_own_announcement_reads
ON app.user_announcement_reads FOR SELECT
USING (user_id = auth.uid());

DROP POLICY IF EXISTS student_upsert_own_announcement_reads ON app.user_announcement_reads;
CREATE POLICY student_insert_own_announcement_reads
ON app.user_announcement_reads FOR INSERT
WITH CHECK (user_id = auth.uid());

CREATE POLICY student_update_own_announcement_reads
ON app.user_announcement_reads FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON app.user_announcement_reads TO authenticated;
GRANT ALL ON app.user_announcement_reads TO service_role;

CREATE INDEX IF NOT EXISTS idx_user_announcement_reads_user
ON app.user_announcement_reads (user_id);

CREATE INDEX IF NOT EXISTS idx_user_announcement_reads_announcement
ON app.user_announcement_reads (announcement_id);

-- ========================================
-- 3) TABLE CALENDRIER ACADÉMIQUE GLOBAL
-- ========================================

CREATE TABLE IF NOT EXISTS app.academic_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    event_type TEXT NOT NULL, -- exam, registration, scholarship, holiday, info, other
    country TEXT,
    city TEXT,
    location TEXT, -- texte libre pour adresse / lieu
    university_id UUID, -- optionnel, référence vers app.universities.id
    program_id UUID,    -- optionnel, référence vers app.programs.id
    level TEXT,         -- ex: terminale, L1, M2, etc.
    tags TEXT[],
    is_all_day BOOLEAN NOT NULL DEFAULT FALSE,
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    registration_open_at TIMESTAMPTZ,
    registration_deadline_at TIMESTAMPTZ,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    is_highlighted BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.academic_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_published_academic_events ON app.academic_events;
CREATE POLICY student_select_published_academic_events
ON app.academic_events FOR SELECT
USING (is_published = TRUE);

GRANT SELECT ON app.academic_events TO authenticated;
GRANT ALL ON app.academic_events TO service_role;

CREATE INDEX IF NOT EXISTS idx_academic_events_published_start
ON app.academic_events (is_published, start_at);

CREATE INDEX IF NOT EXISTS idx_academic_events_type_country
ON app.academic_events (event_type, country);

-- ========================================
-- 4) TABLE SUIVI DES ÉVÉNEMENTS PAR UTILISATEUR
-- ========================================

CREATE TABLE IF NOT EXISTS app.user_event_follows (
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES app.academic_events (id) ON DELETE CASCADE,
    follow_mode TEXT NOT NULL DEFAULT 'normal', -- normal | strong | silent
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, event_id)
);

ALTER TABLE app.user_event_follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_event_follows ON app.user_event_follows;
CREATE POLICY student_select_own_event_follows
ON app.user_event_follows FOR SELECT
USING (user_id = auth.uid());

DROP POLICY IF EXISTS student_upsert_own_event_follows ON app.user_event_follows;
CREATE POLICY student_insert_own_event_follows
ON app.user_event_follows FOR INSERT
WITH CHECK (user_id = auth.uid());

CREATE POLICY student_update_own_event_follows
ON app.user_event_follows FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS student_delete_own_event_follows ON app.user_event_follows;
CREATE POLICY student_delete_own_event_follows
ON app.user_event_follows FOR DELETE
USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON app.user_event_follows TO authenticated;
GRANT ALL ON app.user_event_follows TO service_role;

CREATE INDEX IF NOT EXISTS idx_user_event_follows_user
ON app.user_event_follows (user_id);

CREATE INDEX IF NOT EXISTS idx_user_event_follows_event
ON app.user_event_follows (event_id);

-- ========================================
-- 5) EXTENSION PROFIL ÉTUDIANT POUR MÉTÉO
-- ========================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND table_name = 'students'
    ) THEN
        ALTER TABLE app.students
        ADD COLUMN IF NOT EXISTS timezone TEXT,
        ADD COLUMN IF NOT EXISTS geo_latitude NUMERIC(9,6),
        ADD COLUMN IF NOT EXISTS geo_longitude NUMERIC(9,6);
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION app_get_official_announcements_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_unread_count INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', TRUE, 'unread_count', 0);
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    SELECT COALESCE(COUNT(*), 0)
    INTO v_unread_count
    FROM app.official_announcements a
    LEFT JOIN app.user_announcement_reads r
      ON r.user_id = v_user_id
     AND r.announcement_id = a.id
    WHERE a.is_published = TRUE
      AND (a.visible_from IS NULL OR a.visible_from <= NOW())
      AND (a.visible_until IS NULL OR a.visible_until >= NOW())
      AND (a.target_roles IS NULL OR array_length(a.target_roles, 1) IS NULL OR v_role IS NULL OR v_role = ANY (a.target_roles))
      AND r.announcement_id IS NULL;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'unread_count', v_unread_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_get_official_announcements_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION app_get_official_announcements_summary() TO service_role;

CREATE OR REPLACE FUNCTION app_list_official_announcements_for_current_user(
    p_limit INTEGER DEFAULT 50
)
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
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', s.id,
                'title', s.title,
                'body', s.body,
                'summary', s.summary,
                'urgency_level', s.urgency_level,
                'category', s.category,
                'visible_from', s.visible_from,
                'visible_until', s.visible_until,
                'created_at', s.created_at,
                'is_read', s.is_read,
                'is_pinned', s.is_pinned
            )
            ORDER BY s.urgency_level DESC, s.visible_from NULLS LAST, s.created_at DESC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM (
        SELECT
            a.id,
            a.title,
            a.body,
            a.summary,
            a.urgency_level,
            a.category,
            a.visible_from,
            a.visible_until,
            a.created_at,
            (r.announcement_id IS NOT NULL) AS is_read,
            COALESCE(r.is_pinned, FALSE) AS is_pinned
        FROM app.official_announcements a
        LEFT JOIN app.user_announcement_reads r
          ON r.user_id = v_user_id
         AND r.announcement_id = a.id
        WHERE a.is_published = TRUE
          AND (a.visible_from IS NULL OR a.visible_from <= NOW())
          AND (a.visible_until IS NULL OR a.visible_until >= NOW())
          AND (a.target_roles IS NULL OR array_length(a.target_roles, 1) IS NULL OR v_role IS NULL OR v_role = ANY (a.target_roles))
        ORDER BY a.urgency_level DESC, a.visible_from NULLS LAST, a.created_at DESC
        LIMIT COALESCE(p_limit, 50)
    ) AS s;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'announcements', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_official_announcements_for_current_user(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_official_announcements_for_current_user(INTEGER) TO service_role;

CREATE OR REPLACE FUNCTION app_mark_official_announcement_read(
    p_announcement_id UUID,
    p_is_pinned BOOLEAN DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_exists BOOLEAN;
    v_pinned BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT EXISTS(
        SELECT 1
        FROM app.official_announcements a
        WHERE a.id = p_announcement_id
          AND a.is_published = TRUE
          AND (a.visible_from IS NULL OR a.visible_from <= NOW())
          AND (a.visible_until IS NULL OR a.visible_until >= NOW())
    )
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'announcement_not_available');
    END IF;

    v_pinned := COALESCE(p_is_pinned, FALSE);

    INSERT INTO app.user_announcement_reads (user_id, announcement_id, is_pinned)
    VALUES (v_user_id, p_announcement_id, v_pinned)
    ON CONFLICT (user_id, announcement_id)
    DO UPDATE SET
        last_read_at = NOW(),
        is_pinned = COALESCE(EXCLUDED.is_pinned, app.user_announcement_reads.is_pinned);

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_mark_official_announcement_read(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_mark_official_announcement_read(UUID, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_list_academic_events_for_student(
    p_from TIMESTAMPTZ DEFAULT NOW(),
    p_to TIMESTAMPTZ DEFAULT NOW() + INTERVAL '90 days'
)
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
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
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
                'created_at', e.created_at,
                'is_followed', (f.event_id IS NOT NULL),
                'follow_mode', f.follow_mode
            )
            ORDER BY e.start_at NULLS LAST, e.created_at DESC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.academic_events e
    LEFT JOIN app.user_event_follows f
      ON f.user_id = v_user_id
     AND f.event_id = e.id
    WHERE e.is_published = TRUE
      AND (
            (e.start_at IS NOT NULL AND e.start_at BETWEEN p_from AND p_to)
         OR (e.registration_deadline_at IS NOT NULL AND e.registration_deadline_at BETWEEN p_from AND p_to)
      );

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'events', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_academic_events_for_student(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_academic_events_for_student(TIMESTAMPTZ, TIMESTAMPTZ) TO service_role;

CREATE OR REPLACE FUNCTION app_list_my_followed_academic_events()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', e.id,
                'title', e.title,
                'event_type', e.event_type,
                'country', e.country,
                'city', e.city,
                'location', e.location,
                'start_at', e.start_at,
                'end_at', e.end_at,
                'registration_deadline_at', e.registration_deadline_at,
                'is_published', e.is_published,
                'is_highlighted', e.is_highlighted,
                'follow_mode', f.follow_mode,
                'followed_at', f.created_at
            )
            ORDER BY e.start_at NULLS LAST, f.created_at DESC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.user_event_follows f
    JOIN app.academic_events e
      ON e.id = f.event_id
    WHERE f.user_id = v_user_id
      AND e.is_published = TRUE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'events', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_my_followed_academic_events() TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_my_followed_academic_events() TO service_role;

CREATE OR REPLACE FUNCTION app_follow_academic_event(
    p_event_id UUID,
    p_follow_mode TEXT DEFAULT 'normal'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_mode TEXT := LOWER(TRIM(COALESCE(p_follow_mode, 'normal')));
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'student' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_student');
    END IF;

    IF v_mode NOT IN ('normal', 'strong', 'silent') THEN
        v_mode := 'normal';
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM app.academic_events e
        WHERE e.id = p_event_id
          AND e.is_published = TRUE
    )
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'event_not_available');
    END IF;

    INSERT INTO app.user_event_follows (user_id, event_id, follow_mode)
    VALUES (v_user_id, p_event_id, v_mode)
    ON CONFLICT (user_id, event_id)
    DO UPDATE SET follow_mode = EXCLUDED.follow_mode;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_follow_academic_event(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_follow_academic_event(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_unfollow_academic_event(
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
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'student' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_student');
    END IF;

    DELETE FROM app.user_event_follows
    WHERE user_id = v_user_id
      AND event_id = p_event_id;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'deleted_count', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION app_unfollow_academic_event(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_unfollow_academic_event(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_get_academic_events_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_upcoming_followed INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', TRUE, 'upcoming_followed_count', 0);
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    SELECT COALESCE(COUNT(*), 0)
    INTO v_upcoming_followed
    FROM app.academic_events e
    JOIN app.user_event_follows f
      ON f.user_id = v_user_id
     AND f.event_id = e.id
    WHERE e.is_published = TRUE
      AND e.start_at IS NOT NULL
      AND e.start_at >= NOW()
      AND e.start_at <= NOW() + INTERVAL '30 days';

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'upcoming_followed_count', v_upcoming_followed
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_get_academic_events_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION app_get_academic_events_summary() TO service_role;

