-- ========================================
-- ACADEMIA - MODULE COURS EN LIGNE (ONLINE COURSES)
-- Cours vidéo à la demande + lives + progression + forums + certificats
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE COURS EN LIGNE
-- ========================================

CREATE TABLE IF NOT EXISTS app.online_courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    short_description TEXT,
    full_description TEXT,
    category TEXT,
    level TEXT,
    language TEXT,
    estimated_hours INTEGER,
    cover_image_url TEXT,
    price NUMERIC,
    contact_phone TEXT,
    contact_whatsapp TEXT,
    contact_email TEXT,
    contact_website TEXT,
    contact_notes TEXT,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.online_courses
  ADD COLUMN IF NOT EXISTS contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS contact_whatsapp TEXT,
  ADD COLUMN IF NOT EXISTS contact_email TEXT,
  ADD COLUMN IF NOT EXISTS contact_website TEXT,
  ADD COLUMN IF NOT EXISTS contact_notes TEXT;

ALTER TABLE app.online_courses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_published_online_courses ON app.online_courses;
CREATE POLICY public_select_published_online_courses
ON app.online_courses FOR SELECT
USING (is_published = TRUE);

GRANT SELECT ON app.online_courses TO anon, authenticated;
GRANT ALL ON app.online_courses TO service_role;

-- ========================================
-- 2) SECTIONS & LEÇONS
-- ========================================

CREATE TABLE IF NOT EXISTS app.online_course_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES app.online_courses (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    sort_order INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.online_course_sections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_online_course_sections ON app.online_course_sections;
CREATE POLICY public_select_online_course_sections
ON app.online_course_sections FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.online_courses c
    WHERE c.id = online_course_sections.course_id
      AND c.is_published = TRUE
  )
);

GRANT SELECT ON app.online_course_sections TO anon, authenticated;
GRANT ALL ON app.online_course_sections TO service_role;

CREATE TABLE IF NOT EXISTS app.online_course_lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    section_id UUID NOT NULL REFERENCES app.online_course_sections (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    lesson_type TEXT NOT NULL DEFAULT 'video', -- video, live, quiz, assignment, resource
    sort_order INTEGER,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    estimated_minutes INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.online_course_lessons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_online_course_lessons ON app.online_course_lessons;
CREATE POLICY public_select_online_course_lessons
ON app.online_course_lessons FOR SELECT
USING (
  is_published = TRUE AND EXISTS (
    SELECT 1 FROM app.online_course_sections s
    JOIN app.online_courses c ON c.id = s.course_id
    WHERE s.id = online_course_lessons.section_id
      AND c.is_published = TRUE
  )
);

GRANT SELECT ON app.online_course_lessons TO anon, authenticated;
GRANT ALL ON app.online_course_lessons TO service_role;

-- ========================================
-- 3) MÉDIA DES LEÇONS (VIDÉO, RESSOURCES)
-- ========================================

CREATE TABLE IF NOT EXISTS app.online_course_lesson_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lesson_id UUID NOT NULL REFERENCES app.online_course_lessons (id) ON DELETE CASCADE,
    media_type TEXT NOT NULL, -- video, document, link, etc.
    title TEXT,
    description TEXT,
    storage_bucket TEXT,
    storage_path TEXT,
    external_url TEXT,
    duration_seconds INTEGER,
    sort_order INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.online_course_lesson_media ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_online_course_lesson_media ON app.online_course_lesson_media;
CREATE POLICY public_select_online_course_lesson_media
ON app.online_course_lesson_media FOR SELECT
USING (
  is_active = TRUE AND EXISTS (
    SELECT 1
    FROM app.online_course_lessons l
    JOIN app.online_course_sections s ON s.id = l.section_id
    JOIN app.online_courses c ON c.id = s.course_id
    WHERE l.id = online_course_lesson_media.lesson_id
      AND l.is_published = TRUE
      AND c.is_published = TRUE
  )
);

GRANT SELECT ON app.online_course_lesson_media TO anon, authenticated;
GRANT ALL ON app.online_course_lesson_media TO service_role;

-- ========================================
-- 4) INSCRIPTIONS & PROGRESSION
-- ========================================

CREATE TABLE IF NOT EXISTS app.online_course_enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES app.online_courses (id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    access_type TEXT NOT NULL DEFAULT 'free', -- free, paid, scholarship, internal
    starts_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE (course_id, student_id)
);

ALTER TABLE app.online_course_enrollments
    ADD COLUMN IF NOT EXISTS contact_phone TEXT,
    ADD COLUMN IF NOT EXISTS preferred_channel TEXT,
    ADD COLUMN IF NOT EXISTS payment_method TEXT,
    ADD COLUMN IF NOT EXISTS wants_invoice BOOLEAN,
    ADD COLUMN IF NOT EXISTS company_name TEXT,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS student_last_read_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS admin_last_read_at TIMESTAMPTZ;

ALTER TABLE app.online_course_enrollments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_online_course_enrollments ON app.online_course_enrollments;
CREATE POLICY student_select_own_online_course_enrollments
ON app.online_course_enrollments FOR SELECT
USING (student_id = auth.uid());

DROP POLICY IF EXISTS student_insert_own_online_course_enrollments ON app.online_course_enrollments;
CREATE POLICY student_insert_own_online_course_enrollments
ON app.online_course_enrollments FOR INSERT
WITH CHECK (student_id = auth.uid());

GRANT SELECT, INSERT ON app.online_course_enrollments TO authenticated;
GRANT ALL ON app.online_course_enrollments TO service_role;

-- ========================================
-- 4b) TABLE MESSAGES D'INSCRIPTION À UN COURS EN LIGNE
-- ========================================

CREATE TABLE IF NOT EXISTS app.online_course_enrollment_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enrollment_id UUID NOT NULL REFERENCES app.online_course_enrollments (id) ON DELETE CASCADE,
    sender_role TEXT NOT NULL,
    audience TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.online_course_enrollment_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_online_course_enrollment_messages ON app.online_course_enrollment_messages;
CREATE POLICY student_select_own_online_course_enrollment_messages
ON app.online_course_enrollment_messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.online_course_enrollments e
    WHERE e.id = online_course_enrollment_messages.enrollment_id
      AND e.student_id = auth.uid()
  )
);

DROP POLICY IF EXISTS student_insert_own_online_course_enrollment_messages ON app.online_course_enrollment_messages;
CREATE POLICY student_insert_own_online_course_enrollment_messages
ON app.online_course_enrollment_messages FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.online_course_enrollments e
    WHERE e.id = online_course_enrollment_messages.enrollment_id
      AND e.student_id = auth.uid()
  )
  AND sender_role = 'student'
);

GRANT SELECT, INSERT ON app.online_course_enrollment_messages TO authenticated;
GRANT ALL ON app.online_course_enrollment_messages TO service_role;

CREATE TABLE IF NOT EXISTS app.online_course_lesson_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enrollment_id UUID NOT NULL REFERENCES app.online_course_enrollments (id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES app.online_course_lessons (id) ON DELETE CASCADE,
    last_position_seconds INTEGER DEFAULT 0,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE (enrollment_id, lesson_id)
);

ALTER TABLE app.online_course_lesson_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_online_course_lesson_progress ON app.online_course_lesson_progress;
CREATE POLICY student_select_own_online_course_lesson_progress
ON app.online_course_lesson_progress FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.online_course_enrollments e
    WHERE e.id = online_course_lesson_progress.enrollment_id
      AND e.student_id = auth.uid()
  )
);

DROP POLICY IF EXISTS student_insert_own_online_course_lesson_progress ON app.online_course_lesson_progress;
CREATE POLICY student_insert_own_online_course_lesson_progress
ON app.online_course_lesson_progress FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.online_course_enrollments e
    WHERE e.id = online_course_lesson_progress.enrollment_id
      AND e.student_id = auth.uid()
  )
);

DROP POLICY IF EXISTS student_update_own_online_course_lesson_progress ON app.online_course_lesson_progress;
CREATE POLICY student_update_own_online_course_lesson_progress
ON app.online_course_lesson_progress FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM app.online_course_enrollments e
    WHERE e.id = online_course_lesson_progress.enrollment_id
      AND e.student_id = auth.uid()
  )
);

GRANT SELECT, INSERT, UPDATE ON app.online_course_lesson_progress TO authenticated;
GRANT ALL ON app.online_course_lesson_progress TO service_role;

-- ========================================
-- 5) LIVES / SESSIONS EN DIRECT
-- ========================================

CREATE TABLE IF NOT EXISTS app.online_course_live_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES app.online_courses (id) ON DELETE CASCADE,
    lesson_id UUID REFERENCES app.online_course_lessons (id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    provider TEXT, -- zoom, meet, webrtc...
    join_url TEXT,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ,
    replay_video_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.online_course_live_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_online_course_live_sessions ON app.online_course_live_sessions;
CREATE POLICY student_select_online_course_live_sessions
ON app.online_course_live_sessions FOR SELECT
USING (
  is_active = TRUE AND EXISTS (
    SELECT 1 FROM app.online_course_enrollments e
    WHERE e.course_id = online_course_live_sessions.course_id
      AND e.student_id = auth.uid()
  )
);

GRANT SELECT ON app.online_course_live_sessions TO authenticated;
GRANT ALL ON app.online_course_live_sessions TO service_role;

-- ========================================
-- 6) FORUMS & DISCUSSIONS
-- ========================================

CREATE TABLE IF NOT EXISTS app.online_course_forum_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES app.online_courses (id) ON DELETE CASCADE,
    student_id UUID REFERENCES app.students (id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.online_course_forum_threads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_online_course_forum_threads ON app.online_course_forum_threads;
CREATE POLICY student_select_online_course_forum_threads
ON app.online_course_forum_threads FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.online_course_enrollments e
    WHERE e.course_id = online_course_forum_threads.course_id
      AND e.student_id = auth.uid()
  )
);

DROP POLICY IF EXISTS student_insert_online_course_forum_threads ON app.online_course_forum_threads;
CREATE POLICY student_insert_online_course_forum_threads
ON app.online_course_forum_threads FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.online_course_enrollments e
    WHERE e.course_id = online_course_forum_threads.course_id
      AND e.student_id = auth.uid()
  )
);

DROP POLICY IF EXISTS instructor_select_online_course_forum_threads ON app.online_course_forum_threads;
CREATE POLICY instructor_select_online_course_forum_threads
ON app.online_course_forum_threads FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.online_course_instructors ci
    WHERE ci.course_id = online_course_forum_threads.course_id
      AND ci.instructor_id = auth.uid()
  )
);

DROP POLICY IF EXISTS instructor_insert_online_course_forum_threads ON app.online_course_forum_threads;
CREATE POLICY instructor_insert_online_course_forum_threads
ON app.online_course_forum_threads FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.online_course_instructors ci
    WHERE ci.course_id = online_course_forum_threads.course_id
      AND ci.instructor_id = auth.uid()
  )
);

GRANT SELECT, INSERT ON app.online_course_forum_threads TO authenticated;
GRANT ALL ON app.online_course_forum_threads TO service_role;

CREATE TABLE IF NOT EXISTS app.online_course_forum_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id UUID NOT NULL REFERENCES app.online_course_forum_threads (id) ON DELETE CASCADE,
    student_id UUID REFERENCES app.students (id) ON DELETE SET NULL,
    instructor_id UUID REFERENCES app.instructors (id) ON DELETE SET NULL,
    sender_role TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.online_course_forum_messages
  ADD COLUMN IF NOT EXISTS instructor_id UUID REFERENCES app.instructors (id) ON DELETE SET NULL;

ALTER TABLE app.online_course_forum_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_online_course_forum_messages ON app.online_course_forum_messages;
CREATE POLICY student_select_online_course_forum_messages
ON app.online_course_forum_messages FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM app.online_course_forum_threads t
    JOIN app.online_course_enrollments e ON e.course_id = t.course_id
    WHERE t.id = online_course_forum_messages.thread_id
      AND e.student_id = auth.uid()
  )
);

DROP POLICY IF EXISTS student_insert_online_course_forum_messages ON app.online_course_forum_messages;
CREATE POLICY student_insert_online_course_forum_messages
ON app.online_course_forum_messages FOR INSERT
WITH CHECK (
  sender_role = 'student' AND EXISTS (
    SELECT 1
    FROM app.online_course_forum_threads t
    JOIN app.online_course_enrollments e ON e.course_id = t.course_id
    WHERE t.id = online_course_forum_messages.thread_id
      AND e.student_id = auth.uid()
  )
);

GRANT SELECT, INSERT ON app.online_course_forum_messages TO authenticated;
GRANT ALL ON app.online_course_forum_messages TO service_role;

-- ========================================
-- 7) CERTIFICATS
-- ========================================

CREATE TABLE IF NOT EXISTS app.online_course_certificates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enrollment_id UUID NOT NULL REFERENCES app.online_course_enrollments (id) ON DELETE CASCADE,
    issued_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    verification_code TEXT NOT NULL,
    pdf_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.online_course_certificates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_online_course_certificates ON app.online_course_certificates;
CREATE POLICY student_select_own_online_course_certificates
ON app.online_course_certificates FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.online_course_enrollments e
    WHERE e.id = online_course_certificates.enrollment_id
      AND e.student_id = auth.uid()
  )
);

GRANT SELECT ON app.online_course_certificates TO authenticated;
GRANT ALL ON app.online_course_certificates TO service_role;

-- ========================================
-- 8) RPC PUBLIC - CATALOGUE COURS EN LIGNE
-- ========================================

CREATE OR REPLACE FUNCTION app_public_list_online_courses()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_courses JSONB;
BEGIN
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'title', c.title,
                'short_description', c.short_description,
                'category', c.category,
                'level', c.level,
                'language', c.language,
                'estimated_hours', c.estimated_hours,
                'cover_image_url', c.cover_image_url,
                'price', c.price,
                'contact_phone', c.contact_phone,
                'contact_whatsapp', c.contact_whatsapp,
                'contact_email', c.contact_email,
                'contact_website', c.contact_website,
                'contact_notes', c.contact_notes,
                'is_published', c.is_published,
                'created_at', c.created_at
            )
            ORDER BY c.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_courses
    FROM app.online_courses c
    WHERE c.is_published = TRUE;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'courses', v_courses
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_public_list_online_courses() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_public_list_online_courses() TO service_role;

CREATE OR REPLACE FUNCTION app_public_get_online_course_detail(
    p_course_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_course JSONB;
    v_sections JSONB;
BEGIN
    SELECT TO_JSONB(c)
    INTO v_course
    FROM app.online_courses c
    WHERE c.id = p_course_id
      AND c.is_published = TRUE;

    IF v_course IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'course_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', s.id,
                'title', s.title,
                'sort_order', s.sort_order,
                'lessons', COALESCE(
                    (
                        SELECT JSONB_AGG(
                                   JSONB_BUILD_OBJECT(
                                       'id', l.id,
                                       'title', l.title,
                                       'lesson_type', l.lesson_type,
                                       'sort_order', l.sort_order,
                                       'estimated_minutes', l.estimated_minutes
                                   )
                                   ORDER BY l.sort_order, l.created_at
                               )
                        FROM app.online_course_lessons l
                        WHERE l.section_id = s.id
                          AND l.is_published = TRUE
                    ),
                    '[]'::JSONB
                )
            )
            ORDER BY s.sort_order, s.created_at
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM app.online_course_sections s
    WHERE s.course_id = p_course_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'course', v_course,
        'sections', v_sections
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_public_get_online_course_detail(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_public_get_online_course_detail(UUID) TO service_role;

-- ========================================
-- 9) RPC ÉTUDIANT - MES COURS & PROGRESSION
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_my_online_courses()
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
                'enrollment_id', e.id,
                'course_id', c.id,
                'title', c.title,
                'short_description', c.short_description,
                'cover_image_url', c.cover_image_url,
                'category', c.category,
                'level', c.level,
                'language', c.language,
                'access_type', e.access_type,
                'starts_at', e.starts_at,
                'expires_at', e.expires_at,
                'last_message_at', e.last_message_at,
                'student_last_read_at', e.student_last_read_at,
                'admin_last_read_at', e.admin_last_read_at
            )
            ORDER BY e.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_enrollments e
    JOIN app.online_courses c ON c.id = e.course_id
    WHERE e.student_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'courses', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_my_online_courses() TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_my_online_courses() TO service_role;

CREATE OR REPLACE FUNCTION app_student_enroll_online_course(
    p_course_id UUID,
    p_access_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_student_id UUID;
    v_course_exists BOOLEAN;
    v_enrollment_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT id INTO v_student_id
    FROM app.students
    WHERE id = v_user_id;

    IF v_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'student_profile_not_found');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.online_courses c WHERE c.id = p_course_id AND c.is_published = TRUE)
    INTO v_course_exists;

    IF NOT v_course_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'course_not_found');
    END IF;

    INSERT INTO app.online_course_enrollments (course_id, student_id, access_type)
    VALUES (p_course_id, v_student_id, COALESCE(p_access_type, 'free'))
    ON CONFLICT (course_id, student_id) DO UPDATE
        SET updated_at = NOW()
    RETURNING id INTO v_enrollment_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'enrollment_id', v_enrollment_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_enroll_online_course(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_enroll_online_course(UUID, TEXT) TO service_role;

-- ========================================
-- 9.5) RPC ÉTUDIANT/ADMIN - MESSAGES D'INSCRIPTION COURS EN LIGNE
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_online_course_enrollment_messages(
    p_enrollment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_owner_id UUID;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT student_id
    INTO v_owner_id
    FROM app.online_course_enrollments
    WHERE id = p_enrollment_id;

    IF v_owner_id IS NULL OR v_owner_id <> v_user_id THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'enrollment_id', m.enrollment_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.online_course_enrollment_messages m
    WHERE m.enrollment_id = p_enrollment_id
      AND (m.sender_role = 'student' OR m.audience = 'student');

    UPDATE app.online_course_enrollments
    SET student_last_read_at = NOW()
    WHERE id = p_enrollment_id
      AND student_id = v_user_id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_online_course_enrollment_messages(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_online_course_enrollment_messages(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_student_add_online_course_enrollment_message(
    p_enrollment_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_owner_id UUID;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT student_id
    INTO v_owner_id
    FROM app.online_course_enrollments
    WHERE id = p_enrollment_id;

    IF v_owner_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'enrollment_not_found');
    END IF;

    IF v_owner_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    INSERT INTO app.online_course_enrollment_messages (enrollment_id, sender_role, audience, content)
    VALUES (p_enrollment_id, 'student', 'admin_only', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.online_course_enrollments
    SET last_message_at = NOW(), updated_at = NOW()
    WHERE id = p_enrollment_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_add_online_course_enrollment_message(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_add_online_course_enrollment_message(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_list_online_course_enrollment_messages(
    p_enrollment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_result JSONB;
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

    SELECT EXISTS(SELECT 1 FROM app.online_course_enrollments e WHERE e.id = p_enrollment_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'enrollment_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'enrollment_id', m.enrollment_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.online_course_enrollment_messages m
    WHERE m.enrollment_id = p_enrollment_id;

    UPDATE app.online_course_enrollments
    SET admin_last_read_at = NOW()
    WHERE id = p_enrollment_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'messages', v_result
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_online_course_enrollment_messages(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_online_course_enrollment_messages(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_add_online_course_enrollment_message_to_student(
    p_enrollment_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_message_id UUID;
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

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.online_course_enrollments e WHERE e.id = p_enrollment_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'enrollment_not_found');
    END IF;

    INSERT INTO app.online_course_enrollment_messages (enrollment_id, sender_role, audience, content)
    VALUES (p_enrollment_id, 'admin', 'student', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.online_course_enrollments
    SET last_message_at = NOW(), updated_at = NOW()
    WHERE id = p_enrollment_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_add_online_course_enrollment_message_to_student(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_add_online_course_enrollment_message_to_student(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_student_update_lesson_progress(
    p_lesson_id UUID,
    p_last_position_seconds INTEGER,
    p_completed BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_enrollment_id UUID;
    v_course_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT c.id, e.id
    INTO v_course_id, v_enrollment_id
    FROM app.online_course_lessons l
    JOIN app.online_course_sections s ON s.id = l.section_id
    JOIN app.online_courses c ON c.id = s.course_id
    JOIN app.online_course_enrollments e ON e.course_id = c.id
    WHERE l.id = p_lesson_id
      AND e.student_id = v_user_id
    LIMIT 1;

    IF v_enrollment_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_enrolled');
    END IF;

    INSERT INTO app.online_course_lesson_progress (
        enrollment_id,
        lesson_id,
        last_position_seconds,
        completed_at,
        updated_at
    )
    VALUES (
        v_enrollment_id,
        p_lesson_id,
        GREATEST(COALESCE(p_last_position_seconds, 0), 0),
        CASE WHEN p_completed THEN NOW() ELSE NULL END,
        NOW()
    )
    ON CONFLICT (enrollment_id, lesson_id) DO UPDATE
        SET last_position_seconds = EXCLUDED.last_position_seconds,
            completed_at = CASE WHEN EXCLUDED.completed_at IS NOT NULL THEN EXCLUDED.completed_at ELSE app.online_course_lesson_progress.completed_at END,
            updated_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_update_lesson_progress(UUID, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_update_lesson_progress(UUID, INTEGER, BOOLEAN) TO service_role;

-- ========================================
-- 10) RPC CERTIFICATS & FORUM - ÉTUDIANT
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_my_online_certificates()
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
                'certificate_id', c.id,
                'enrollment_id', c.enrollment_id,
                'issued_at', c.issued_at,
                'verification_code', c.verification_code,
                'pdf_url', c.pdf_url
            )
            ORDER BY c.issued_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_certificates c
    JOIN app.online_course_enrollments e ON e.id = c.enrollment_id
    WHERE e.student_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'certificates', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_my_online_certificates() TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_my_online_certificates() TO service_role;

-- ========================================
-- 11) RPC ADMIN - GESTION COURS EN LIGNE
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_online_courses()
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

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(c) ORDER BY c.created_at DESC),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_courses c;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'courses', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_online_courses() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_online_courses() TO service_role;

CREATE OR REPLACE FUNCTION app_admin_upsert_online_course(
    p_course_id UUID,
    p_title TEXT,
    p_short_description TEXT,
    p_full_description TEXT,
    p_category TEXT,
    p_level TEXT,
    p_language TEXT,
    p_estimated_hours INTEGER,
    p_cover_image_url TEXT,
    p_price NUMERIC,
    p_contact_phone TEXT,
    p_contact_whatsapp TEXT,
    p_contact_email TEXT,
    p_contact_website TEXT,
    p_contact_notes TEXT,
    p_is_published BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
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

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF p_course_id IS NULL THEN
        INSERT INTO app.online_courses (
            title,
            short_description,
            full_description,
            category,
            level,
            language,
            estimated_hours,
            cover_image_url,
            price,
            contact_phone,
            contact_whatsapp,
            contact_email,
            contact_website,
            contact_notes,
            is_published,
            created_by
        )
        VALUES (
            p_title,
            p_short_description,
            p_full_description,
            p_category,
            p_level,
            p_language,
            p_estimated_hours,
            p_cover_image_url,
            p_price,
            p_contact_phone,
            p_contact_whatsapp,
            p_contact_email,
            p_contact_website,
            p_contact_notes,
            COALESCE(p_is_published, FALSE),
            v_user_id
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.online_courses
        SET
            title = p_title,
            short_description = p_short_description,
            full_description = p_full_description,
            category = p_category,
            level = p_level,
            language = p_language,
            estimated_hours = p_estimated_hours,
            cover_image_url = p_cover_image_url,
            price = p_price,
            contact_phone = p_contact_phone,
            contact_whatsapp = p_contact_whatsapp,
            contact_email = p_contact_email,
            contact_website = p_contact_website,
            contact_notes = p_contact_notes,
            is_published = COALESCE(p_is_published, is_published),
            updated_at = NOW()
        WHERE id = p_course_id
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'course_not_saved');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'course_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_upsert_online_course(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_upsert_online_course(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_list_online_course_enrollments(
    p_course_id UUID
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

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_course_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'course_required');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'enrollment_id', e.id,
                'student_id', e.student_id,
                'access_type', e.access_type,
                'starts_at', e.starts_at,
                'expires_at', e.expires_at,
                'contact_phone', e.contact_phone,
                'preferred_channel', e.preferred_channel,
                'payment_method', e.payment_method,
                'wants_invoice', e.wants_invoice,
                'company_name', e.company_name,
                'notes', e.notes,
                'last_message_at', e.last_message_at,
                'student_last_read_at', e.student_last_read_at,
                'admin_last_read_at', e.admin_last_read_at,
                'student_full_name', s.full_name,
                'student_profile_phone', s.phone,
                'student_email', u.email
            )
            ORDER BY e.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_enrollments e
    LEFT JOIN app.students s ON s.id = e.student_id
    LEFT JOIN auth.users u ON u.id = e.student_id
    WHERE e.course_id = p_course_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'enrollments', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_online_course_enrollments(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_online_course_enrollments(UUID) TO service_role;

-- ========================================
-- 12) RPC ÉTUDIANT - LIVES & FORUM COURS EN LIGNE
-- ========================================

CREATE OR REPLACE FUNCTION app_student_list_online_course_live_sessions(
    p_course_id UUID
)
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
                'id', s.id,
                'course_id', s.course_id,
                'lesson_id', s.lesson_id,
                'title', s.title,
                'description', s.description,
                'provider', s.provider,
                'join_url', s.join_url,
                'start_at', s.start_at,
                'end_at', s.end_at,
                'replay_video_url', s.replay_video_url,
                'is_active', s.is_active
            )
            ORDER BY s.start_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_live_sessions s
    JOIN app.online_course_enrollments e ON e.course_id = s.course_id
    WHERE s.course_id = p_course_id
      AND s.is_active = TRUE
      AND e.student_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'sessions', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_online_course_live_sessions(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_online_course_live_sessions(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_student_list_online_course_forum_threads(
    p_course_id UUID
)
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
                'id', t.id,
                'course_id', t.course_id,
                'student_id', t.student_id,
                'title', t.title,
                'is_pinned', t.is_pinned,
                'created_at', t.created_at,
                'updated_at', t.updated_at
            )
            ORDER BY t.is_pinned DESC, t.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_forum_threads t
    JOIN app.online_course_enrollments e ON e.course_id = t.course_id
    WHERE t.course_id = p_course_id
      AND e.student_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'threads', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_online_course_forum_threads(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_online_course_forum_threads(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_student_create_online_course_forum_thread(
    p_course_id UUID,
    p_title TEXT,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_student_id UUID;
    v_thread_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT id INTO v_student_id
    FROM app.students
    WHERE id = v_user_id;

    IF v_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'student_profile_not_found');
    END IF;

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    INSERT INTO app.online_course_forum_threads (course_id, student_id, title)
    VALUES (p_course_id, v_student_id, p_title)
    RETURNING id INTO v_thread_id;

    INSERT INTO app.online_course_forum_messages (
        thread_id,
        student_id,
        sender_role,
        content
    )
    VALUES (
        v_thread_id,
        v_student_id,
        'student',
        p_content
    );

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'thread_id', v_thread_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_create_online_course_forum_thread(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_create_online_course_forum_thread(UUID, TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_student_list_online_course_forum_messages(
    p_thread_id UUID
)
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
                'id', m.id,
                'thread_id', m.thread_id,
                'student_id', m.student_id,
                'sender_role', m.sender_role,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_forum_messages m
    JOIN app.online_course_forum_threads t ON t.id = m.thread_id
    JOIN app.online_course_enrollments e ON e.course_id = t.course_id
    WHERE m.thread_id = p_thread_id
      AND e.student_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'messages', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_list_online_course_forum_messages(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_list_online_course_forum_messages(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_student_add_online_course_forum_message(
    p_thread_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_student_id UUID;
    v_thread_course_id UUID;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT id INTO v_student_id
    FROM app.students
    WHERE id = v_user_id;

    IF v_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'student_profile_not_found');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT course_id INTO v_thread_course_id
    FROM app.online_course_forum_threads
    WHERE id = p_thread_id;

    IF v_thread_course_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'thread_not_found');
    END IF;

    INSERT INTO app.online_course_forum_messages (
        thread_id,
        student_id,
        sender_role,
        content
    )
    VALUES (
        p_thread_id,
        v_student_id,
        'student',
        p_content
    )
    RETURNING id INTO v_message_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'message_id', v_message_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_add_online_course_forum_message(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_add_online_course_forum_message(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_ci_list_online_course_forum_threads(
    p_course_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_is_instructor_course BOOLEAN;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'instructor' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.online_course_instructors ci
        WHERE ci.course_id = p_course_id
          AND ci.instructor_id = v_user_id
    ) INTO v_is_instructor_course;

    IF NOT v_is_instructor_course THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_course_instructor');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', t.id,
                'course_id', t.course_id,
                'student_id', t.student_id,
                'title', t.title,
                'is_pinned', t.is_pinned,
                'created_at', t.created_at,
                'updated_at', t.updated_at
            )
            ORDER BY t.is_pinned DESC, t.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_forum_threads t
    WHERE t.course_id = p_course_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'threads', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_list_online_course_forum_threads(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_list_online_course_forum_threads(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_ci_create_online_course_forum_thread(
    p_course_id UUID,
    p_title TEXT,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_is_instructor_course BOOLEAN;
    v_thread_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'instructor' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.online_course_instructors ci
        WHERE ci.course_id = p_course_id
          AND ci.instructor_id = v_user_id
    ) INTO v_is_instructor_course;

    IF NOT v_is_instructor_course THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_course_instructor');
    END IF;

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    INSERT INTO app.online_course_forum_threads (course_id, student_id, title)
    VALUES (p_course_id, NULL, p_title)
    RETURNING id INTO v_thread_id;

    INSERT INTO app.online_course_forum_messages (
        thread_id,
        student_id,
        instructor_id,
        sender_role,
        content
    )
    VALUES (
        v_thread_id,
        NULL,
        v_user_id,
        'instructor',
        p_content
    );

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'thread_id', v_thread_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_create_online_course_forum_thread(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_create_online_course_forum_thread(UUID, TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_ci_list_online_course_forum_messages(
    p_thread_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_is_instructor_thread BOOLEAN;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'instructor' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.online_course_forum_threads t
        JOIN app.online_course_instructors ci ON ci.course_id = t.course_id
        WHERE t.id = p_thread_id
          AND ci.instructor_id = v_user_id
    ) INTO v_is_instructor_thread;

    IF NOT v_is_instructor_thread THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_course_instructor');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'thread_id', m.thread_id,
                'student_id', m.student_id,
                'instructor_id', m.instructor_id,
                'sender_role', m.sender_role,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_forum_messages m
    WHERE m.thread_id = p_thread_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'messages', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_list_online_course_forum_messages(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_list_online_course_forum_messages(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_ci_add_online_course_forum_message(
    p_thread_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_thread_course_id UUID;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'instructor' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT course_id INTO v_thread_course_id
    FROM app.online_course_forum_threads
    WHERE id = p_thread_id;

    IF v_thread_course_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'thread_not_found');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM app.online_course_instructors ci
        WHERE ci.course_id = v_thread_course_id
          AND ci.instructor_id = v_user_id
    ) THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_course_instructor');
    END IF;

    INSERT INTO app.online_course_forum_messages (
        thread_id,
        student_id,
        instructor_id,
        sender_role,
        content
    )
    VALUES (
        p_thread_id,
        NULL,
        v_user_id,
        'instructor',
        p_content
    )
    RETURNING id INTO v_message_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'message_id', v_message_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_add_online_course_forum_message(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_add_online_course_forum_message(UUID, TEXT) TO service_role;

-- ========================================
-- 13) RÔLE ENSEIGNANT (CI) & RPC ASSOCIÉES
-- ========================================

-- 13.1) Profil enseignant

CREATE TABLE IF NOT EXISTS app.instructors (
    id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    full_name TEXT,
    bio TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.instructors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS instructor_select_self ON app.instructors;
CREATE POLICY instructor_select_self
ON app.instructors FOR SELECT
USING (id = auth.uid());

DROP POLICY IF EXISTS instructor_insert_self ON app.instructors;
CREATE POLICY instructor_insert_self
ON app.instructors FOR INSERT
WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS instructor_update_self ON app.instructors;
CREATE POLICY instructor_update_self
ON app.instructors FOR UPDATE
USING (id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON app.instructors TO authenticated;
GRANT ALL ON app.instructors TO service_role;

-- 13.2) Association cours ↔ enseignants

CREATE TABLE IF NOT EXISTS app.online_course_instructors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES app.online_courses (id) ON DELETE CASCADE,
    instructor_id UUID NOT NULL REFERENCES app.instructors (id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'owner', -- owner, assistant, guest
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE (course_id, instructor_id)
);

ALTER TABLE app.online_course_instructors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS instructor_select_own_course_links ON app.online_course_instructors;
CREATE POLICY instructor_select_own_course_links
ON app.online_course_instructors FOR SELECT
USING (instructor_id = auth.uid());

DROP POLICY IF EXISTS instructor_insert_own_course_links ON app.online_course_instructors;
CREATE POLICY instructor_insert_own_course_links
ON app.online_course_instructors FOR INSERT
WITH CHECK (instructor_id = auth.uid());

DROP POLICY IF EXISTS instructor_update_own_course_links ON app.online_course_instructors;
CREATE POLICY instructor_update_own_course_links
ON app.online_course_instructors FOR UPDATE
USING (instructor_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON app.online_course_instructors TO authenticated;
GRANT ALL ON app.online_course_instructors TO service_role;

-- 13.3) RPC CI - S'assurer du profil enseignant

CREATE OR REPLACE FUNCTION app_ci_ensure_instructor_profile()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    INSERT INTO app.instructors (id, full_name)
    VALUES (v_user_id, NULL)
    ON CONFLICT (id) DO UPDATE
        SET updated_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_ensure_instructor_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_ensure_instructor_profile() TO service_role;

-- 13.4) RPC CI - Lister les cours en ligne d'un enseignant

CREATE OR REPLACE FUNCTION app_ci_list_my_online_courses()
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

    IF v_role <> 'instructor' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
    END IF;

    PERFORM app_ci_ensure_instructor_profile();

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'title', c.title,
                'short_description', c.short_description,
                'full_description', c.full_description,
                'category', c.category,
                'level', c.level,
                'language', c.language,
                'estimated_hours', c.estimated_hours,
                'cover_image_url', c.cover_image_url,
                'price', c.price,
                'contact_phone', c.contact_phone,
                'contact_whatsapp', c.contact_whatsapp,
                'contact_email', c.contact_email,
                'contact_website', c.contact_website,
                'contact_notes', c.contact_notes,
                'is_published', c.is_published,
                'created_at', c.created_at,
                'updated_at', c.updated_at,
                'instructor_role', ci.role
            )
            ORDER BY c.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_courses c
    JOIN app.online_course_instructors ci ON ci.course_id = c.id
    WHERE ci.instructor_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'courses', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_list_my_online_courses() TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_list_my_online_courses() TO service_role;

-- 13.5) RPC CI - Créer / modifier un cours en ligne

CREATE OR REPLACE FUNCTION app_ci_upsert_online_course(
    p_course_id UUID,
    p_title TEXT,
    p_short_description TEXT,
    p_full_description TEXT,
    p_category TEXT,
    p_level TEXT,
    p_language TEXT,
    p_estimated_hours INTEGER,
    p_cover_image_url TEXT,
    p_price NUMERIC,
    p_contact_phone TEXT,
    p_contact_whatsapp TEXT,
    p_contact_email TEXT,
    p_contact_website TEXT,
    p_contact_notes TEXT,
    p_is_published BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'instructor' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
    END IF;

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    PERFORM app_ci_ensure_instructor_profile();

    IF p_course_id IS NULL THEN
        INSERT INTO app.online_courses (
            title,
            short_description,
            full_description,
            category,
            level,
            language,
            estimated_hours,
            cover_image_url,
            price,
            contact_phone,
            contact_whatsapp,
            contact_email,
            contact_website,
            contact_notes,
            is_published,
            created_by
        )
        VALUES (
            p_title,
            p_short_description,
            p_full_description,
            p_category,
            p_level,
            p_language,
            p_estimated_hours,
            p_cover_image_url,
            p_price,
            p_contact_phone,
            p_contact_whatsapp,
            p_contact_email,
            p_contact_website,
            p_contact_notes,
            COALESCE(p_is_published, FALSE),
            v_user_id
        )
        RETURNING id INTO v_id;

        INSERT INTO app.online_course_instructors (course_id, instructor_id, role)
        VALUES (v_id, v_user_id, 'owner')
        ON CONFLICT (course_id, instructor_id) DO UPDATE
            SET updated_at = NOW();
    ELSE
        UPDATE app.online_courses c
        SET
            title = p_title,
            short_description = p_short_description,
            full_description = p_full_description,
            category = p_category,
            level = p_level,
            language = p_language,
            estimated_hours = p_estimated_hours,
            cover_image_url = p_cover_image_url,
            price = p_price,
            contact_phone = p_contact_phone,
            contact_whatsapp = p_contact_whatsapp,
            contact_email = p_contact_email,
            contact_website = p_contact_website,
            contact_notes = p_contact_notes,
            is_published = COALESCE(p_is_published, is_published),
            updated_at = NOW()
        WHERE c.id = p_course_id
          AND EXISTS (
            SELECT 1 FROM app.online_course_instructors ci
            WHERE ci.course_id = c.id
              AND ci.instructor_id = v_user_id
          )
        RETURNING id INTO v_id;
    END IF;

    IF v_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'course_not_saved_or_not_owned');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'course_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_upsert_online_course(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_upsert_online_course(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO service_role;

-- 13.6) RPC CI - Sessions live de l'enseignant

CREATE OR REPLACE FUNCTION app_ci_list_my_online_course_live_sessions()
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

    IF v_role <> 'instructor' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', s.id,
                'course_id', s.course_id,
                'lesson_id', s.lesson_id,
                'title', s.title,
                'description', s.description,
                'provider', s.provider,
                'join_url', s.join_url,
                'start_at', s.start_at,
                'end_at', s.end_at,
                'replay_video_url', s.replay_video_url,
                'is_active', s.is_active,
                'course_title', c.title
            )
            ORDER BY s.start_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.online_course_live_sessions s
    JOIN app.online_course_instructors ci ON ci.course_id = s.course_id
    JOIN app.online_courses c ON c.id = s.course_id
    WHERE ci.instructor_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'sessions', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_list_my_online_course_live_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_list_my_online_course_live_sessions() TO service_role;

CREATE OR REPLACE FUNCTION app_ci_upsert_online_course_live_session(
    p_session_id UUID,
    p_course_id UUID,
    p_lesson_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_provider TEXT,
    p_join_url TEXT,
    p_start_at TIMESTAMPTZ,
    p_end_at TIMESTAMPTZ,
    p_replay_video_url TEXT,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_session_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'instructor' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_instructor');
    END IF;

    IF p_course_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_course_id');
    END IF;

    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_title');
    END IF;

    IF p_start_at IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_start_at');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM app.online_course_instructors ci
        WHERE ci.course_id = p_course_id
          AND ci.instructor_id = v_user_id
    ) THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_course_instructor');
    END IF;

    IF p_session_id IS NULL THEN
        INSERT INTO app.online_course_live_sessions (
            course_id,
            lesson_id,
            title,
            description,
            provider,
            join_url,
            start_at,
            end_at,
            replay_video_url,
            is_active
        )
        VALUES (
            p_course_id,
            p_lesson_id,
            p_title,
            p_description,
            p_provider,
            p_join_url,
            p_start_at,
            p_end_at,
            p_replay_video_url,
            COALESCE(p_is_active, TRUE)
        )
        RETURNING id INTO v_session_id;
    ELSE
        UPDATE app.online_course_live_sessions s
        SET
            title = p_title,
            description = p_description,
            provider = p_provider,
            join_url = p_join_url,
            start_at = p_start_at,
            end_at = p_end_at,
            replay_video_url = p_replay_video_url,
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE s.id = p_session_id
          AND s.course_id = p_course_id
          AND EXISTS (
            SELECT 1 FROM app.online_course_instructors ci
            WHERE ci.course_id = s.course_id
              AND ci.instructor_id = v_user_id
          )
        RETURNING id INTO v_session_id;
    END IF;

    IF v_session_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_saved_or_not_owned');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'session_id', v_session_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_ci_upsert_online_course_live_session(UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_ci_upsert_online_course_live_session(UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, BOOLEAN) TO service_role;
