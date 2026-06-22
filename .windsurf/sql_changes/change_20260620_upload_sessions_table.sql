-- Create upload_sessions table for resumable upload protocol
-- Based on YouTube/TikTok best practices
-- Date: 20 Juin 2026

-- Create table
CREATE TABLE IF NOT EXISTS app.upload_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket TEXT NOT NULL,
  path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  content_type TEXT NOT NULL,
  uploaded_bytes BIGINT DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'initialized', -- initialized, uploading, completed, failed, expired
  final_path TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_upload_sessions_user ON app.upload_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_upload_sessions_status ON app.upload_sessions(status);
CREATE INDEX IF NOT EXISTS idx_upload_sessions_expires_at ON app.upload_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_upload_sessions_created_at ON app.upload_sessions(created_at DESC);

-- Add RLS policies
ALTER TABLE app.upload_sessions ENABLE ROW LEVEL SECURITY;

-- Users can only see their own upload sessions
CREATE POLICY "Users can view own upload sessions"
  ON app.upload_sessions FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own upload sessions
CREATE POLICY "Users can insert own upload sessions"
  ON app.upload_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own upload sessions
CREATE POLICY "Users can update own upload sessions"
  ON app.upload_sessions FOR UPDATE
  USING (auth.uid() = user_id);

-- Service role can do everything
CREATE POLICY "Service role full access to upload_sessions"
  ON app.upload_sessions FOR ALL
  USING (auth.role() = 'service_role');

-- Add trigger to auto-expire old sessions
CREATE OR REPLACE FUNCTION app.cleanup_expired_upload_sessions()
RETURNS void AS $$
BEGIN
  UPDATE app.upload_sessions
  SET status = 'expired'
  WHERE status IN ('initialized', 'uploading')
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Create trigger to run cleanup before any query on upload_sessions
CREATE OR REPLACE TRIGGER trigger_cleanup_expired_upload_sessions
  BEFORE SELECT OR INSERT OR UPDATE OR DELETE ON app.upload_sessions
  FOR EACH STATEMENT EXECUTE FUNCTION app.cleanup_expired_upload_sessions();

-- Add comment
COMMENT ON TABLE app.upload_sessions IS 'Resumable upload sessions following YouTube/TikTok protocol with Content-Range headers';
