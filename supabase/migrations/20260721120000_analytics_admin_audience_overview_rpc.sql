-- RPC agregats Audience — ADMIN UNIQUEMENT (T3) — appliquee en prod le 2026-07-21 via MCP.
CREATE OR REPLACE FUNCTION public.app_admin_audience_overview(p_days integer DEFAULT 7)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public'
AS $$
DECLARE
  v_since timestamptz := now() - make_interval(days => greatest(least(coalesce(p_days,7), 90), 1));
  v_result jsonb;
BEGIN
  IF NOT app.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  SELECT jsonb_build_object(
    'success', true,
    'since', v_since,
    'totals', (
      SELECT jsonb_build_object(
        'events', count(*),
        'visitors', count(DISTINCT visitor_id),
        'logged_users', count(DISTINCT user_id) FILTER (WHERE user_id IS NOT NULL),
        'anonymous_visitors', count(DISTINCT visitor_id) FILTER (WHERE user_id IS NULL)
      ) FROM app.analytics_events WHERE created_at >= v_since
    ),
    'platforms', (
      SELECT coalesce(jsonb_agg(jsonb_build_object('platform', platform, 'events', n) ORDER BY n DESC), '[]'::jsonb)
      FROM (SELECT platform, count(*) n FROM app.analytics_events
            WHERE created_at >= v_since GROUP BY platform) p
    ),
    'top_screens', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'screen', screen_name, 'views', views, 'visitors', visitors,
        'avg_duration', avg_duration) ORDER BY views DESC), '[]'::jsonb)
      FROM (
        SELECT screen_name, count(*) views, count(DISTINCT visitor_id) visitors,
               round(avg(duration_seconds) FILTER (WHERE duration_seconds > 0)) avg_duration
        FROM app.analytics_events
        WHERE created_at >= v_since AND event_type = 'screen_view' AND screen_name IS NOT NULL
        GROUP BY screen_name ORDER BY count(*) DESC LIMIT 20
      ) s
    ),
    'top_entities', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'entity_type', entity_type, 'entity_id', entity_id,
        'views', views, 'visitors', visitors) ORDER BY views DESC), '[]'::jsonb)
      FROM (
        SELECT entity_type, entity_id, count(*) views, count(DISTINCT visitor_id) visitors
        FROM app.analytics_events
        WHERE created_at >= v_since AND entity_type IS NOT NULL
        GROUP BY entity_type, entity_id ORDER BY count(*) DESC LIMIT 20
      ) e
    ),
    'top_searches', (
      SELECT coalesce(jsonb_agg(jsonb_build_object('query', q, 'searches', n) ORDER BY n DESC), '[]'::jsonb)
      FROM (
        SELECT properties->>'query' q, count(*) n
        FROM app.analytics_events
        WHERE created_at >= v_since AND event_type = 'search' AND properties ? 'query'
        GROUP BY 1 ORDER BY count(*) DESC LIMIT 15
      ) q
    ),
    'daily', (
      SELECT coalesce(jsonb_agg(jsonb_build_object('day', d, 'events', n, 'visitors', v) ORDER BY d), '[]'::jsonb)
      FROM (
        SELECT date_trunc('day', created_at)::date d, count(*) n, count(DISTINCT visitor_id) v
        FROM app.analytics_events WHERE created_at >= v_since GROUP BY 1
      ) dd
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.app_admin_audience_overview(integer) FROM public;
GRANT EXECUTE ON FUNCTION public.app_admin_audience_overview(integer) TO authenticated;
