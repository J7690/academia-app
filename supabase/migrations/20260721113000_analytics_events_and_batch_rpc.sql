-- Analytics parcours utilisateurs (T1) — appliquee en prod le 2026-07-21 via MCP.
-- Table neuve + RPC ingestion batch (anonyme + connecte). Lecture admin uniquement.

CREATE TABLE app.analytics_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visitor_id text NOT NULL,
  user_id uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  session_id text NULL,
  event_type text NOT NULL,
  screen_name text NULL,
  entity_type text NULL,
  entity_id text NULL,
  properties jsonb NOT NULL DEFAULT '{}'::jsonb,
  platform text NULL,
  duration_seconds integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_analytics_events_created_at ON app.analytics_events (created_at DESC);
CREATE INDEX idx_analytics_events_visitor ON app.analytics_events (visitor_id, created_at DESC);
CREATE INDEX idx_analytics_events_user ON app.analytics_events (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_analytics_events_entity ON app.analytics_events (entity_type, entity_id) WHERE entity_type IS NOT NULL;
CREATE INDEX idx_analytics_events_type_screen ON app.analytics_events (event_type, screen_name);

ALTER TABLE app.analytics_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY analytics_events_admin_select ON app.analytics_events
  FOR SELECT USING (app.is_admin());

REVOKE ALL ON app.analytics_events FROM anon, authenticated;
GRANT SELECT ON app.analytics_events TO authenticated;

CREATE OR REPLACE FUNCTION public.app_track_events_batch(
  p_visitor_id text,
  p_platform text,
  p_events jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public'
AS $$
DECLARE
  v_event jsonb;
  v_count integer := 0;
BEGIN
  IF p_visitor_id IS NULL OR length(p_visitor_id) < 8 OR length(p_visitor_id) > 64 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_visitor_id');
  END IF;
  IF p_events IS NULL OR jsonb_typeof(p_events) <> 'array' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_events');
  END IF;
  IF jsonb_array_length(p_events) > 50 THEN
    RETURN jsonb_build_object('success', false, 'error', 'batch_too_large');
  END IF;

  FOR v_event IN SELECT * FROM jsonb_array_elements(p_events) LOOP
    INSERT INTO app.analytics_events (
      visitor_id, user_id, session_id, event_type, screen_name,
      entity_type, entity_id, properties, platform, duration_seconds
    ) VALUES (
      p_visitor_id,
      auth.uid(),
      left(coalesce(v_event->>'session_id',''), 64),
      left(coalesce(v_event->>'event_type','unknown'), 40),
      left(v_event->>'screen_name', 80),
      left(v_event->>'entity_type', 40),
      left(v_event->>'entity_id', 80),
      CASE WHEN jsonb_typeof(v_event->'properties') = 'object'
           THEN v_event->'properties' ELSE '{}'::jsonb END,
      left(coalesce(p_platform,'unknown'), 20),
      least(greatest(coalesce((v_event->>'duration_seconds')::integer, 0), 0), 86400)
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'inserted', v_count);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.app_track_events_batch(text, text, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.app_track_events_batch(text, text, jsonb) TO anon, authenticated;
