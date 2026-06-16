-- ============================================================
-- Academia Learning Engine — Table unifiée academia_sessions
-- Migration: 2026-06-07
-- ============================================================

-- 1. Type enum pour session_type
DO $$ BEGIN
  CREATE TYPE app.academia_session_type AS ENUM (
    'course', 'td', 'prep_concours', 'orientation',
    'conference', 'masterclass', 'live_pedagogique',
    'revision_collective', 'exam_blanc', 'game_challenge'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. Type enum pour session_status
DO $$ BEGIN
  CREATE TYPE app.academia_session_status AS ENUM (
    'draft', 'scheduled', 'pending_approval', 'approved',
    'running', 'paused', 'ended', 'cancelled', 'rejected'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. Table principale unifiée
CREATE TABLE IF NOT EXISTS app.academia_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_type app.academia_session_type NOT NULL DEFAULT 'course',
  status app.academia_session_status NOT NULL DEFAULT 'draft',
  provider TEXT NOT NULL DEFAULT 'livekit', -- livekit | zoom | meet | external

  -- Identité
  title TEXT NOT NULL,
  description TEXT,
  subject TEXT,
  concours_type TEXT,

  -- Relations
  host_id UUID NOT NULL REFERENCES auth.users(id),
  course_id UUID, -- FK vers online_courses si applicable
  program_id UUID, -- FK vers td_programs si applicable

  -- Planification
  scheduled_start TIMESTAMPTZ,
  scheduled_end TIMESTAMPTZ,
  actual_start TIMESTAMPTZ,
  actual_end TIMESTAMPTZ,

  -- Capacité
  max_participants INT DEFAULT 100,
  current_participants INT DEFAULT 0,

  -- Configuration features
  is_recording_enabled BOOLEAN DEFAULT TRUE,
  is_whiteboard_enabled BOOLEAN DEFAULT FALSE,
  is_quiz_enabled BOOLEAN DEFAULT TRUE,
  is_chat_enabled BOOLEAN DEFAULT TRUE,
  is_screen_share_enabled BOOLEAN DEFAULT TRUE,
  is_hand_raise_enabled BOOLEAN DEFAULT TRUE,

  -- Replay
  replay_url TEXT,
  replay_video_asset_id UUID,
  chapters JSONB DEFAULT '[]'::JSONB,

  -- LiveKit
  livekit_room_name TEXT,

  -- Métadonnées
  thumbnail_url TEXT,
  metadata JSONB DEFAULT '{}'::JSONB,

  -- Audit
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Contraintes
  CONSTRAINT chk_title_not_empty CHECK (char_length(title) > 0)
);

-- 4. Table participants
CREATE TABLE IF NOT EXISTS app.academia_session_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES app.academia_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  role TEXT NOT NULL DEFAULT 'participant', -- host, co_host, participant, observer
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  left_at TIMESTAMPTZ,
  duration_seconds INT DEFAULT 0,
  is_hand_raised BOOLEAN DEFAULT FALSE,
  is_muted BOOLEAN DEFAULT FALSE,
  is_camera_on BOOLEAN DEFAULT FALSE,
  metadata JSONB DEFAULT '{}'::JSONB,

  CONSTRAINT uq_session_participant UNIQUE (session_id, user_id)
);

-- 5. Table présence (tracking détaillé)
CREATE TABLE IF NOT EXISTS app.academia_session_presence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES app.academia_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  event_type TEXT NOT NULL, -- 'join', 'leave', 'reconnect', 'idle', 'active'
  event_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::JSONB
);

-- 6. Table chat messages (persistés en DB pour replay)
CREATE TABLE IF NOT EXISTS app.academia_session_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES app.academia_sessions(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  sender_name TEXT,
  content TEXT NOT NULL,
  message_type TEXT DEFAULT 'text', -- text, reaction, system, quiz_answer, file
  reply_to_id UUID,
  metadata JSONB DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Table quiz questions (pour quiz live persistés)
CREATE TABLE IF NOT EXISTS app.academia_session_quiz_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES app.academia_sessions(id) ON DELETE CASCADE,
  question_index INT NOT NULL DEFAULT 0,
  question_text TEXT NOT NULL,
  options JSONB NOT NULL DEFAULT '[]'::JSONB, -- ["A","B","C","D"]
  correct_index INT NOT NULL DEFAULT 0,
  time_limit_seconds INT DEFAULT 30,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Table quiz answers
CREATE TABLE IF NOT EXISTS app.academia_session_quiz_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id UUID NOT NULL REFERENCES app.academia_session_quiz_questions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  selected_index INT NOT NULL,
  answered_at TIMESTAMPTZ DEFAULT NOW(),
  is_correct BOOLEAN DEFAULT FALSE,

  CONSTRAINT uq_quiz_answer UNIQUE (question_id, user_id)
);

-- 9. Indexes
CREATE INDEX IF NOT EXISTS idx_academia_sessions_host ON app.academia_sessions(host_id);
CREATE INDEX IF NOT EXISTS idx_academia_sessions_type ON app.academia_sessions(session_type);
CREATE INDEX IF NOT EXISTS idx_academia_sessions_status ON app.academia_sessions(status);
CREATE INDEX IF NOT EXISTS idx_academia_sessions_scheduled ON app.academia_sessions(scheduled_start);
CREATE INDEX IF NOT EXISTS idx_academia_sessions_course ON app.academia_sessions(course_id) WHERE course_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_academia_session_participants_session ON app.academia_session_participants(session_id);
CREATE INDEX IF NOT EXISTS idx_academia_session_participants_user ON app.academia_session_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_academia_session_presence_session ON app.academia_session_presence(session_id);
CREATE INDEX IF NOT EXISTS idx_academia_session_messages_session ON app.academia_session_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_academia_session_quiz_session ON app.academia_session_quiz_questions(session_id);

-- 10. Trigger updated_at
CREATE OR REPLACE FUNCTION app.fn_academia_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_academia_sessions_updated_at ON app.academia_sessions;
CREATE TRIGGER trg_academia_sessions_updated_at
  BEFORE UPDATE ON app.academia_sessions
  FOR EACH ROW EXECUTE FUNCTION app.fn_academia_sessions_updated_at();

-- 11. RLS Policies
ALTER TABLE app.academia_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.academia_session_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.academia_session_presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.academia_session_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.academia_session_quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.academia_session_quiz_answers ENABLE ROW LEVEL SECURITY;

-- Sessions: lecture pour tous auth, écriture pour host + admin
CREATE POLICY sessions_select ON app.academia_sessions FOR SELECT TO authenticated
  USING (TRUE);
CREATE POLICY sessions_insert ON app.academia_sessions FOR INSERT TO authenticated
  WITH CHECK (host_id = auth.uid());
CREATE POLICY sessions_update ON app.academia_sessions FOR UPDATE TO authenticated
  USING (host_id = auth.uid());
CREATE POLICY sessions_service ON app.academia_sessions FOR ALL TO service_role
  USING (TRUE) WITH CHECK (TRUE);

-- Participants: lecture pour membres session, écriture via service_role
CREATE POLICY participants_select ON app.academia_session_participants FOR SELECT TO authenticated
  USING (TRUE);
CREATE POLICY participants_service ON app.academia_session_participants FOR ALL TO service_role
  USING (TRUE) WITH CHECK (TRUE);

-- Presence: lecture session members, écriture via service_role
CREATE POLICY presence_select ON app.academia_session_presence FOR SELECT TO authenticated
  USING (TRUE);
CREATE POLICY presence_service ON app.academia_session_presence FOR ALL TO service_role
  USING (TRUE) WITH CHECK (TRUE);

-- Messages: lecture tous auth, écriture sender
CREATE POLICY messages_select ON app.academia_session_messages FOR SELECT TO authenticated
  USING (TRUE);
CREATE POLICY messages_insert ON app.academia_session_messages FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid());
CREATE POLICY messages_service ON app.academia_session_messages FOR ALL TO service_role
  USING (TRUE) WITH CHECK (TRUE);

-- Quiz questions: lecture tous, écriture host
CREATE POLICY quiz_q_select ON app.academia_session_quiz_questions FOR SELECT TO authenticated
  USING (TRUE);
CREATE POLICY quiz_q_service ON app.academia_session_quiz_questions FOR ALL TO service_role
  USING (TRUE) WITH CHECK (TRUE);

-- Quiz answers: lecture tous, écriture propre réponse
CREATE POLICY quiz_a_select ON app.academia_session_quiz_answers FOR SELECT TO authenticated
  USING (TRUE);
CREATE POLICY quiz_a_insert ON app.academia_session_quiz_answers FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
CREATE POLICY quiz_a_service ON app.academia_session_quiz_answers FOR ALL TO service_role
  USING (TRUE) WITH CHECK (TRUE);

-- 12. Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE app.academia_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE app.academia_session_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE app.academia_session_messages;
