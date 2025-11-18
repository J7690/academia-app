-- ========================================
-- ACADEMIA - MODULE BOBODO (ASSISTANT IA)
-- Tables app.bobodo_sessions, app.bobodo_messages, app.bobodo_knowledge
-- + RPC pour gérer les sessions et messages côté Supabase
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) TABLE SESSIONS BOBODO
-- ========================================

CREATE TABLE IF NOT EXISTS app.bobodo_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    title TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.bobodo_sessions ENABLE ROW LEVEL SECURITY;

-- Un étudiant ne voit que ses propres sessions
DROP POLICY IF EXISTS student_select_own_bobodo_sessions ON app.bobodo_sessions;
CREATE POLICY student_select_own_bobodo_sessions
ON app.bobodo_sessions FOR SELECT
USING (student_id = auth.uid());

DROP POLICY IF EXISTS student_insert_own_bobodo_sessions ON app.bobodo_sessions;
CREATE POLICY student_insert_own_bobodo_sessions
ON app.bobodo_sessions FOR INSERT
WITH CHECK (student_id = auth.uid());

GRANT SELECT, INSERT ON app.bobodo_sessions TO authenticated;
GRANT ALL ON app.bobodo_sessions TO service_role;

-- ========================================
-- 2) TABLE MESSAGES BOBODO
-- ========================================

CREATE TABLE IF NOT EXISTS app.bobodo_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES app.bobodo_sessions (id) ON DELETE CASCADE,
    sender TEXT NOT NULL,           -- 'student' ou 'ai' ou 'system'
    content TEXT NOT NULL,
    safety_flag TEXT,               -- ex: 'safe', 'blocked', 'warning'
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.bobodo_messages ENABLE ROW LEVEL SECURITY;

-- Un étudiant ne voit que les messages de ses sessions
DROP POLICY IF EXISTS student_select_own_bobodo_messages ON app.bobodo_messages;
CREATE POLICY student_select_own_bobodo_messages
ON app.bobodo_messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.bobodo_sessions s
    WHERE s.id = app.bobodo_messages.session_id
      AND s.student_id = auth.uid()
  )
);

-- Insertion de messages par l'étudiant ou par le backend IA (via service_role)
DROP POLICY IF EXISTS student_insert_own_bobodo_messages ON app.bobodo_messages;
CREATE POLICY student_insert_own_bobodo_messages
ON app.bobodo_messages FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.bobodo_sessions s
    WHERE s.id = app.bobodo_messages.session_id
      AND s.student_id = auth.uid()
  )
);

GRANT SELECT, INSERT ON app.bobodo_messages TO authenticated;
GRANT ALL ON app.bobodo_messages TO service_role;

-- ========================================
-- 3) TABLE CONNAISSANCE INTERNE BOBODO
-- ========================================

CREATE TABLE IF NOT EXISTS app.bobodo_knowledge (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL,                -- 'academia', 'nexiom', 'process', etc.
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT[],                           -- tags pour filtrage
    language TEXT DEFAULT 'fr',
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.bobodo_knowledge ENABLE ROW LEVEL SECURITY;

-- Lecture globale des connaissances actives pour les rôles internes et l'assistant
DROP POLICY IF EXISTS public_select_active_bobodo_knowledge ON app.bobodo_knowledge;
CREATE POLICY public_select_active_bobodo_knowledge
ON app.bobodo_knowledge FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.bobodo_knowledge TO authenticated;
GRANT ALL ON app.bobodo_knowledge TO service_role;

-- ========================================
-- 4) RPC - CRÉER UNE SESSION BOBODO POUR L'ÉTUDIANT COURANT
-- ========================================

CREATE OR REPLACE FUNCTION app_create_bobodo_session(
    p_title TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID;
BEGIN
    INSERT INTO app.bobodo_sessions (student_id, title)
    VALUES (auth.uid(), p_title)
    RETURNING id INTO v_session_id;

    RETURN v_session_id;
END;
$$;

GRANT EXECUTE ON FUNCTION app_create_bobodo_session(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_create_bobodo_session(TEXT) TO service_role;

-- ========================================
-- 5) RPC - LISTE DES MESSAGES D'UNE SESSION
-- ========================================

CREATE OR REPLACE FUNCTION app_list_bobodo_messages(
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'sender', m.sender,
                'content', m.content,
                'safety_flag', m.safety_flag,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.bobodo_messages m
    JOIN app.bobodo_sessions s ON s.id = m.session_id
    WHERE m.session_id = p_session_id
      AND s.student_id = auth.uid();

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_list_bobodo_messages(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_list_bobodo_messages(UUID) TO service_role;

-- ========================================
-- 6) RPC - ENREGISTRER UN MESSAGE DANS UNE SESSION
-- ========================================

CREATE OR REPLACE FUNCTION app_append_bobodo_message(
    p_session_id UUID,
    p_sender TEXT,
    p_content TEXT,
    p_safety_flag TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_message_id UUID;
BEGIN
    INSERT INTO app.bobodo_messages (session_id, sender, content, safety_flag)
    VALUES (p_session_id, p_sender, p_content, p_safety_flag)
    RETURNING id INTO v_message_id;

    RETURN v_message_id;
END;
$$;

GRANT EXECUTE ON FUNCTION app_append_bobodo_message(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_append_bobodo_message(UUID, TEXT, TEXT, TEXT) TO service_role;

-- ========================================
-- 7) RPC - RECHERCHE SIMPLE DANS LA BASE DE CONNAISSANCE
-- (le backend IA peut l'utiliser pour construire le contexte)
-- ========================================

CREATE OR REPLACE FUNCTION app_search_bobodo_knowledge(
    p_query TEXT,
    p_category TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', k.id,
                'category', k.category,
                'title', k.title,
                'content', k.content,
                'tags', k.tags,
                'language', k.language
            )
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.bobodo_knowledge k
    WHERE k.is_active = TRUE
      AND (
        p_query IS NULL
        OR k.title ILIKE '%' || p_query || '%'
        OR k.content ILIKE '%' || p_query || '%'
      )
      AND (
        p_category IS NULL
        OR k.category = p_category
      );

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_search_bobodo_knowledge(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_search_bobodo_knowledge(TEXT, TEXT) TO service_role;

CREATE TABLE IF NOT EXISTS app.bobodo_unanswered_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES app.bobodo_sessions (id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    category TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'new',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.bobodo_unanswered_questions ENABLE ROW LEVEL SECURITY;

GRANT ALL ON app.bobodo_unanswered_questions TO service_role;


CREATE OR REPLACE FUNCTION app_log_bobodo_unanswered_question(
    p_session_id UUID,
    p_question_text TEXT,
    p_category TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO app.bobodo_unanswered_questions (session_id, question_text, category)
    VALUES (p_session_id, p_question_text, p_category);
END;
$$;

GRANT EXECUTE ON FUNCTION app_log_bobodo_unanswered_question(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_log_bobodo_unanswered_question(UUID, TEXT, TEXT) TO service_role;

-- ========================================
-- 8) RPC ADMIN - LECTURE DES QUESTIONS ET CONVERSATIONS BOBODO
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_bobodo_unanswered_questions(
    p_status TEXT DEFAULT NULL
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
        RETURN '[]'::JSONB;
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', q.id,
                'session_id', q.session_id,
                'question_text', q.question_text,
                'category', q.category,
                'status', q.status,
                'created_at', q.created_at
            )
            ORDER BY q.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.bobodo_unanswered_questions q
    WHERE p_status IS NULL OR q.status = p_status;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_bobodo_unanswered_questions(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_bobodo_unanswered_questions(TEXT) TO service_role;


CREATE OR REPLACE FUNCTION app_admin_list_bobodo_sessions(
    p_student_id UUID DEFAULT NULL
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
        RETURN '[]'::JSONB;
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', s.id,
                'student_id', s.student_id,
                'student_full_name', st.full_name,
                'title', s.title,
                'created_at', s.created_at,
                'updated_at', s.updated_at
            )
            ORDER BY s.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.bobodo_sessions s
    JOIN app.students st ON st.id = s.student_id
    WHERE p_student_id IS NULL OR s.student_id = p_student_id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_bobodo_sessions(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_bobodo_sessions(UUID) TO service_role;


CREATE OR REPLACE FUNCTION app_admin_list_bobodo_messages(
    p_session_id UUID
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
        RETURN '[]'::JSONB;
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'session_id', m.session_id,
                'sender', m.sender,
                'content', m.content,
                'safety_flag', m.safety_flag,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.bobodo_messages m
    WHERE m.session_id = p_session_id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_bobodo_messages(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_bobodo_messages(UUID) TO service_role;


-- ========================================
-- 9) TABLE BESOINS DÉTECTÉS PAR BOBODO
-- ========================================

CREATE TABLE IF NOT EXISTS app.bobodo_detected_needs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES app.bobodo_sessions (id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    category TEXT NOT NULL,
    need_summary TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.bobodo_detected_needs ENABLE ROW LEVEL SECURITY;

GRANT ALL ON app.bobodo_detected_needs TO service_role;


CREATE OR REPLACE FUNCTION app_log_bobodo_detected_need(
    p_session_id UUID,
    p_question_text TEXT,
    p_category TEXT,
    p_need_summary TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_summary TEXT;
BEGIN
    v_summary := NULLIF(TRIM(p_need_summary), '');
    IF v_summary IS NULL THEN
        v_summary := p_question_text;
    END IF;

    INSERT INTO app.bobodo_detected_needs (session_id, question_text, category, need_summary)
    VALUES (p_session_id, p_question_text, p_category, v_summary);
END;
$$;

GRANT EXECUTE ON FUNCTION app_log_bobodo_detected_need(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_log_bobodo_detected_need(UUID, TEXT, TEXT, TEXT) TO service_role;


-- ========================================
-- 10) RPC ADMIN - LECTURE DES BESOINS DÉTECTÉS
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_list_bobodo_detected_needs(
    p_student_id UUID DEFAULT NULL
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
        RETURN '[]'::JSONB;
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', n.id,
                'session_id', n.session_id,
                'student_id', s.student_id,
                'student_full_name', st.full_name,
                'question_text', n.question_text,
                'category', n.category,
                'need_summary', n.need_summary,
                'created_at', n.created_at
            )
            ORDER BY n.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.bobodo_detected_needs n
    JOIN app.bobodo_sessions s ON s.id = n.session_id
    JOIN app.students st ON st.id = s.student_id
    WHERE p_student_id IS NULL OR s.student_id = p_student_id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_bobodo_detected_needs(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_bobodo_detected_needs(UUID) TO service_role;


-- ========================================
-- 11) TABLE FEEDBACK BOBODO
-- ========================================

CREATE TABLE IF NOT EXISTS app.bobodo_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES app.bobodo_sessions (id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES app.bobodo_messages (id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    rating TEXT NOT NULL CHECK (rating IN ('up','down')),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.bobodo_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_bobodo_feedback ON app.bobodo_feedback;
CREATE POLICY student_select_own_bobodo_feedback
ON app.bobodo_feedback FOR SELECT
USING (student_id = auth.uid());

DROP POLICY IF EXISTS student_insert_own_bobodo_feedback ON app.bobodo_feedback;
CREATE POLICY student_insert_own_bobodo_feedback
ON app.bobodo_feedback FOR INSERT
WITH CHECK (student_id = auth.uid());

GRANT SELECT, INSERT ON app.bobodo_feedback TO authenticated;
GRANT ALL ON app.bobodo_feedback TO service_role;


CREATE OR REPLACE FUNCTION app_add_bobodo_feedback(
    p_session_id UUID,
    p_message_id UUID,
    p_rating TEXT,
    p_comment TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_student_id UUID;
    v_feedback_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_rating NOT IN ('up','down') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_rating');
    END IF;

    SELECT student_id INTO v_student_id
    FROM app.bobodo_sessions
    WHERE id = p_session_id;

    IF v_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'session_not_found');
    END IF;

    IF v_student_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    INSERT INTO app.bobodo_feedback (session_id, message_id, student_id, rating, comment)
    VALUES (
        p_session_id,
        p_message_id,
        v_student_id,
        p_rating,
        NULLIF(TRIM(p_comment), '')
    )
    RETURNING id INTO v_feedback_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'feedback_id', v_feedback_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_add_bobodo_feedback(UUID, UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_add_bobodo_feedback(UUID, UUID, TEXT, TEXT) TO service_role;


-- ========================================
-- 12) VALIDATION DU MODULE BOBODO
-- ========================================

SELECT
  'bobodo_module_status' AS check_name,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_sessions')) AS bobodo_sessions_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_messages')) AS bobodo_messages_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_knowledge')) AS bobodo_knowledge_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_unanswered_questions')) AS bobodo_unanswered_questions_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_detected_needs')) AS bobodo_detected_needs_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_feedback')) AS bobodo_feedback_table_exists;
