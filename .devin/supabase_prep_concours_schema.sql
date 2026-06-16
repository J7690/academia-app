-- ═══════════════════════════════════════════════════════════════════
-- SCHEMA: Préparation Concours — Tables + RPCs
-- Module complet: Quiz, Flashcards, Exam Papers, AI Tutor, Gamification
-- ═══════════════════════════════════════════════════════════════════

-- ─── 1. BANQUES DE QUESTIONS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS app.td_question_banks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  concours_type TEXT, -- ENAM, ENS, ENSET, BAC, BEPC, IRIC
  subject TEXT NOT NULL,
  created_by UUID REFERENCES auth.users(id),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.td_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_id UUID REFERENCES app.td_question_banks(id) ON DELETE CASCADE,
  question_type TEXT NOT NULL DEFAULT 'qcm', -- qcm, true_false, open
  content TEXT NOT NULL,
  options JSONB DEFAULT '[]'::jsonb, -- ["Option A", "Option B", ...]
  correct_index INTEGER DEFAULT 0,
  explanation TEXT,
  difficulty INTEGER DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
  subject TEXT,
  tags TEXT[] DEFAULT '{}',
  points INTEGER DEFAULT 10,
  time_limit_seconds INTEGER DEFAULT 60,
  image_url TEXT,
  created_by UUID REFERENCES auth.users(id),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 2. QUIZ / EXAMENS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS app.td_quiz_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  bank_id UUID REFERENCES app.td_question_banks(id),
  concours_type TEXT,
  subject TEXT,
  question_count INTEGER DEFAULT 10,
  time_limit_minutes INTEGER,
  shuffle_questions BOOLEAN DEFAULT TRUE,
  is_exam_mode BOOLEAN DEFAULT FALSE,
  passing_score INTEGER DEFAULT 60,
  created_by UUID REFERENCES auth.users(id),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.td_quiz_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID REFERENCES app.td_quiz_templates(id),
  student_id UUID NOT NULL REFERENCES auth.users(id),
  questions_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  answers_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  score NUMERIC(5,2) DEFAULT 0,
  total_points INTEGER DEFAULT 0,
  correct_count INTEGER DEFAULT 0,
  question_count INTEGER DEFAULT 0,
  time_spent_seconds INTEGER DEFAULT 0,
  status TEXT DEFAULT 'in_progress', -- in_progress, completed, abandoned
  started_at TIMESTAMPTZ DEFAULT now(),
  finished_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 3. FLASHCARDS (SM-2) ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS app.td_flashcard_decks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  subject TEXT,
  concours_type TEXT,
  card_count INTEGER DEFAULT 0,
  created_by UUID REFERENCES auth.users(id),
  is_public BOOLEAN DEFAULT TRUE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.td_flashcards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deck_id UUID REFERENCES app.td_flashcard_decks(id) ON DELETE CASCADE,
  front_text TEXT NOT NULL,
  back_text TEXT NOT NULL,
  subject TEXT,
  tags TEXT[] DEFAULT '{}',
  image_url TEXT,
  created_by UUID REFERENCES auth.users(id),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.td_flashcard_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  flashcard_id UUID REFERENCES app.td_flashcards(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES auth.users(id),
  ease_factor NUMERIC(4,2) DEFAULT 2.50,
  interval_days INTEGER DEFAULT 1,
  repetitions INTEGER DEFAULT 0,
  next_review_at TIMESTAMPTZ DEFAULT now(),
  last_reviewed_at TIMESTAMPTZ,
  quality_history JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(flashcard_id, student_id)
);

-- ─── 4. SUJETS / ÉPREUVES ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS app.td_exam_papers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  concours_type TEXT NOT NULL,
  year TEXT,
  subject TEXT NOT NULL,
  paper_url TEXT,
  correction_url TEXT,
  difficulty INTEGER DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
  is_official BOOLEAN DEFAULT FALSE,
  has_correction BOOLEAN DEFAULT FALSE,
  uploaded_by UUID REFERENCES auth.users(id),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 5. PROGRESSION / GAMIFICATION ──────────────────────────────
CREATE TABLE IF NOT EXISTS app.td_student_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES auth.users(id),
  subject TEXT,
  total_questions_answered INTEGER DEFAULT 0,
  correct_count INTEGER DEFAULT 0,
  total_quizzes_completed INTEGER DEFAULT 0,
  total_flashcards_reviewed INTEGER DEFAULT 0,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  total_xp INTEGER DEFAULT 0,
  level INTEGER DEFAULT 1,
  last_activity_date DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, subject)
);

CREATE TABLE IF NOT EXISTS app.td_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  emoji TEXT,
  xp_reward INTEGER DEFAULT 0,
  condition_type TEXT, -- streak, correct_count, quiz_count, xp, perfect_score
  condition_value INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.td_student_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES auth.users(id),
  badge_id UUID REFERENCES app.td_badges(id) ON DELETE CASCADE,
  earned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, badge_id)
);

-- ─── 6. IA TUTOR ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS app.td_ai_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES auth.users(id),
  title TEXT,
  subject TEXT,
  message_count INTEGER DEFAULT 0,
  total_tokens_used INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.td_ai_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES app.td_ai_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL, -- user, assistant, system
  content TEXT NOT NULL,
  tokens_used INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 7. AI CONFIG (admin) ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS app.td_ai_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  config_key TEXT UNIQUE NOT NULL,
  config_value TEXT,
  description TEXT,
  updated_by UUID REFERENCES auth.users(id),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════════════
-- SEED: Badges par défaut
-- ═══════════════════════════════════════════════════════════════════
INSERT INTO app.td_badges (code, title, description, emoji, xp_reward, condition_type, condition_value)
VALUES
  ('first_star', 'Première étoile', 'Complète ton premier quiz', '🌟', 10, 'quiz_count', 1),
  ('flame_7', 'Flamme', '7 jours de streak consécutifs', '🔥', 50, 'streak', 7),
  ('bookworm', 'Rat de bibliothèque', '100 réponses correctes', '📚', 100, 'correct_count', 100),
  ('sharpshooter', 'Tireur d''élite', '10 quiz avec score parfait', '🎯', 200, 'perfect_score', 10),
  ('genius', 'Génie', '500 réponses correctes', '🧠', 500, 'correct_count', 500),
  ('champion', 'Champion', 'Atteins le top 3 du classement', '🏆', 300, 'xp', 0),
  ('diamond', 'Diamant', 'Atteins le niveau 10', '💎', 1000, 'xp', 1000),
  ('lightning', 'Éclair', '50 réponses correctes en une journée', '⚡', 150, 'correct_count', 50)
ON CONFLICT (code) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════
-- SEED: AI Config par défaut
-- ═══════════════════════════════════════════════════════════════════
INSERT INTO app.td_ai_config (config_key, config_value, description)
VALUES
  ('gemini_api_key', '', 'Clé API Google Gemini (à remplir par l''admin)'),
  ('ai_model', 'gemini-2.0-flash', 'Modèle IA à utiliser'),
  ('max_messages_per_day', '50', 'Limite de messages IA par étudiant par jour'),
  ('system_prompt', 'Tu es un tuteur expert en préparation aux concours camerounais (ENAM, ENS, ENSET, BAC, BEPC, IRIC). Tu expliques les concepts pas à pas, tu proposes des exercices, tu corriges les erreurs avec bienveillance. Tu t''adaptes au niveau de l''étudiant. Langue : français. Contexte : système éducatif camerounais.', 'Prompt système pour le tuteur IA')
ON CONFLICT (config_key) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════
-- RLS Policies
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE app.td_question_banks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_quiz_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_flashcard_decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_flashcard_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_exam_papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_student_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_student_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.td_ai_config ENABLE ROW LEVEL SECURITY;

-- Service role bypass (RPCs use service role)
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_question_banks FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_questions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_quiz_templates FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_quiz_attempts FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_flashcard_decks FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_flashcards FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_flashcard_progress FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_exam_papers FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_student_progress FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_badges FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_student_badges FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_ai_conversations FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_ai_messages FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "service_role_all" ON app.td_ai_config FOR ALL TO service_role USING (true) WITH CHECK (true)
