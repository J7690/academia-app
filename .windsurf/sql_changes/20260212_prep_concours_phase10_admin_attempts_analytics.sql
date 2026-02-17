-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (PHASE 10)
-- Analytics pédagogiques admin sur les tentatives (prep_attempts)
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) RLS: lecture globale des tentatives pour les admins
-- ========================================

DROP POLICY IF EXISTS admin_select_all_prep_attempts ON app.prep_attempts;
CREATE POLICY admin_select_all_prep_attempts
ON app.prep_attempts
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

-- ========================================
-- 2) RPC ADMIN: résumé global des tentatives
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_prep_get_attempts_summary(
  p_subject_id UUID DEFAULT NULL,
  p_days INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_days INTEGER := GREATEST(1, LEAST(COALESCE(p_days, 30), 365));
  v_total INTEGER := 0;
  v_correct INTEGER := 0;
  v_avg_time NUMERIC;
  v_by_subject JSONB := '[]'::JSONB;
BEGIN
  -- Auth + admin check
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

  -- Stats globales sur la fenêtre et, si fourni, sur une matière
  SELECT
    COUNT(*)::INTEGER,
    COALESCE(SUM(CASE WHEN a.is_correct IS TRUE THEN 1 ELSE 0 END), 0)::INTEGER,
    AVG(a.time_spent_sec)
  INTO v_total, v_correct, v_avg_time
  FROM app.prep_attempts a
  JOIN app.prep_questions q ON q.id = a.question_id
  WHERE a.created_at > NOW() - (v_days || ' days')::INTERVAL
    AND (p_subject_id IS NULL OR q.subject_id = p_subject_id);

  -- Répartition par matière
  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'subject_id', sub.subject_id,
        'total', sub.total,
        'correct', sub.correct,
        'accuracy', sub.accuracy
      )
      ORDER BY sub.total DESC
    ),
    '[]'::JSONB
  )
  INTO v_by_subject
  FROM (
    SELECT
      q.subject_id AS subject_id,
      COUNT(*)::INTEGER AS total,
      COALESCE(SUM(CASE WHEN a.is_correct IS TRUE THEN 1 ELSE 0 END), 0)::INTEGER AS correct,
      CASE WHEN COUNT(*) = 0 THEN 0
           ELSE ROUND((COALESCE(SUM(CASE WHEN a.is_correct IS TRUE THEN 1 ELSE 0 END), 0)::NUMERIC
                      / GREATEST(COUNT(*)::NUMERIC, 1)) * 100, 1)
      END AS accuracy
    FROM app.prep_attempts a
    JOIN app.prep_questions q ON q.id = a.question_id
    WHERE a.created_at > NOW() - (v_days || ' days')::INTERVAL
      AND (p_subject_id IS NULL OR q.subject_id = p_subject_id)
    GROUP BY q.subject_id
  ) sub;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'days', v_days,
    'subject_id', p_subject_id,
    'overall', JSONB_BUILD_OBJECT(
      'total', v_total,
      'correct', v_correct,
      'accuracy', CASE WHEN v_total <= 0 THEN 0 ELSE ROUND((v_correct::NUMERIC / v_total::NUMERIC) * 100, 1) END,
      'avg_time_sec', COALESCE(ROUND(v_avg_time::NUMERIC, 1), 0)
    ),
    'by_subject', v_by_subject
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_get_attempts_summary(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_get_attempts_summary(UUID, INTEGER) TO service_role;
