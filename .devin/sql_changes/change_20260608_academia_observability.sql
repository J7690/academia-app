-- Phase 14 : Table d'observabilité pour le Learning Engine

CREATE TABLE IF NOT EXISTS app.academia_session_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES app.academia_sessions(id) ON DELETE CASCADE,
  user_id UUID,
  event_type TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_session_events_session ON app.academia_session_events(session_id);
CREATE INDEX idx_session_events_type ON app.academia_session_events(event_type);
CREATE INDEX idx_session_events_created ON app.academia_session_events(created_at DESC);

-- RLS
ALTER TABLE app.academia_session_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_insert_session_events"
  ON app.academia_session_events FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "admin_read_session_events"
  ON app.academia_session_events FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM app.user_admin_status WHERE user_id = auth.uid() AND is_active = TRUE)
    OR user_id = auth.uid()
  );
