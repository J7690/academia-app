-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (PHASE 1)
-- Socle DB + RLS + RPC (lecture + writes contrôlés)
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) Matières / Chapitres
-- ========================================

CREATE TABLE IF NOT EXISTS app.prep_subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT,
    sort_order INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app.prep_chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID NOT NULL REFERENCES app.prep_subjects(id) ON DELETE CASCADE,
    slug TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    sort_order INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(subject_id, slug)
);

ALTER TABLE app.prep_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_chapters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_active_prep_subjects ON app.prep_subjects;
CREATE POLICY public_select_active_prep_subjects
ON app.prep_subjects FOR SELECT
USING (is_active = TRUE);

DROP POLICY IF EXISTS public_select_active_prep_chapters ON app.prep_chapters;
CREATE POLICY public_select_active_prep_chapters
ON app.prep_chapters FOR SELECT
USING (is_active = TRUE);

GRANT SELECT ON app.prep_subjects TO anon, authenticated;
GRANT SELECT ON app.prep_chapters TO anon, authenticated;
GRANT ALL ON app.prep_subjects TO service_role;
GRANT ALL ON app.prep_chapters TO service_role;

-- ========================================
-- 2) Questions / Choix (QCM)
-- ========================================

CREATE TABLE IF NOT EXISTS app.prep_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID NOT NULL REFERENCES app.prep_subjects(id) ON DELETE CASCADE,
    chapter_id UUID REFERENCES app.prep_chapters(id) ON DELETE SET NULL,
    source TEXT NOT NULL DEFAULT 'manual', -- manual|import|ai
    question_type TEXT NOT NULL DEFAULT 'mcq', -- mcq|short|case
    level TEXT NOT NULL DEFAULT 'beginner', -- beginner|intermediate|advanced
    mechanism TEXT,
    prompt_context TEXT,
    question TEXT NOT NULL,
    explanation TEXT,
    correct_answer TEXT,
    estimated_time_sec INTEGER,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app.prep_question_choices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES app.prep_questions(id) ON DELETE CASCADE,
    choice_label TEXT,
    choice_text TEXT NOT NULL,
    is_correct BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(question_id, sort_order)
);

ALTER TABLE app.prep_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_question_choices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_published_prep_questions ON app.prep_questions;
CREATE POLICY public_select_published_prep_questions
ON app.prep_questions FOR SELECT
USING (is_published = TRUE);

DROP POLICY IF EXISTS public_select_published_prep_question_choices ON app.prep_question_choices;
CREATE POLICY public_select_published_prep_question_choices
ON app.prep_question_choices FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.prep_questions q
    WHERE q.id = prep_question_choices.question_id
      AND q.is_published = TRUE
  )
);

GRANT SELECT ON app.prep_questions TO anon, authenticated;
GRANT SELECT ON app.prep_question_choices TO anon, authenticated;
GRANT ALL ON app.prep_questions TO service_role;
GRANT ALL ON app.prep_question_choices TO service_role;

-- ========================================
-- 3) Attempts (réponses étudiants)
-- ========================================

CREATE TABLE IF NOT EXISTS app.prep_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES app.prep_questions(id) ON DELETE CASCADE,
    attempt_type TEXT NOT NULL DEFAULT 'training', -- training|diagnostic|exam
    selected_answer TEXT,
    is_correct BOOLEAN,
    time_spent_sec INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.prep_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_select_own_prep_attempts ON app.prep_attempts;
CREATE POLICY student_select_own_prep_attempts
ON app.prep_attempts FOR SELECT
USING (student_id = auth.uid());

DROP POLICY IF EXISTS student_insert_own_prep_attempts ON app.prep_attempts;
CREATE POLICY student_insert_own_prep_attempts
ON app.prep_attempts FOR INSERT
WITH CHECK (student_id = auth.uid());

GRANT SELECT, INSERT ON app.prep_attempts TO authenticated;
GRANT ALL ON app.prep_attempts TO service_role;

-- ========================================
-- 4) Exams / Exam items
-- ========================================

CREATE TABLE IF NOT EXISTS app.prep_exams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    student_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    title TEXT,
    subject_id UUID REFERENCES app.prep_subjects(id) ON DELETE SET NULL,
    level TEXT,
    mode TEXT NOT NULL DEFAULT 'practice', -- practice|strict
    duration_sec INTEGER,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app.prep_exam_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES app.prep_exams(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES app.prep_questions(id) ON DELETE RESTRICT,
    sort_order INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(exam_id, sort_order)
);

ALTER TABLE app.prep_exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_exam_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_select_published_prep_exams ON app.prep_exams;
CREATE POLICY public_select_published_prep_exams
ON app.prep_exams FOR SELECT
USING (is_published = TRUE);

DROP POLICY IF EXISTS public_select_published_prep_exam_items ON app.prep_exam_items;
CREATE POLICY public_select_published_prep_exam_items
ON app.prep_exam_items FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM app.prep_exams e
    WHERE e.id = prep_exam_items.exam_id
      AND e.is_published = TRUE
  )
);

GRANT SELECT ON app.prep_exams TO anon, authenticated;
GRANT SELECT ON app.prep_exam_items TO anon, authenticated;
GRANT ALL ON app.prep_exams TO service_role;
GRANT ALL ON app.prep_exam_items TO service_role;

-- ========================================
-- 5) Pipeline IA - Sources / Chunks / Generations
-- ========================================

CREATE TABLE IF NOT EXISTS app.prep_source_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    subject_id UUID REFERENCES app.prep_subjects(id) ON DELETE SET NULL,
    year INTEGER,
    doc_type TEXT,
    source_type TEXT NOT NULL DEFAULT 'pdf', -- pdf|image|text
    storage_bucket TEXT,
    storage_path TEXT,
    extracted_text TEXT,
    status TEXT NOT NULL DEFAULT 'received', -- received|extracted|indexed|validated|published|rejected
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app.prep_doc_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_document_id UUID NOT NULL REFERENCES app.prep_source_documents(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    content TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(source_document_id, chunk_index)
);

CREATE TABLE IF NOT EXISTS app.prep_ai_generations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    subject_id UUID REFERENCES app.prep_subjects(id) ON DELETE SET NULL,
    generation_type TEXT NOT NULL DEFAULT 'mcq', -- mcq|exam|explanation|sheet
    input_params JSONB,
    output_json JSONB,
    status TEXT NOT NULL DEFAULT 'proposed', -- proposed|validated|published|rejected|error
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.prep_source_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_doc_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_ai_generations ENABLE ROW LEVEL SECURITY;

-- MVP policies: lecture limitée aux utilisateurs authentifiés (admin out-of-band via service_role)
DROP POLICY IF EXISTS authenticated_select_prep_source_documents ON app.prep_source_documents;
CREATE POLICY authenticated_select_prep_source_documents
ON app.prep_source_documents FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS authenticated_select_prep_doc_chunks ON app.prep_doc_chunks;
CREATE POLICY authenticated_select_prep_doc_chunks
ON app.prep_doc_chunks FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS authenticated_select_prep_ai_generations ON app.prep_ai_generations;
CREATE POLICY authenticated_select_prep_ai_generations
ON app.prep_ai_generations FOR SELECT
USING (auth.uid() IS NOT NULL);

GRANT SELECT ON app.prep_source_documents TO authenticated;
GRANT SELECT ON app.prep_doc_chunks TO authenticated;
GRANT SELECT ON app.prep_ai_generations TO authenticated;
GRANT ALL ON app.prep_source_documents TO service_role;
GRANT ALL ON app.prep_doc_chunks TO service_role;
GRANT ALL ON app.prep_ai_generations TO service_role;

-- ========================================
-- 6) RPC minimales (lecture) pour Flutter
-- ========================================

CREATE OR REPLACE FUNCTION app_prep_list_subjects()
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
        'id', s.id,
        'slug', s.slug,
        'title', s.title,
        'description', s.description,
        'sort_order', s.sort_order
      )
      ORDER BY COALESCE(s.sort_order, 999999)
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.prep_subjects s
  WHERE s.is_active = TRUE;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_list_subjects TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_prep_list_subjects TO service_role;

CREATE OR REPLACE FUNCTION app_prep_list_chapters(
  p_subject_id UUID
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
        'id', c.id,
        'subject_id', c.subject_id,
        'slug', c.slug,
        'title', c.title,
        'description', c.description,
        'sort_order', c.sort_order
      )
      ORDER BY COALESCE(c.sort_order, 999999)
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.prep_chapters c
  WHERE c.subject_id = p_subject_id
    AND c.is_active = TRUE;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_list_chapters(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_prep_list_chapters(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_prep_list_published_questions(
  p_subject_id UUID,
  p_level TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
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
        'id', q.id,
        'subject_id', q.subject_id,
        'chapter_id', q.chapter_id,
        'question_type', q.question_type,
        'level', q.level,
        'mechanism', q.mechanism,
        'question', q.question,
        'explanation', q.explanation,
        'correct_answer', q.correct_answer,
        'estimated_time_sec', q.estimated_time_sec
      )
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.prep_questions q
  WHERE q.is_published = TRUE
    AND q.subject_id = p_subject_id
    AND (p_level IS NULL OR q.level = p_level)
  ORDER BY q.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 100));

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_list_published_questions(UUID, TEXT, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_prep_list_published_questions(UUID, TEXT, INTEGER) TO service_role;

CREATE OR REPLACE FUNCTION app_prep_list_question_choices(
  p_question_id UUID
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
        'id', c.id,
        'question_id', c.question_id,
        'choice_label', c.choice_label,
        'choice_text', c.choice_text,
        'sort_order', c.sort_order
      )
      ORDER BY COALESCE(c.sort_order, 999999)
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.prep_question_choices c
  WHERE c.question_id = p_question_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_list_question_choices(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_prep_list_question_choices(UUID) TO service_role;

-- ========================================
-- 7) RPC minimale (write) : enregistrer attempt
-- ========================================

CREATE OR REPLACE FUNCTION app_prep_create_attempt(
  p_question_id UUID,
  p_attempt_type TEXT,
  p_selected_answer TEXT,
  p_is_correct BOOLEAN,
  p_time_spent_sec INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO app.prep_attempts(
    student_id,
    question_id,
    attempt_type,
    selected_answer,
    is_correct,
    time_spent_sec
  ) VALUES (
    auth.uid(),
    p_question_id,
    COALESCE(p_attempt_type, 'training'),
    p_selected_answer,
    p_is_correct,
    p_time_spent_sec
  ) RETURNING id INTO v_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_create_attempt(UUID, TEXT, TEXT, BOOLEAN, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION app_prep_create_attempt(UUID, TEXT, TEXT, BOOLEAN, INTEGER) TO service_role;
