-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (PHASE 1) - FIX RPC
-- Corrige:
-- - app_prep_list_published_questions: ORDER BY + JSONB_AGG (erreur GROUP BY)
-- - app_prep_create_attempt: refuse si non authentifié (évite insert NULL student_id)
-- Application via admin_execute_sql
-- ========================================

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
  FROM (
    SELECT *
    FROM app.prep_questions q
    WHERE q.is_published = TRUE
      AND q.subject_id = p_subject_id
      AND (p_level IS NULL OR q.level = p_level)
    ORDER BY q.created_at DESC
    LIMIT GREATEST(1, LEAST(p_limit, 100))
  ) q;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_list_published_questions(UUID, TEXT, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_prep_list_published_questions(UUID, TEXT, INTEGER) TO service_role;

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
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  INSERT INTO app.prep_attempts(
    student_id,
    question_id,
    attempt_type,
    selected_answer,
    is_correct,
    time_spent_sec
  ) VALUES (
    v_user_id,
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
