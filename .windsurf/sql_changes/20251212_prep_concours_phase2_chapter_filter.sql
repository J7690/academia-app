-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (Phase 2)
-- Entraînement filtré par chapitre
-- Étend app_prep_list_published_questions avec p_chapter_id
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE OR REPLACE FUNCTION app_prep_list_published_questions(
  p_subject_id UUID,
  p_level TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_chapter_id UUID DEFAULT NULL
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
      AND (p_chapter_id IS NULL OR q.chapter_id = p_chapter_id)
    ORDER BY q.created_at DESC
    LIMIT GREATEST(1, LEAST(p_limit, 100))
  ) q;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_list_published_questions(UUID, TEXT, INTEGER, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION app_prep_list_published_questions(UUID, TEXT, INTEGER, UUID) TO service_role;
