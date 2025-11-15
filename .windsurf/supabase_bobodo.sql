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

-- ========================================
-- 8) VALIDATION DU MODULE BOBODO
-- ========================================

SELECT
  'bobodo_module_status' AS check_name,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_sessions')) AS bobodo_sessions_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_messages')) AS bobodo_messages_table_exists,
  (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_knowledge')) AS bobodo_knowledge_table_exists;
