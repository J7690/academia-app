-- ============================================================================
-- PHASE 2: Unification du module Préparation Concours
-- Date: 2026-03-15
-- Objectif: Ajouter les tables manquantes dans prep_*, réécrire les RPCs
--           pour que admin/enseignant/étudiant utilisent le MÊME système.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- PARTIE A: Nouvelles tables prep_* (équivalents des td_* manquants)
-- ─────────────────────────────────────────────────────────────────────────────

-- A1: Banques de questions
CREATE TABLE IF NOT EXISTS app.prep_question_banks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    concours_type TEXT,
    subject TEXT,
    created_by UUID REFERENCES auth.users(id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A2: Sujets d'épreuve (exam papers)
CREATE TABLE IF NOT EXISTS app.prep_exam_papers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    concours_type TEXT NOT NULL,
    year TEXT,
    subject TEXT,
    paper_url TEXT,
    correction_url TEXT,
    difficulty INTEGER DEFAULT 1,
    is_official BOOLEAN NOT NULL DEFAULT false,
    has_correction BOOLEAN NOT NULL DEFAULT false,
    uploaded_by UUID REFERENCES auth.users(id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A3: Flashcard decks
CREATE TABLE IF NOT EXISTS app.prep_flashcard_decks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    subject TEXT,
    concours_type TEXT,
    card_count INTEGER NOT NULL DEFAULT 0,
    created_by UUID REFERENCES auth.users(id),
    is_public BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A4: Flashcards individuelles
CREATE TABLE IF NOT EXISTS app.prep_flashcards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deck_id UUID NOT NULL REFERENCES app.prep_flashcard_decks(id) ON DELETE CASCADE,
    front_text TEXT NOT NULL,
    back_text TEXT NOT NULL,
    subject TEXT,
    tags TEXT[] DEFAULT '{}',
    image_url TEXT,
    created_by UUID REFERENCES auth.users(id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A5: Progression flashcards par étudiant
CREATE TABLE IF NOT EXISTS app.prep_flashcard_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flashcard_id UUID NOT NULL REFERENCES app.prep_flashcards(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES auth.users(id),
    ease_factor NUMERIC(4,2) NOT NULL DEFAULT 2.50,
    interval_days INTEGER NOT NULL DEFAULT 1,
    repetitions INTEGER NOT NULL DEFAULT 0,
    next_review_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_reviewed_at TIMESTAMPTZ,
    quality_history INTEGER[] DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (flashcard_id, student_id)
);

-- A6: Quiz templates
CREATE TABLE IF NOT EXISTS app.prep_quiz_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    bank_id UUID REFERENCES app.prep_question_banks(id),
    concours_type TEXT,
    subject TEXT,
    question_count INTEGER NOT NULL DEFAULT 10,
    time_limit_minutes INTEGER,
    shuffle_questions BOOLEAN NOT NULL DEFAULT true,
    is_exam_mode BOOLEAN NOT NULL DEFAULT false,
    passing_score INTEGER NOT NULL DEFAULT 60,
    created_by UUID REFERENCES auth.users(id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A7: Quiz attempts (complet, pas juste prep_attempts)
CREATE TABLE IF NOT EXISTS app.prep_quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID REFERENCES app.prep_quiz_templates(id),
    student_id UUID NOT NULL REFERENCES auth.users(id),
    questions_json JSONB,
    answers_json JSONB,
    score INTEGER NOT NULL DEFAULT 0,
    total_points INTEGER NOT NULL DEFAULT 0,
    correct_count INTEGER NOT NULL DEFAULT 0,
    question_count INTEGER NOT NULL DEFAULT 0,
    time_spent_seconds INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'completed',
    started_at TIMESTAMPTZ DEFAULT now(),
    finished_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A8: Badges
CREATE TABLE IF NOT EXISTS app.prep_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT,
    emoji TEXT DEFAULT '🏅',
    xp_reward INTEGER NOT NULL DEFAULT 0,
    condition_type TEXT,
    condition_value INTEGER DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A9: Badges obtenus par étudiant
CREATE TABLE IF NOT EXISTS app.prep_student_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id),
    badge_id UUID NOT NULL REFERENCES app.prep_badges(id),
    earned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (student_id, badge_id)
);

-- A10: Conversations IA
CREATE TABLE IF NOT EXISTS app.prep_ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id),
    title TEXT,
    subject TEXT,
    message_count INTEGER NOT NULL DEFAULT 0,
    total_tokens_used INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A11: Messages IA
CREATE TABLE IF NOT EXISTS app.prep_ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES app.prep_ai_conversations(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'user',
    content TEXT NOT NULL,
    tokens_used INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A12: Config IA
CREATE TABLE IF NOT EXISTS app.prep_ai_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key TEXT NOT NULL UNIQUE,
    config_value TEXT,
    description TEXT,
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A13: Gamification — XP et Streaks (nouveau)
CREATE TABLE IF NOT EXISTS app.prep_student_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id) UNIQUE,
    total_xp INTEGER NOT NULL DEFAULT 0,
    current_streak INTEGER NOT NULL DEFAULT 0,
    longest_streak INTEGER NOT NULL DEFAULT 0,
    total_correct INTEGER NOT NULL DEFAULT 0,
    total_answered INTEGER NOT NULL DEFAULT 0,
    last_activity_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A14: Colonne bank_id dans prep_questions (lien vers banques)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'bank_id'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN bank_id UUID REFERENCES app.prep_question_banks(id);
    END IF;
END $$;

-- A15: Colonnes manquantes dans prep_questions pour compatibilité enseignant
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'content'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN content TEXT;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'options'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN options JSONB;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'correct_index'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN correct_index INTEGER;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'difficulty'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN difficulty INTEGER DEFAULT 1;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'subject'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN subject TEXT;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'tags'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN tags TEXT[] DEFAULT '{}';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'points'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN points INTEGER DEFAULT 10;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'time_limit_seconds'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN time_limit_seconds INTEGER DEFAULT 60;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'image_url'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN image_url TEXT;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'is_active'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN is_active BOOLEAN DEFAULT true;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'prep_questions' AND column_name = 'concours_type'
    ) THEN
        ALTER TABLE app.prep_questions ADD COLUMN concours_type TEXT;
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PARTIE B: RLS pour les nouvelles tables
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE app.prep_question_banks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_exam_papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_flashcard_decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_flashcard_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_quiz_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_student_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_ai_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_student_progress ENABLE ROW LEVEL SECURITY;

-- Service role full access (pour les RPCs SECURITY DEFINER)
CREATE POLICY IF NOT EXISTS sr_all_prep_question_banks ON app.prep_question_banks FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_exam_papers ON app.prep_exam_papers FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_flashcard_decks ON app.prep_flashcard_decks FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_flashcards ON app.prep_flashcards FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_flashcard_progress ON app.prep_flashcard_progress FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_quiz_templates ON app.prep_quiz_templates FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_quiz_attempts ON app.prep_quiz_attempts FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_badges ON app.prep_badges FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_student_badges ON app.prep_student_badges FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_ai_conversations ON app.prep_ai_conversations FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_ai_messages ON app.prep_ai_messages FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_ai_config ON app.prep_ai_config FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS sr_all_prep_student_progress ON app.prep_student_progress FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Authenticated read policies (with entitlement check)
CREATE POLICY IF NOT EXISTS auth_select_prep_question_banks ON app.prep_question_banks FOR SELECT USING (is_active = true AND app_has_feature_access('prep_concours'));
CREATE POLICY IF NOT EXISTS auth_select_prep_exam_papers ON app.prep_exam_papers FOR SELECT USING (is_active = true AND app_has_feature_access('prep_concours'));
CREATE POLICY IF NOT EXISTS auth_select_prep_flashcard_decks ON app.prep_flashcard_decks FOR SELECT USING (is_active = true AND app_has_feature_access('prep_concours'));
CREATE POLICY IF NOT EXISTS auth_select_prep_flashcards ON app.prep_flashcards FOR SELECT USING (is_active = true AND app_has_feature_access('prep_concours'));
CREATE POLICY IF NOT EXISTS auth_select_own_prep_flashcard_progress ON app.prep_flashcard_progress FOR SELECT USING (student_id = auth.uid() AND app_has_feature_access('prep_concours'));
CREATE POLICY IF NOT EXISTS auth_insert_own_prep_flashcard_progress ON app.prep_flashcard_progress FOR INSERT WITH CHECK (student_id = auth.uid());
CREATE POLICY IF NOT EXISTS auth_update_own_prep_flashcard_progress ON app.prep_flashcard_progress FOR UPDATE USING (student_id = auth.uid());
CREATE POLICY IF NOT EXISTS auth_select_prep_quiz_templates ON app.prep_quiz_templates FOR SELECT USING (is_active = true AND app_has_feature_access('prep_concours'));
CREATE POLICY IF NOT EXISTS auth_select_own_prep_quiz_attempts ON app.prep_quiz_attempts FOR SELECT USING (student_id = auth.uid() AND app_has_feature_access('prep_concours'));
CREATE POLICY IF NOT EXISTS auth_insert_own_prep_quiz_attempts ON app.prep_quiz_attempts FOR INSERT WITH CHECK (student_id = auth.uid());
CREATE POLICY IF NOT EXISTS auth_select_prep_badges ON app.prep_badges FOR SELECT USING (is_active = true);
CREATE POLICY IF NOT EXISTS auth_select_own_prep_student_badges ON app.prep_student_badges FOR SELECT USING (student_id = auth.uid());
CREATE POLICY IF NOT EXISTS auth_select_own_prep_ai_conversations ON app.prep_ai_conversations FOR SELECT USING (student_id = auth.uid());
CREATE POLICY IF NOT EXISTS auth_insert_own_prep_ai_conversations ON app.prep_ai_conversations FOR INSERT WITH CHECK (student_id = auth.uid());
CREATE POLICY IF NOT EXISTS auth_select_own_prep_ai_messages ON app.prep_ai_messages FOR SELECT USING (EXISTS (SELECT 1 FROM app.prep_ai_conversations c WHERE c.id = conversation_id AND c.student_id = auth.uid()));
CREATE POLICY IF NOT EXISTS auth_select_prep_ai_config ON app.prep_ai_config FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY IF NOT EXISTS auth_select_own_prep_student_progress ON app.prep_student_progress FOR SELECT USING (student_id = auth.uid());
CREATE POLICY IF NOT EXISTS auth_upsert_own_prep_student_progress ON app.prep_student_progress FOR INSERT WITH CHECK (student_id = auth.uid());
CREATE POLICY IF NOT EXISTS auth_update_own_prep_student_progress ON app.prep_student_progress FOR UPDATE USING (student_id = auth.uid());

-- Admin full access on new tables
CREATE POLICY IF NOT EXISTS admin_all_prep_question_banks ON app.prep_question_banks FOR ALL USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>'role' = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>'role' = 'admin'));
CREATE POLICY IF NOT EXISTS admin_all_prep_exam_papers ON app.prep_exam_papers FOR ALL USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>'role' = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>'role' = 'admin'));
CREATE POLICY IF NOT EXISTS admin_all_prep_badges ON app.prep_badges FOR ALL USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>'role' = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>'role' = 'admin'));
CREATE POLICY IF NOT EXISTS admin_all_prep_ai_config ON app.prep_ai_config FOR ALL USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>'role' = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>'role' = 'admin'));

-- ─────────────────────────────────────────────────────────────────────────────
-- PARTIE C: Seed data (badges + ai_config) depuis td_* vers prep_*
-- ─────────────────────────────────────────────────────────────────────────────

-- Copier les 8 badges depuis td_badges vers prep_badges
INSERT INTO app.prep_badges (code, title, description, emoji, xp_reward, condition_type, condition_value, is_active)
SELECT code, title, description, emoji, xp_reward, condition_type, condition_value, is_active
FROM app.td_badges
WHERE NOT EXISTS (SELECT 1 FROM app.prep_badges pb WHERE pb.code = td_badges.code);

-- Copier les 4 configs IA depuis td_ai_config vers prep_ai_config
INSERT INTO app.prep_ai_config (config_key, config_value, description, updated_by)
SELECT config_key, config_value, description, updated_by
FROM app.td_ai_config
WHERE NOT EXISTS (SELECT 1 FROM app.prep_ai_config pc WHERE pc.config_key = td_ai_config.config_key);

-- ─────────────────────────────────────────────────────────────────────────────
-- PARTIE D: Réécriture des RPCs admin/enseignant → pointent vers prep_*
-- ─────────────────────────────────────────────────────────────────────────────

-- D1: app_prep_create_question_bank
CREATE OR REPLACE FUNCTION app.app_prep_create_question_bank(
    p_title TEXT,
    p_description TEXT DEFAULT NULL,
    p_concours_type TEXT DEFAULT NULL,
    p_subject TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO app.prep_question_banks (title, description, concours_type, subject, created_by)
    VALUES (p_title, p_description, p_concours_type, p_subject, auth.uid())
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- D2: app_prep_list_question_banks
CREATE OR REPLACE FUNCTION app.app_prep_list_question_banks(
    p_concours_type TEXT DEFAULT NULL,
    p_subject TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT b.id, b.title, b.description, b.concours_type, b.subject,
               b.is_active, b.created_at,
               (SELECT COUNT(*) FROM app.prep_questions q WHERE q.bank_id = b.id) AS question_count
        FROM app.prep_question_banks b
        WHERE b.is_active = true
          AND (p_concours_type IS NULL OR b.concours_type = p_concours_type)
          AND (p_subject IS NULL OR b.subject = p_subject)
    ) t;

    RETURN v_result;
END;
$$;

-- D3: app_prep_create_question
CREATE OR REPLACE FUNCTION app.app_prep_create_question(
    p_bank_id UUID,
    p_content TEXT,
    p_options JSONB,
    p_correct_index INTEGER,
    p_explanation TEXT DEFAULT NULL,
    p_difficulty INTEGER DEFAULT 1,
    p_subject TEXT DEFAULT NULL,
    p_image_url TEXT DEFAULT NULL,
    p_points INTEGER DEFAULT 10,
    p_time_limit_seconds INTEGER DEFAULT 60
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_id UUID;
    v_i INTEGER;
    v_opt JSONB;
    v_label TEXT;
BEGIN
    INSERT INTO app.prep_questions (
        bank_id, question, content, options, correct_index, explanation,
        difficulty, subject, image_url, points, time_limit_seconds,
        question_type, level, source, is_published, is_active, created_by
    ) VALUES (
        p_bank_id, p_content, p_content, p_options, p_correct_index, p_explanation,
        p_difficulty, p_subject, p_image_url, p_points, p_time_limit_seconds,
        'mcq', 'beginner', 'manual', true, true, auth.uid()
    )
    RETURNING id INTO v_id;

    -- Insert choices from options array
    IF p_options IS NOT NULL AND jsonb_typeof(p_options) = 'array' THEN
        FOR v_i IN 0 .. jsonb_array_length(p_options) - 1 LOOP
            v_opt := p_options -> v_i;
            v_label := chr(65 + v_i); -- A, B, C, D...
            INSERT INTO app.prep_question_choices (question_id, choice_label, choice_text, is_correct, sort_order)
            VALUES (v_id, v_label, v_opt #>> '{}', v_i = p_correct_index, v_i);
        END LOOP;
    END IF;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- D4: app_prep_list_questions
CREATE OR REPLACE FUNCTION app.app_prep_list_questions(
    p_bank_id UUID DEFAULT NULL,
    p_concours_type TEXT DEFAULT NULL,
    p_subject TEXT DEFAULT NULL,
    p_difficulty INTEGER DEFAULT NULL,
    p_limit INTEGER DEFAULT 20
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT q.id, q.bank_id, q.question_type, q.content, q.question,
               q.options, q.correct_index, q.explanation, q.difficulty,
               q.subject, q.tags, q.points, q.time_limit_seconds,
               q.image_url, q.is_active, q.is_published, q.created_at,
               b.title AS bank_title
        FROM app.prep_questions q
        LEFT JOIN app.prep_question_banks b ON b.id = q.bank_id
        WHERE (p_bank_id IS NULL OR q.bank_id = p_bank_id)
          AND (p_concours_type IS NULL OR q.concours_type = p_concours_type)
          AND (p_subject IS NULL OR q.subject = p_subject)
          AND (p_difficulty IS NULL OR q.difficulty = p_difficulty)
        ORDER BY q.created_at DESC
        LIMIT p_limit
    ) t;

    RETURN v_result;
END;
$$;

-- D5: app_prep_create_exam_paper
CREATE OR REPLACE FUNCTION app.app_prep_create_exam_paper(
    p_title TEXT,
    p_concours_type TEXT,
    p_year TEXT DEFAULT NULL,
    p_subject TEXT DEFAULT NULL,
    p_paper_url TEXT DEFAULT NULL,
    p_correction_url TEXT DEFAULT NULL,
    p_difficulty INTEGER DEFAULT 1,
    p_is_official BOOLEAN DEFAULT false,
    p_has_correction BOOLEAN DEFAULT false
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO app.prep_exam_papers (
        title, concours_type, year, subject, paper_url, correction_url,
        difficulty, is_official, has_correction, uploaded_by
    ) VALUES (
        p_title, p_concours_type, p_year, p_subject, p_paper_url, p_correction_url,
        p_difficulty, p_is_official, p_has_correction, auth.uid()
    )
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- D6: app_prep_list_exam_papers
CREATE OR REPLACE FUNCTION app.app_prep_list_exam_papers(
    p_concours_type TEXT DEFAULT NULL,
    p_year TEXT DEFAULT NULL,
    p_subject TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT * FROM app.prep_exam_papers
        WHERE is_active = true
          AND (p_concours_type IS NULL OR concours_type = p_concours_type)
          AND (p_year IS NULL OR year = p_year)
          AND (p_subject IS NULL OR subject = p_subject)
    ) t;

    RETURN v_result;
END;
$$;

-- D7: app_prep_create_flashcard_deck
CREATE OR REPLACE FUNCTION app.app_prep_create_flashcard_deck(
    p_title TEXT,
    p_description TEXT DEFAULT NULL,
    p_subject TEXT DEFAULT NULL,
    p_concours_type TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO app.prep_flashcard_decks (title, description, subject, concours_type, created_by)
    VALUES (p_title, p_description, p_subject, p_concours_type, auth.uid())
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- D8: app_prep_list_flashcard_decks
CREATE OR REPLACE FUNCTION app.app_prep_list_flashcard_decks(
    p_subject TEXT DEFAULT NULL,
    p_concours_type TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT d.*, (SELECT COUNT(*) FROM app.prep_flashcards f WHERE f.deck_id = d.id AND f.is_active) AS card_count
        FROM app.prep_flashcard_decks d
        WHERE d.is_active = true
          AND (p_subject IS NULL OR d.subject = p_subject)
          AND (p_concours_type IS NULL OR d.concours_type = p_concours_type)
    ) t;

    RETURN v_result;
END;
$$;

-- D9: app_prep_create_flashcard
CREATE OR REPLACE FUNCTION app.app_prep_create_flashcard(
    p_deck_id UUID,
    p_front_text TEXT,
    p_back_text TEXT,
    p_subject TEXT DEFAULT NULL,
    p_tags TEXT[] DEFAULT '{}'
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO app.prep_flashcards (deck_id, front_text, back_text, subject, tags, created_by)
    VALUES (p_deck_id, p_front_text, p_back_text, p_subject, p_tags, auth.uid())
    RETURNING id INTO v_id;

    -- Update deck card count
    UPDATE app.prep_flashcard_decks SET card_count = (
        SELECT COUNT(*) FROM app.prep_flashcards WHERE deck_id = p_deck_id AND is_active
    ) WHERE id = p_deck_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- D10: app_prep_list_flashcards
CREATE OR REPLACE FUNCTION app.app_prep_list_flashcards(
    p_deck_id UUID
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT f.*,
               fp.ease_factor, fp.interval_days, fp.repetitions,
               fp.next_review_at, fp.last_reviewed_at
        FROM app.prep_flashcards f
        LEFT JOIN app.prep_flashcard_progress fp ON fp.flashcard_id = f.id AND fp.student_id = auth.uid()
        WHERE f.deck_id = p_deck_id AND f.is_active = true
    ) t;

    RETURN v_result;
END;
$$;

-- D11: app_prep_save_flashcard_review
CREATE OR REPLACE FUNCTION app.app_prep_save_flashcard_review(
    p_flashcard_id UUID,
    p_quality INTEGER,
    p_ease_factor NUMERIC DEFAULT 2.5,
    p_interval_days INTEGER DEFAULT 1,
    p_repetitions INTEGER DEFAULT 0
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
BEGIN
    INSERT INTO app.prep_flashcard_progress (flashcard_id, student_id, ease_factor, interval_days, repetitions, next_review_at, last_reviewed_at, quality_history)
    VALUES (p_flashcard_id, auth.uid(), p_ease_factor, p_interval_days, p_repetitions, now() + (p_interval_days || ' days')::interval, now(), ARRAY[p_quality])
    ON CONFLICT (flashcard_id, student_id) DO UPDATE SET
        ease_factor = EXCLUDED.ease_factor,
        interval_days = EXCLUDED.interval_days,
        repetitions = EXCLUDED.repetitions,
        next_review_at = now() + (p_interval_days || ' days')::interval,
        last_reviewed_at = now(),
        quality_history = array_append(app.prep_flashcard_progress.quality_history, p_quality);

    RETURN jsonb_build_object('success', true);
END;
$$;

-- D12: app_prep_save_quiz_attempt
CREATE OR REPLACE FUNCTION app.app_prep_save_quiz_attempt(
    p_template_id UUID DEFAULT NULL,
    p_questions_json JSONB DEFAULT NULL,
    p_answers_json JSONB DEFAULT NULL,
    p_score INTEGER DEFAULT 0,
    p_total_points INTEGER DEFAULT 0,
    p_correct_count INTEGER DEFAULT 0,
    p_question_count INTEGER DEFAULT 0,
    p_time_spent_seconds INTEGER DEFAULT 0,
    p_status TEXT DEFAULT 'completed'
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO app.prep_quiz_attempts (
        template_id, student_id, questions_json, answers_json,
        score, total_points, correct_count, question_count,
        time_spent_seconds, status
    ) VALUES (
        p_template_id, auth.uid(), p_questions_json, p_answers_json,
        p_score, p_total_points, p_correct_count, p_question_count,
        p_time_spent_seconds, p_status
    )
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- D13: app_prep_admin_get_stats
CREATE OR REPLACE FUNCTION app.app_prep_admin_get_stats()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_questions', (SELECT COUNT(*) FROM app.prep_questions),
        'total_banks', (SELECT COUNT(*) FROM app.prep_question_banks),
        'total_quiz_attempts', (SELECT COUNT(*) FROM app.prep_quiz_attempts),
        'total_students_active', (SELECT COUNT(DISTINCT student_id) FROM app.prep_quiz_attempts),
        'total_exam_papers', (SELECT COUNT(*) FROM app.prep_exam_papers),
        'total_flashcard_decks', (SELECT COUNT(*) FROM app.prep_flashcard_decks),
        'total_ai_conversations', (SELECT COUNT(*) FROM app.prep_ai_conversations),
        'total_ai_messages', (SELECT COUNT(*) FROM app.prep_ai_messages),
        'badges_config', (SELECT COALESCE(jsonb_agg(row_to_json(b)::jsonb), '[]'::jsonb) FROM app.prep_badges b WHERE b.is_active),
        'avg_score', (SELECT ROUND(AVG(score)) FROM app.prep_quiz_attempts WHERE status = 'completed')
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- D14: app_prep_admin_list_questions
CREATE OR REPLACE FUNCTION app.app_prep_admin_list_questions(
    p_bank_id UUID DEFAULT NULL,
    p_subject TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT q.id, q.content, q.question, q.options, q.correct_index,
               q.explanation, q.difficulty, q.subject, q.is_active, q.is_published,
               q.created_at, b.title AS bank_title
        FROM app.prep_questions q
        LEFT JOIN app.prep_question_banks b ON b.id = q.bank_id
        WHERE (p_bank_id IS NULL OR q.bank_id = p_bank_id)
          AND (p_subject IS NULL OR q.subject = p_subject)
        ORDER BY q.created_at DESC
        LIMIT p_limit OFFSET p_offset
    ) t;

    RETURN v_result;
END;
$$;

-- D15: app_prep_admin_toggle_question
CREATE OR REPLACE FUNCTION app.app_prep_admin_toggle_question(
    p_question_id UUID,
    p_is_active BOOLEAN
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
BEGIN
    UPDATE app.prep_questions SET is_active = p_is_active, is_published = p_is_active, updated_at = now()
    WHERE id = p_question_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- D16: app_prep_admin_upsert_badge
CREATE OR REPLACE FUNCTION app.app_prep_admin_upsert_badge(
    p_code TEXT,
    p_title TEXT,
    p_description TEXT DEFAULT NULL,
    p_emoji TEXT DEFAULT '🏅',
    p_xp_reward INTEGER DEFAULT 0,
    p_condition_type TEXT DEFAULT NULL,
    p_condition_value INTEGER DEFAULT 0
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO app.prep_badges (code, title, description, emoji, xp_reward, condition_type, condition_value)
    VALUES (p_code, p_title, p_description, p_emoji, p_xp_reward, p_condition_type, p_condition_value)
    ON CONFLICT (code) DO UPDATE SET
        title = EXCLUDED.title,
        description = EXCLUDED.description,
        emoji = EXCLUDED.emoji,
        xp_reward = EXCLUDED.xp_reward,
        condition_type = EXCLUDED.condition_type,
        condition_value = EXCLUDED.condition_value
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- D17: app_prep_get_ai_config
CREATE OR REPLACE FUNCTION app.app_prep_get_ai_config()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB := '{}'::jsonb;
    r RECORD;
BEGIN
    FOR r IN SELECT config_key, config_value FROM app.prep_ai_config LOOP
        v_result := v_result || jsonb_build_object(r.config_key, r.config_value);
    END LOOP;

    RETURN v_result;
END;
$$;

-- D18: app_prep_update_ai_config
CREATE OR REPLACE FUNCTION app.app_prep_update_ai_config(
    p_key TEXT,
    p_value TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
BEGIN
    INSERT INTO app.prep_ai_config (config_key, config_value, updated_by)
    VALUES (p_key, p_value, auth.uid())
    ON CONFLICT (config_key) DO UPDATE SET
        config_value = EXCLUDED.config_value,
        updated_by = auth.uid(),
        updated_at = now();

    RETURN jsonb_build_object('success', true);
END;
$$;

-- D19: app_prep_create_ai_conversation
CREATE OR REPLACE FUNCTION app.app_prep_create_ai_conversation(
    p_title TEXT DEFAULT NULL,
    p_subject TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO app.prep_ai_conversations (student_id, title, subject)
    VALUES (auth.uid(), COALESCE(p_title, 'Tuteur IA'), p_subject)
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'conversation_id', v_id);
END;
$$;

-- D20: app_prep_save_ai_message
CREATE OR REPLACE FUNCTION app.app_prep_save_ai_message(
    p_conversation_id UUID,
    p_role TEXT,
    p_content TEXT,
    p_tokens_used INTEGER DEFAULT 0
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO app.prep_ai_messages (conversation_id, role, content, tokens_used)
    VALUES (p_conversation_id, p_role, p_content, p_tokens_used)
    RETURNING id INTO v_id;

    -- Update conversation counters
    UPDATE app.prep_ai_conversations SET
        message_count = message_count + 1,
        total_tokens_used = total_tokens_used + p_tokens_used,
        updated_at = now()
    WHERE id = p_conversation_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- D21: app_prep_list_ai_conversations
CREATE OR REPLACE FUNCTION app.app_prep_list_ai_conversations()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.updated_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT * FROM app.prep_ai_conversations WHERE student_id = auth.uid()
    ) t;

    RETURN v_result;
END;
$$;

-- D22: app_prep_list_ai_messages
CREATE OR REPLACE FUNCTION app.app_prep_list_ai_messages(
    p_conversation_id UUID
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT * FROM app.prep_ai_messages WHERE conversation_id = p_conversation_id
    ) t;

    RETURN v_result;
END;
$$;

-- D23: app_prep_admin_list_ai_conversations
CREATE OR REPLACE FUNCTION app.app_prep_admin_list_ai_conversations(
    p_limit INTEGER DEFAULT 50
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.updated_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT c.*, s.full_name AS student_name
        FROM app.prep_ai_conversations c
        LEFT JOIN app.students s ON s.id = c.student_id
        LIMIT p_limit
    ) t;

    RETURN v_result;
END;
$$;

-- D24: app_prep_get_student_progress
CREATE OR REPLACE FUNCTION app.app_prep_get_student_progress()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT row_to_json(t)::jsonb INTO v_result
    FROM (
        SELECT
            COALESCE(p.total_xp, 0) AS total_xp,
            COALESCE(p.current_streak, 0) AS current_streak,
            COALESCE(p.longest_streak, 0) AS longest_streak,
            COALESCE(p.total_correct, 0) AS total_correct,
            COALESCE(p.total_answered, 0) AS total_answered,
            p.last_activity_date,
            (SELECT COUNT(*) FROM app.prep_quiz_attempts qa WHERE qa.student_id = auth.uid()) AS quiz_count,
            (SELECT COUNT(*) FROM app.prep_student_badges sb WHERE sb.student_id = auth.uid()) AS badge_count,
            (SELECT COALESCE(jsonb_agg(row_to_json(b)::jsonb), '[]'::jsonb)
             FROM app.prep_student_badges sb
             JOIN app.prep_badges b ON b.id = sb.badge_id
             WHERE sb.student_id = auth.uid()
            ) AS earned_badges
        FROM app.prep_student_progress p
        WHERE p.student_id = auth.uid()
    ) t;

    -- If no progress record yet, return defaults
    IF v_result IS NULL THEN
        v_result := jsonb_build_object(
            'total_xp', 0, 'current_streak', 0, 'longest_streak', 0,
            'total_correct', 0, 'total_answered', 0,
            'last_activity_date', NULL,
            'quiz_count', 0, 'badge_count', 0, 'earned_badges', '[]'::jsonb
        );
    END IF;

    RETURN v_result;
END;
$$;

-- D25: app_prep_get_subject_stats (réécriture pour utiliser prep_*)
CREATE OR REPLACE FUNCTION app.app_prep_get_subject_stats()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT
            q.subject,
            COUNT(a.id) AS total,
            SUM(CASE WHEN a.is_correct THEN 1 ELSE 0 END) AS correct,
            CASE WHEN COUNT(a.id) > 0
                 THEN ROUND((SUM(CASE WHEN a.is_correct THEN 1 ELSE 0 END)::numeric / COUNT(a.id)) * 100, 1)
                 ELSE 0 END AS accuracy,
            ROUND(AVG(a.time_spent_sec), 1) AS avg_time_sec
        FROM app.prep_attempts a
        JOIN app.prep_questions q ON q.id = a.question_id
        WHERE a.student_id = auth.uid()
        GROUP BY q.subject
        ORDER BY total DESC
    ) t;

    RETURN v_result;
END;
$$;

-- D26: app_prep_get_leaderboard
CREATE OR REPLACE FUNCTION app.app_prep_get_leaderboard(
    p_limit INTEGER DEFAULT 20
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT
            p.student_id,
            s.full_name AS student_name,
            p.total_xp,
            p.current_streak,
            p.total_correct,
            p.total_answered,
            ROW_NUMBER() OVER (ORDER BY p.total_xp DESC) AS rank
        FROM app.prep_student_progress p
        LEFT JOIN app.students s ON s.id = p.student_id
        ORDER BY p.total_xp DESC
        LIMIT p_limit
    ) t;

    RETURN v_result;
END;
$$;

-- D27: app_prep_list_quiz_templates
CREATE OR REPLACE FUNCTION app.app_prep_list_quiz_templates(
    p_concours_type TEXT DEFAULT NULL,
    p_subject TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT qt.*, b.title AS bank_title
        FROM app.prep_quiz_templates qt
        LEFT JOIN app.prep_question_banks b ON b.id = qt.bank_id
        WHERE qt.is_active = true
          AND (p_concours_type IS NULL OR qt.concours_type = p_concours_type)
          AND (p_subject IS NULL OR qt.subject = p_subject)
    ) t;

    RETURN v_result;
END;
$$;

-- D28: app_prep_create_quiz_template
CREATE OR REPLACE FUNCTION app.app_prep_create_quiz_template(
    p_title TEXT,
    p_bank_id UUID DEFAULT NULL,
    p_concours_type TEXT DEFAULT NULL,
    p_subject TEXT DEFAULT NULL,
    p_question_count INTEGER DEFAULT 10,
    p_time_limit_minutes INTEGER DEFAULT NULL,
    p_shuffle BOOLEAN DEFAULT true,
    p_is_exam_mode BOOLEAN DEFAULT false,
    p_passing_score INTEGER DEFAULT 60,
    p_description TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO app.prep_quiz_templates (
        title, description, bank_id, concours_type, subject,
        question_count, time_limit_minutes, shuffle_questions,
        is_exam_mode, passing_score, created_by
    ) VALUES (
        p_title, p_description, p_bank_id, p_concours_type, p_subject,
        p_question_count, p_time_limit_minutes, p_shuffle,
        p_is_exam_mode, p_passing_score, auth.uid()
    )
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- D29: Nouvelle RPC — Sync XP/Streak serveur (Phase 4)
CREATE OR REPLACE FUNCTION public.app_prep_sync_student_progress(
    p_total_xp INTEGER DEFAULT 0,
    p_current_streak INTEGER DEFAULT 0,
    p_longest_streak INTEGER DEFAULT 0,
    p_total_correct INTEGER DEFAULT 0,
    p_total_answered INTEGER DEFAULT 0,
    p_last_activity_date DATE DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
BEGIN
    INSERT INTO app.prep_student_progress (
        student_id, total_xp, current_streak, longest_streak,
        total_correct, total_answered, last_activity_date
    ) VALUES (
        auth.uid(), p_total_xp, p_current_streak, p_longest_streak,
        p_total_correct, p_total_answered, p_last_activity_date
    )
    ON CONFLICT (student_id) DO UPDATE SET
        total_xp = GREATEST(app.prep_student_progress.total_xp, EXCLUDED.total_xp),
        current_streak = EXCLUDED.current_streak,
        longest_streak = GREATEST(app.prep_student_progress.longest_streak, EXCLUDED.longest_streak),
        total_correct = GREATEST(app.prep_student_progress.total_correct, EXCLUDED.total_correct),
        total_answered = GREATEST(app.prep_student_progress.total_answered, EXCLUDED.total_answered),
        last_activity_date = EXCLUDED.last_activity_date,
        updated_at = now();

    RETURN jsonb_build_object('success', true);
END;
$$;

-- D30: Nouvelle RPC — Récupérer les questions pour quiz depuis Supabase
CREATE OR REPLACE FUNCTION public.app_prep_get_quiz_questions(
    p_subject TEXT DEFAULT NULL,
    p_concours_type TEXT DEFAULT NULL,
    p_difficulty INTEGER DEFAULT NULL,
    p_count INTEGER DEFAULT 10
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT q.id, q.content, q.question, q.options, q.correct_index,
               q.explanation, q.difficulty, q.subject, q.image_url,
               q.points, q.time_limit_seconds,
               (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                   'id', c.id, 'label', c.choice_label, 'text', c.choice_text,
                   'is_correct', c.is_correct
               ) ORDER BY c.sort_order), '[]'::jsonb)
               FROM app.prep_question_choices c WHERE c.question_id = q.id
               ) AS choices
        FROM app.prep_questions q
        WHERE q.is_published = true AND q.is_active = true
          AND (p_subject IS NULL OR q.subject = p_subject)
          AND (p_concours_type IS NULL OR q.concours_type = p_concours_type)
          AND (p_difficulty IS NULL OR q.difficulty = p_difficulty)
        ORDER BY random()
        LIMIT p_count
    ) t;

    RETURN v_result;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PARTIE E: Créer le bucket Storage pour les documents concours
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('prep-documents', 'prep-documents', true, 52428800, ARRAY['application/pdf','image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Storage policies
CREATE POLICY IF NOT EXISTS prep_docs_select ON storage.objects FOR SELECT USING (bucket_id = 'prep-documents');
CREATE POLICY IF NOT EXISTS prep_docs_insert ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'prep-documents' AND auth.uid() IS NOT NULL
);
CREATE POLICY IF NOT EXISTS prep_docs_delete ON storage.objects FOR DELETE USING (
    bucket_id = 'prep-documents'
    AND EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>'role' = 'admin')
);
