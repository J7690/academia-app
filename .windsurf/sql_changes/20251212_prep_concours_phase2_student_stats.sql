-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (Student stats/historique)
-- Hors paiement: historique tentatives + stats simples
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- Historique des tentatives (student = auth.uid)
CREATE OR REPLACE FUNCTION app_prep_list_my_attempts(
  p_subject_id UUID DEFAULT NULL,
  p_attempt_type TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_limit INTEGER := GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
  v_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  IF NOT app_has_feature_access('prep_concours') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_feature_access');
  END IF;

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', a.id,
        'created_at', a.created_at,
        'attempt_type', a.attempt_type,
        'is_correct', a.is_correct,
        'time_spent_sec', a.time_spent_sec,
        'question_id', q.id,
        'subject_id', q.subject_id,
        'question', q.question,
        'correct_answer', q.correct_answer
      )
      ORDER BY a.created_at DESC
    ),
    '[]'::JSONB
  )
  INTO v_result
  FROM (
    SELECT *
    FROM app.prep_attempts a
    WHERE a.student_id = v_user_id
      AND (p_attempt_type IS NULL OR a.attempt_type = p_attempt_type)
    ORDER BY a.created_at DESC
    LIMIT v_limit
  ) a
  JOIN app.prep_questions q
    ON q.id = a.question_id
  WHERE (p_subject_id IS NULL OR q.subject_id = p_subject_id);

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'attempts', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_list_my_attempts(UUID, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION app_prep_list_my_attempts(UUID, TEXT, INTEGER) TO service_role;

-- Stats simples par matière (fenêtre 30 jours)
CREATE OR REPLACE FUNCTION app_prep_get_my_subject_stats(
  p_subject_id UUID,
  p_days INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_days INTEGER := GREATEST(1, LEAST(COALESCE(p_days, 30), 365));
  v_total INTEGER := 0;
  v_correct INTEGER := 0;
  v_avg_time NUMERIC;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  IF NOT app_has_feature_access('prep_concours') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_feature_access');
  END IF;

  IF p_subject_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_subject_id');
  END IF;

  SELECT
    COUNT(*)::INTEGER,
    COALESCE(SUM(CASE WHEN a.is_correct IS TRUE THEN 1 ELSE 0 END), 0)::INTEGER,
    AVG(a.time_spent_sec)
  INTO v_total, v_correct, v_avg_time
  FROM app.prep_attempts a
  JOIN app.prep_questions q ON q.id = a.question_id
  WHERE a.student_id = v_user_id
    AND q.subject_id = p_subject_id
    AND a.created_at > NOW() - (v_days || ' days')::INTERVAL;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'subject_id', p_subject_id,
    'days', v_days,
    'total', v_total,
    'correct', v_correct,
    'accuracy', CASE WHEN v_total <= 0 THEN 0 ELSE ROUND((v_correct::NUMERIC / v_total::NUMERIC) * 100, 1) END,
    'avg_time_sec', COALESCE(ROUND(v_avg_time::NUMERIC, 1), 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_get_my_subject_stats(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION app_prep_get_my_subject_stats(UUID, INTEGER) TO service_role;
