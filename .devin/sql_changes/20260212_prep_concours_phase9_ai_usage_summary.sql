-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (PHASE 9)
-- Analytics IA: résumé d'usage sur prep_ai_usage_logs
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) RPC ADMIN: résumé d'usage IA sur une fenêtre glissante
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_prep_ai_get_usage_summary(
  p_days INTEGER DEFAULT 1,
  p_endpoint TEXT DEFAULT 'ai/prep/generate'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_days INTEGER := GREATEST(1, LEAST(COALESCE(p_days, 1), 365));
  v_total INTEGER := 0;
  v_by_status JSONB := '[]'::JSONB;
  v_top_users JSONB := '[]'::JSONB;
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

  -- Total appels sur la fenêtre
  SELECT COUNT(*)::INTEGER
  INTO v_total
  FROM app.prep_ai_usage_logs l
  WHERE l.created_at > NOW() - (v_days || ' days')::INTERVAL
    AND (p_endpoint IS NULL OR l.endpoint = p_endpoint);

  -- Répartition par statut
  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'status', sub.status,
        'count', sub.cnt
      )
    ),
    '[]'::JSONB
  )
  INTO v_by_status
  FROM (
    SELECT l.status AS status, COUNT(*)::INTEGER AS cnt
    FROM app.prep_ai_usage_logs l
    WHERE l.created_at > NOW() - (v_days || ' days')::INTERVAL
      AND (p_endpoint IS NULL OR l.endpoint = p_endpoint)
    GROUP BY l.status
    ORDER BY cnt DESC
  ) sub;

  -- Top users (par nombre d'appels)
  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'user_id', sub.user_id,
        'count', sub.cnt
      )
    ),
    '[]'::JSONB
  )
  INTO v_top_users
  FROM (
    SELECT l.user_id AS user_id, COUNT(*)::INTEGER AS cnt
    FROM app.prep_ai_usage_logs l
    WHERE l.created_at > NOW() - (v_days || ' days')::INTERVAL
      AND (p_endpoint IS NULL OR l.endpoint = p_endpoint)
    GROUP BY l.user_id
    ORDER BY cnt DESC
    LIMIT 20
  ) sub;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'days', v_days,
    'endpoint', p_endpoint,
    'total', v_total,
    'by_status', v_by_status,
    'top_users', v_top_users
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_ai_get_usage_summary(INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_ai_get_usage_summary(INTEGER, TEXT) TO service_role;
