-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (PHASE 7)
-- Anti-piratage V1 + Analytics (MVP)
-- - Logs d'usage IA (prep_ai_usage_logs)
-- - Rate-limit applicatif via RPC (app_prep_ai_check_rate_limit)
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- 1) Table logs usage IA
-- ========================================

CREATE TABLE IF NOT EXISTS app.prep_ai_usage_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  generation_id UUID,
  subject_id UUID,
  endpoint TEXT NOT NULL DEFAULT 'ai/prep/generate',
  input_hash TEXT,
  status TEXT NOT NULL DEFAULT 'started',
  duration_ms INTEGER,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.prep_ai_usage_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_select_own_prep_ai_usage_logs ON app.prep_ai_usage_logs;
CREATE POLICY user_select_own_prep_ai_usage_logs
ON app.prep_ai_usage_logs
FOR SELECT
USING (user_id = auth.uid());

DROP POLICY IF EXISTS user_insert_own_prep_ai_usage_logs ON app.prep_ai_usage_logs;
CREATE POLICY user_insert_own_prep_ai_usage_logs
ON app.prep_ai_usage_logs
FOR INSERT
WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT ON app.prep_ai_usage_logs TO authenticated;
GRANT ALL ON app.prep_ai_usage_logs TO service_role;

-- ========================================
-- 2) RPC: log usage
-- ========================================

CREATE OR REPLACE FUNCTION app_prep_ai_log_usage(
  p_generation_id UUID DEFAULT NULL,
  p_subject_id UUID DEFAULT NULL,
  p_input_hash TEXT DEFAULT NULL,
  p_endpoint TEXT DEFAULT 'ai/prep/generate',
  p_status TEXT DEFAULT 'started',
  p_duration_ms INTEGER DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  INSERT INTO app.prep_ai_usage_logs(
    user_id,
    generation_id,
    subject_id,
    endpoint,
    input_hash,
    status,
    duration_ms,
    metadata,
    created_at
  ) VALUES (
    v_user_id,
    p_generation_id,
    p_subject_id,
    COALESCE(p_endpoint, 'ai/prep/generate'),
    p_input_hash,
    COALESCE(p_status, 'started'),
    p_duration_ms,
    p_metadata,
    NOW()
  ) RETURNING id INTO v_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_ai_log_usage(UUID, UUID, TEXT, TEXT, TEXT, INTEGER, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION app_prep_ai_log_usage(UUID, UUID, TEXT, TEXT, TEXT, INTEGER, JSONB) TO service_role;

-- ========================================
-- 3) RPC: rate-limit
-- ========================================

CREATE OR REPLACE FUNCTION app_prep_ai_check_rate_limit(
  p_endpoint TEXT DEFAULT 'ai/prep/generate',
  p_window_seconds INTEGER DEFAULT 3600,
  p_max_calls INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_count INTEGER := 0;
  v_allowed BOOLEAN := FALSE;
  v_reset_in_sec INTEGER := 0;
  v_window INTEGER := GREATEST(1, COALESCE(p_window_seconds, 3600));
  v_max INTEGER := GREATEST(1, COALESCE(p_max_calls, 20));
  v_oldest TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT COUNT(*)::INTEGER,
         MIN(created_at)
  INTO v_count, v_oldest
  FROM app.prep_ai_usage_logs
  WHERE user_id = v_user_id
    AND endpoint = COALESCE(p_endpoint, 'ai/prep/generate')
    AND created_at > NOW() - (v_window || ' seconds')::INTERVAL;

  v_allowed := (v_count < v_max);

  IF v_oldest IS NULL THEN
    v_reset_in_sec := v_window;
  ELSE
    v_reset_in_sec := GREATEST(0, (EXTRACT(EPOCH FROM (v_oldest + (v_window || ' seconds')::INTERVAL - NOW())))::INTEGER);
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'allowed', v_allowed,
    'count', v_count,
    'max', v_max,
    'window_seconds', v_window,
    'reset_in_seconds', v_reset_in_sec
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_ai_check_rate_limit(TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION app_prep_ai_check_rate_limit(TEXT, INTEGER, INTEGER) TO service_role;
