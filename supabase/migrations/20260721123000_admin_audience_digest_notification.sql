-- Notification admin « activite / parcours » — digest agrege (anti-spam).
-- Appliquee en prod le 2026-07-21 via MCP. Reutilise le pipeline notification_events.
CREATE TABLE IF NOT EXISTS app.audience_digest_state (
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  last_run timestamptz NOT NULL DEFAULT now()
);
INSERT INTO app.audience_digest_state (id, last_run)
VALUES (true, now()) ON CONFLICT (id) DO NOTHING;
ALTER TABLE app.audience_digest_state ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION app.enqueue_admin_audience_digest()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public'
AS $$
DECLARE
  v_since timestamptz;
  v_now timestamptz := now();
  v_events integer;
  v_visitors integer;
  v_anon integer;
  v_offer_views integer;
  v_top_screen text;
  v_admin record;
  v_payload jsonb;
  v_count integer := 0;
BEGIN
  SELECT last_run INTO v_since FROM app.audience_digest_state WHERE id;
  IF v_since IS NULL THEN v_since := v_now - interval '15 minutes'; END IF;

  SELECT count(*), count(DISTINCT visitor_id),
         count(DISTINCT visitor_id) FILTER (WHERE user_id IS NULL),
         count(*) FILTER (WHERE entity_type IS NOT NULL)
  INTO v_events, v_visitors, v_anon, v_offer_views
  FROM app.analytics_events
  WHERE created_at > v_since AND created_at <= v_now;

  UPDATE app.audience_digest_state SET last_run = v_now WHERE id;

  IF coalesce(v_events, 0) = 0 THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'no_activity');
  END IF;

  SELECT screen_name INTO v_top_screen
  FROM app.analytics_events
  WHERE created_at > v_since AND created_at <= v_now
    AND event_type = 'screen_view' AND screen_name IS NOT NULL
  GROUP BY screen_name ORDER BY count(*) DESC LIMIT 1;

  v_payload := jsonb_build_object(
    'events', v_events, 'visitors', v_visitors, 'anonymous', v_anon,
    'offer_views', v_offer_views, 'top_screen', coalesce(v_top_screen, ''),
    'window_minutes', round(extract(epoch FROM (v_now - v_since)) / 60)
  );

  FOR v_admin IN SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin' LOOP
    PERFORM app.fn_enqueue_notification_event(v_admin.id, 'admin_audience', 'activity_digest', v_payload);
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'notified_admins', v_count, 'payload', v_payload);
END;
$$;

REVOKE ALL ON FUNCTION app.enqueue_admin_audience_digest() FROM public, anon, authenticated;

SELECT cron.schedule('admin-audience-digest', '*/15 * * * *',
  $$SELECT app.enqueue_admin_audience_digest();$$);
