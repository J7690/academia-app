-- ============================================================
-- Analytics Tracking: onglets visités par les utilisateurs
-- Permet à l'admin de voir quelles sections attirent le plus
-- ============================================================

-- Table principale des événements de navigation
CREATE TABLE IF NOT EXISTS app.user_navigation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  screen_name text NOT NULL,
  tab_index int,
  tab_name text,
  session_id text,
  duration_seconds int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_nav_events_user ON app.user_navigation_events(user_id);
CREATE INDEX IF NOT EXISTS idx_nav_events_screen ON app.user_navigation_events(screen_name);
CREATE INDEX IF NOT EXISTS idx_nav_events_created ON app.user_navigation_events(created_at DESC);

-- RPC: Enregistrer un événement de navigation
CREATE OR REPLACE FUNCTION app.app_track_navigation_event(
  p_screen_name text,
  p_tab_index int DEFAULT NULL,
  p_tab_name text DEFAULT NULL,
  p_session_id text DEFAULT NULL,
  p_duration_seconds int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  INSERT INTO app.user_navigation_events (user_id, screen_name, tab_index, tab_name, session_id, duration_seconds)
  VALUES (v_user_id, p_screen_name, p_tab_index, p_tab_name, p_session_id, p_duration_seconds);

  RETURN jsonb_build_object('success', true);
END;
$$;

-- RPC Admin: Stats de navigation agrégées (top screens, top tabs, par période)
CREATE OR REPLACE FUNCTION app.app_admin_get_navigation_stats(
  p_days int DEFAULT 7,
  p_limit int DEFAULT 20
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_since timestamptz := now() - (p_days || ' days')::interval;
  v_top_screens jsonb;
  v_top_tabs jsonb;
  v_daily_activity jsonb;
  v_unique_users int;
  v_total_events int;
BEGIN
  -- Top screens
  SELECT jsonb_agg(row_to_json(t))
  INTO v_top_screens
  FROM (
    SELECT screen_name, COUNT(*) as visits, COUNT(DISTINCT user_id) as unique_users,
           COALESCE(AVG(duration_seconds) FILTER (WHERE duration_seconds > 0), 0)::int as avg_duration_sec
    FROM app.user_navigation_events
    WHERE created_at >= v_since
    GROUP BY screen_name
    ORDER BY visits DESC
    LIMIT p_limit
  ) t;

  -- Top tabs (screen + tab combos)
  SELECT jsonb_agg(row_to_json(t))
  INTO v_top_tabs
  FROM (
    SELECT screen_name, tab_name, tab_index, COUNT(*) as visits, COUNT(DISTINCT user_id) as unique_users
    FROM app.user_navigation_events
    WHERE created_at >= v_since AND tab_name IS NOT NULL
    GROUP BY screen_name, tab_name, tab_index
    ORDER BY visits DESC
    LIMIT p_limit
  ) t;

  -- Daily activity
  SELECT jsonb_agg(row_to_json(t))
  INTO v_daily_activity
  FROM (
    SELECT created_at::date as day, COUNT(*) as events, COUNT(DISTINCT user_id) as users
    FROM app.user_navigation_events
    WHERE created_at >= v_since
    GROUP BY created_at::date
    ORDER BY day DESC
  ) t;

  -- Totals
  SELECT COUNT(DISTINCT user_id), COUNT(*)
  INTO v_unique_users, v_total_events
  FROM app.user_navigation_events
  WHERE created_at >= v_since;

  RETURN jsonb_build_object(
    'success', true,
    'period_days', p_days,
    'unique_users', v_unique_users,
    'total_events', v_total_events,
    'top_screens', COALESCE(v_top_screens, '[]'::jsonb),
    'top_tabs', COALESCE(v_top_tabs, '[]'::jsonb),
    'daily_activity', COALESCE(v_daily_activity, '[]'::jsonb)
  );
END;
$$;
