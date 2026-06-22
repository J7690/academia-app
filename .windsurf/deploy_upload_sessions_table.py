#!/usr/bin/env python3
"""
Deploy upload_sessions table to Supabase
Resumable upload protocol following YouTube/TikTok best practices
"""

import os
import sys
from supabase import create_client, Client

# Load environment variables
SUPABASE_URL = os.environ.get('SUPABASE_URL')
SUPABASE_SERVICE_ROLE_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    print("ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set")
    sys.exit(1)

# Create Supabase client
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

# SQL migration
SQL_MIGRATION = """
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
CREATE POLICY IF NOT EXISTS "Users can view own upload sessions"
  ON app.upload_sessions FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own upload sessions
CREATE POLICY IF NOT EXISTS "Users can insert own upload sessions"
  ON app.upload_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own upload sessions
CREATE POLICY IF NOT EXISTS "Users can update own upload sessions"
  ON app.upload_sessions FOR UPDATE
  USING (auth.uid() = user_id);

-- Service role can do everything
CREATE POLICY IF NOT EXISTS "Service role full access to upload_sessions"
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
DROP TRIGGER IF EXISTS trigger_cleanup_expired_upload_sessions ON app.upload_sessions;
CREATE TRIGGER trigger_cleanup_expired_upload_sessions
  BEFORE SELECT OR INSERT OR UPDATE OR DELETE ON app.upload_sessions
  FOR EACH STATEMENT EXECUTE FUNCTION app.cleanup_expired_upload_sessions();

-- Add comment
COMMENT ON TABLE app.upload_sessions IS 'Resumable upload sessions following YouTube/TikTok protocol with Content-Range headers';
"""

def main():
    print("Deploying upload_sessions table to Supabase...")
    print(f"Supabase URL: {SUPABASE_URL}")
    
    try:
        # Execute SQL migration
        result = supabase.rpc('exec_sql', params={'sql': SQL_MIGRATION})
        print("✓ Migration executed successfully")
    except Exception as e:
        # Try direct SQL execution via pgadmin or supabase CLI
        print(f"Note: Could not execute via RPC (may not exist)")
        print(f"Please run the SQL manually in Supabase SQL Editor:")
        print(f"\n{SQL_MIGRATION}")
        return
    
    print("\n✓ upload_sessions table created successfully")
    print("\nNext steps:")
    print("1. Deploy Edge Functions: create-upload-session, complete-upload-session")
    print("2. Update Flutter screens to use ResumableUploadService")
    print("3. Test the complete pipeline")

if __name__ == '__main__':
    main()
