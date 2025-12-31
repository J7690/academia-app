-- Suivi de présence et dernière activité des utilisateurs
-- Table de présence + RPC de mise à jour par l'application

CREATE TABLE IF NOT EXISTS app.user_presence (
    user_id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app.user_presence ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_presence_self ON app.user_presence;
CREATE POLICY user_presence_self
ON app.user_presence
FOR SELECT
USING (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.user_presence TO service_role;
GRANT SELECT ON app.user_presence TO authenticated;

CREATE OR REPLACE FUNCTION app_track_user_activity()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  INSERT INTO app.user_presence (user_id, last_activity_at)
  VALUES (v_user_id, NOW())
  ON CONFLICT (user_id)
  DO UPDATE SET last_activity_at = EXCLUDED.last_activity_at;

  RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_track_user_activity() TO authenticated;
GRANT EXECUTE ON FUNCTION app_track_user_activity() TO service_role;
