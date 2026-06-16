-- ═══════════════════════════════════════════════════════════════════
-- RPCs: Préparation Concours — Fonctions RPC pour Flutter
-- ═══════════════════════════════════════════════════════════════════

-- ─── QUIZ: Lister les banques de questions ───────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_list_question_banks(
  p_concours_type TEXT DEFAULT NULL,
  p_subject TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(r))
  INTO v_result
  FROM (
    SELECT qb.id, qb.title, qb.description, qb.concours_type, qb.subject,
           qb.is_active, qb.created_at,
           (SELECT count(*) FROM app.td_questions q WHERE q.bank_id = qb.id AND q.is_active) AS question_count
    FROM app.td_question_banks qb
    WHERE qb.is_active = TRUE
      AND (p_concours_type IS NULL OR qb.concours_type = p_concours_type)
      AND (p_subject IS NULL OR qb.subject = p_subject)
    ORDER BY qb.created_at DESC
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── QUIZ: Lister les questions d'une banque ─────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_list_questions(
  p_bank_id UUID DEFAULT NULL,
  p_concours_type TEXT DEFAULT NULL,
  p_subject TEXT DEFAULT NULL,
  p_difficulty INTEGER DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(r))
  INTO v_result
  FROM (
    SELECT q.id, q.bank_id, q.question_type, q.content, q.options,
           q.correct_index, q.explanation, q.difficulty, q.subject,
           q.tags, q.points, q.time_limit_seconds, q.image_url
    FROM app.td_questions q
    WHERE q.is_active = TRUE
      AND (p_bank_id IS NULL OR q.bank_id = p_bank_id)
      AND (p_concours_type IS NULL OR q.bank_id IN (
        SELECT id FROM app.td_question_banks WHERE concours_type = p_concours_type
      ))
      AND (p_subject IS NULL OR q.subject = p_subject)
      AND (p_difficulty IS NULL OR q.difficulty = p_difficulty)
    ORDER BY random()
    LIMIT p_limit
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── QUIZ: Créer une question (enseignant/admin) ────────────────
CREATE OR REPLACE FUNCTION app.app_prep_create_question(
  p_bank_id UUID,
  p_content TEXT,
  p_options JSONB,
  p_correct_index INTEGER,
  p_explanation TEXT DEFAULT NULL,
  p_difficulty INTEGER DEFAULT 1,
  p_subject TEXT DEFAULT NULL,
  p_tags TEXT[] DEFAULT '{}',
  p_question_type TEXT DEFAULT 'qcm',
  p_points INTEGER DEFAULT 10,
  p_time_limit_seconds INTEGER DEFAULT 60,
  p_image_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_question_id UUID;
BEGIN
  INSERT INTO app.td_questions (
    bank_id, question_type, content, options, correct_index,
    explanation, difficulty, subject, tags, points,
    time_limit_seconds, image_url, created_by
  ) VALUES (
    p_bank_id, p_question_type, p_content, p_options, p_correct_index,
    p_explanation, p_difficulty, p_subject, p_tags, p_points,
    p_time_limit_seconds, p_image_url, auth.uid()
  )
  RETURNING id INTO v_question_id;

  RETURN jsonb_build_object('success', true, 'question_id', v_question_id);
END;
$$;

-- ─── QUIZ: Créer une banque de questions (enseignant/admin) ──────
CREATE OR REPLACE FUNCTION app.app_prep_create_question_bank(
  p_title TEXT,
  p_description TEXT DEFAULT NULL,
  p_concours_type TEXT DEFAULT NULL,
  p_subject TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_bank_id UUID;
BEGIN
  INSERT INTO app.td_question_banks (title, description, concours_type, subject, created_by)
  VALUES (p_title, p_description, p_concours_type, p_subject, auth.uid())
  RETURNING id INTO v_bank_id;

  RETURN jsonb_build_object('success', true, 'bank_id', v_bank_id);
END;
$$;

-- ─── QUIZ: Sauvegarder un attempt ───────────────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_save_quiz_attempt(
  p_template_id UUID DEFAULT NULL,
  p_questions_json JSONB DEFAULT '[]',
  p_answers_json JSONB DEFAULT '[]',
  p_score NUMERIC DEFAULT 0,
  p_total_points INTEGER DEFAULT 0,
  p_correct_count INTEGER DEFAULT 0,
  p_question_count INTEGER DEFAULT 0,
  p_time_spent_seconds INTEGER DEFAULT 0,
  p_status TEXT DEFAULT 'completed'
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_attempt_id UUID;
  v_student_id UUID := auth.uid();
  v_xp_earned INTEGER := 0;
  v_pct NUMERIC;
BEGIN
  INSERT INTO app.td_quiz_attempts (
    template_id, student_id, questions_json, answers_json,
    score, total_points, correct_count, question_count,
    time_spent_seconds, status, finished_at
  ) VALUES (
    p_template_id, v_student_id, p_questions_json, p_answers_json,
    p_score, p_total_points, p_correct_count, p_question_count,
    p_time_spent_seconds, p_status,
    CASE WHEN p_status = 'completed' THEN now() ELSE NULL END
  )
  RETURNING id INTO v_attempt_id;

  -- Calculate XP
  v_pct := CASE WHEN p_question_count > 0 THEN (p_correct_count::numeric / p_question_count) * 100 ELSE 0 END;
  v_xp_earned := 20; -- base XP
  IF v_pct >= 100 THEN v_xp_earned := v_xp_earned + 25; END IF;
  IF v_pct >= 80 THEN v_xp_earned := v_xp_earned + 10; END IF;

  -- Update progress (global)
  INSERT INTO app.td_student_progress (student_id, subject, total_questions_answered, correct_count, total_quizzes_completed, total_xp, last_activity_date)
  VALUES (v_student_id, 'global', p_question_count, p_correct_count, 1, v_xp_earned, CURRENT_DATE)
  ON CONFLICT (student_id, subject) DO UPDATE SET
    total_questions_answered = app.td_student_progress.total_questions_answered + p_question_count,
    correct_count = app.td_student_progress.correct_count + p_correct_count,
    total_quizzes_completed = app.td_student_progress.total_quizzes_completed + 1,
    total_xp = app.td_student_progress.total_xp + v_xp_earned,
    level = (app.td_student_progress.total_xp + v_xp_earned) / 100 + 1,
    current_streak = CASE
      WHEN app.td_student_progress.last_activity_date = CURRENT_DATE THEN app.td_student_progress.current_streak
      WHEN app.td_student_progress.last_activity_date = CURRENT_DATE - 1 THEN app.td_student_progress.current_streak + 1
      ELSE 1
    END,
    longest_streak = GREATEST(
      app.td_student_progress.longest_streak,
      CASE
        WHEN app.td_student_progress.last_activity_date = CURRENT_DATE THEN app.td_student_progress.current_streak
        WHEN app.td_student_progress.last_activity_date = CURRENT_DATE - 1 THEN app.td_student_progress.current_streak + 1
        ELSE 1
      END
    ),
    last_activity_date = CURRENT_DATE,
    updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'attempt_id', v_attempt_id,
    'xp_earned', v_xp_earned,
    'score_pct', v_pct
  );
END;
$$;

-- ─── QUIZ: Obtenir la progression d'un étudiant ─────────────────
CREATE OR REPLACE FUNCTION app.app_prep_get_student_progress()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
  v_student_id UUID := auth.uid();
BEGIN
  SELECT row_to_json(r)::jsonb INTO v_result
  FROM (
    SELECT sp.*,
      (SELECT jsonb_agg(row_to_json(b))
       FROM (
         SELECT sb.earned_at, bd.code, bd.title, bd.description, bd.emoji, bd.xp_reward
         FROM app.td_student_badges sb
         JOIN app.td_badges bd ON bd.id = sb.badge_id
         WHERE sb.student_id = v_student_id
         ORDER BY sb.earned_at DESC
       ) b
      ) AS badges,
      (SELECT jsonb_agg(row_to_json(a))
       FROM (
         SELECT qa.id, qa.score, qa.correct_count, qa.question_count,
                qa.time_spent_seconds, qa.status, qa.finished_at
         FROM app.td_quiz_attempts qa
         WHERE qa.student_id = v_student_id AND qa.status = 'completed'
         ORDER BY qa.finished_at DESC
         LIMIT 20
       ) a
      ) AS recent_attempts
    FROM app.td_student_progress sp
    WHERE sp.student_id = v_student_id AND sp.subject = 'global'
  ) r;

  IF v_result IS NULL THEN
    -- Create initial progress row
    INSERT INTO app.td_student_progress (student_id, subject)
    VALUES (v_student_id, 'global')
    ON CONFLICT (student_id, subject) DO NOTHING;

    v_result := jsonb_build_object(
      'total_questions_answered', 0, 'correct_count', 0,
      'total_quizzes_completed', 0, 'total_flashcards_reviewed', 0,
      'current_streak', 0, 'longest_streak', 0,
      'total_xp', 0, 'level', 1,
      'badges', '[]'::jsonb, 'recent_attempts', '[]'::jsonb
    );
  END IF;

  RETURN v_result;
END;
$$;

-- ─── QUIZ: Obtenir la progression par matière ────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_get_subject_stats()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
  v_student_id UUID := auth.uid();
BEGIN
  SELECT jsonb_agg(row_to_json(r)) INTO v_result
  FROM (
    SELECT sp.subject, sp.total_questions_answered, sp.correct_count,
           CASE WHEN sp.total_questions_answered > 0
             THEN round((sp.correct_count::numeric / sp.total_questions_answered) * 100, 1)
             ELSE 0 END AS accuracy_pct
    FROM app.td_student_progress sp
    WHERE sp.student_id = v_student_id AND sp.subject != 'global'
    ORDER BY sp.total_questions_answered DESC
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── FLASHCARDS: Lister les decks ───────────────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_list_flashcard_decks(
  p_subject TEXT DEFAULT NULL,
  p_concours_type TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(r)) INTO v_result
  FROM (
    SELECT fd.id, fd.title, fd.description, fd.subject, fd.concours_type,
           (SELECT count(*) FROM app.td_flashcards f WHERE f.deck_id = fd.id AND f.is_active) AS card_count
    FROM app.td_flashcard_decks fd
    WHERE fd.is_active = TRUE AND fd.is_public = TRUE
      AND (p_subject IS NULL OR fd.subject = p_subject)
      AND (p_concours_type IS NULL OR fd.concours_type = p_concours_type)
    ORDER BY fd.created_at DESC
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── FLASHCARDS: Lister les cartes d'un deck avec progression ───
CREATE OR REPLACE FUNCTION app.app_prep_list_flashcards(
  p_deck_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
  v_student_id UUID := auth.uid();
BEGIN
  SELECT jsonb_agg(row_to_json(r)) INTO v_result
  FROM (
    SELECT f.id, f.front_text, f.back_text, f.subject, f.tags, f.image_url,
           COALESCE(fp.ease_factor, 2.50) AS ease_factor,
           COALESCE(fp.interval_days, 1) AS interval_days,
           COALESCE(fp.repetitions, 0) AS repetitions,
           COALESCE(fp.next_review_at, now()) AS next_review_at,
           fp.last_reviewed_at
    FROM app.td_flashcards f
    LEFT JOIN app.td_flashcard_progress fp ON fp.flashcard_id = f.id AND fp.student_id = v_student_id
    WHERE f.deck_id = p_deck_id AND f.is_active = TRUE
    ORDER BY COALESCE(fp.next_review_at, now()) ASC
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── FLASHCARDS: Sauvegarder la progression d'une carte ─────────
CREATE OR REPLACE FUNCTION app.app_prep_save_flashcard_review(
  p_flashcard_id UUID,
  p_quality INTEGER, -- 0-5 (SM-2)
  p_ease_factor NUMERIC DEFAULT 2.50,
  p_interval_days INTEGER DEFAULT 1,
  p_repetitions INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID := auth.uid();
  v_next_review TIMESTAMPTZ;
BEGIN
  v_next_review := now() + (p_interval_days || ' days')::interval;

  INSERT INTO app.td_flashcard_progress (
    flashcard_id, student_id, ease_factor, interval_days,
    repetitions, next_review_at, last_reviewed_at
  ) VALUES (
    p_flashcard_id, v_student_id, p_ease_factor, p_interval_days,
    p_repetitions, v_next_review, now()
  )
  ON CONFLICT (flashcard_id, student_id) DO UPDATE SET
    ease_factor = p_ease_factor,
    interval_days = p_interval_days,
    repetitions = p_repetitions,
    next_review_at = v_next_review,
    last_reviewed_at = now();

  -- Update flashcard review count in progress
  INSERT INTO app.td_student_progress (student_id, subject, total_flashcards_reviewed, last_activity_date)
  VALUES (v_student_id, 'global', 1, CURRENT_DATE)
  ON CONFLICT (student_id, subject) DO UPDATE SET
    total_flashcards_reviewed = app.td_student_progress.total_flashcards_reviewed + 1,
    last_activity_date = CURRENT_DATE,
    updated_at = now();

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── EXAM PAPERS: Lister les sujets d'épreuves ─────────────────
CREATE OR REPLACE FUNCTION app.app_prep_list_exam_papers(
  p_concours_type TEXT DEFAULT NULL,
  p_year TEXT DEFAULT NULL,
  p_subject TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(r)) INTO v_result
  FROM (
    SELECT ep.id, ep.title, ep.concours_type, ep.year, ep.subject,
           ep.paper_url, ep.correction_url, ep.difficulty,
           ep.is_official, ep.has_correction
    FROM app.td_exam_papers ep
    WHERE ep.is_active = TRUE
      AND (p_concours_type IS NULL OR ep.concours_type = p_concours_type)
      AND (p_year IS NULL OR ep.year = p_year)
      AND (p_subject IS NULL OR ep.subject = p_subject)
    ORDER BY ep.year DESC, ep.concours_type, ep.subject
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── EXAM PAPERS: Upload (enseignant/admin) ─────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_create_exam_paper(
  p_title TEXT,
  p_concours_type TEXT,
  p_year TEXT DEFAULT NULL,
  p_subject TEXT DEFAULT NULL,
  p_paper_url TEXT DEFAULT NULL,
  p_correction_url TEXT DEFAULT NULL,
  p_difficulty INTEGER DEFAULT 1,
  p_is_official BOOLEAN DEFAULT FALSE,
  p_has_correction BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_paper_id UUID;
BEGIN
  INSERT INTO app.td_exam_papers (
    title, concours_type, year, subject, paper_url, correction_url,
    difficulty, is_official, has_correction, uploaded_by
  ) VALUES (
    p_title, p_concours_type, p_year, p_subject, p_paper_url, p_correction_url,
    p_difficulty, p_is_official, p_has_correction, auth.uid()
  )
  RETURNING id INTO v_paper_id;

  RETURN jsonb_build_object('success', true, 'paper_id', v_paper_id);
END;
$$;

-- ─── AI TUTOR: Créer une conversation ───────────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_create_ai_conversation(
  p_title TEXT DEFAULT NULL,
  p_subject TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_conv_id UUID;
BEGIN
  INSERT INTO app.td_ai_conversations (student_id, title, subject)
  VALUES (auth.uid(), COALESCE(p_title, 'Nouvelle conversation'), p_subject)
  RETURNING id INTO v_conv_id;

  RETURN jsonb_build_object('success', true, 'conversation_id', v_conv_id);
END;
$$;

-- ─── AI TUTOR: Sauvegarder un message ───────────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_save_ai_message(
  p_conversation_id UUID,
  p_role TEXT,
  p_content TEXT,
  p_tokens_used INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_msg_id UUID;
BEGIN
  INSERT INTO app.td_ai_messages (conversation_id, role, content, tokens_used)
  VALUES (p_conversation_id, p_role, p_content, p_tokens_used)
  RETURNING id INTO v_msg_id;

  UPDATE app.td_ai_conversations
  SET message_count = message_count + 1,
      total_tokens_used = total_tokens_used + p_tokens_used,
      updated_at = now()
  WHERE id = p_conversation_id;

  RETURN jsonb_build_object('success', true, 'message_id', v_msg_id);
END;
$$;

-- ─── AI TUTOR: Lister les conversations ─────────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_list_ai_conversations()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(r)) INTO v_result
  FROM (
    SELECT c.id, c.title, c.subject, c.message_count, c.created_at, c.updated_at
    FROM app.td_ai_conversations c
    WHERE c.student_id = auth.uid()
    ORDER BY c.updated_at DESC
    LIMIT 50
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── AI TUTOR: Lister les messages d'une conversation ───────────
CREATE OR REPLACE FUNCTION app.app_prep_list_ai_messages(
  p_conversation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(r)) INTO v_result
  FROM (
    SELECT m.id, m.role, m.content, m.tokens_used, m.created_at
    FROM app.td_ai_messages m
    WHERE m.conversation_id = p_conversation_id
    ORDER BY m.created_at ASC
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── AI CONFIG: Obtenir la config IA ────────────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_get_ai_config()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_object_agg(config_key, config_value) INTO v_result
  FROM app.td_ai_config;
  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;

-- ─── AI CONFIG: Mettre à jour (admin) ───────────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_update_ai_config(
  p_key TEXT,
  p_value TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO app.td_ai_config (config_key, config_value, updated_by, updated_at)
  VALUES (p_key, p_value, auth.uid(), now())
  ON CONFLICT (config_key) DO UPDATE SET
    config_value = p_value,
    updated_by = auth.uid(),
    updated_at = now();

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── ADMIN: Stats globales ──────────────────────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_admin_get_stats()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'total_questions', (SELECT count(*) FROM app.td_questions WHERE is_active),
    'total_banks', (SELECT count(*) FROM app.td_question_banks WHERE is_active),
    'total_quiz_attempts', (SELECT count(*) FROM app.td_quiz_attempts WHERE status = 'completed'),
    'total_students_active', (SELECT count(DISTINCT student_id) FROM app.td_quiz_attempts),
    'total_flashcard_decks', (SELECT count(*) FROM app.td_flashcard_decks WHERE is_active),
    'total_exam_papers', (SELECT count(*) FROM app.td_exam_papers WHERE is_active),
    'total_ai_conversations', (SELECT count(*) FROM app.td_ai_conversations),
    'total_ai_messages', (SELECT count(*) FROM app.td_ai_messages),
    'avg_score', (SELECT round(avg(score), 1) FROM app.td_quiz_attempts WHERE status = 'completed'),
    'badges_config', (SELECT jsonb_agg(row_to_json(b)) FROM app.td_badges b WHERE b.is_active)
  ) INTO v_result;
  RETURN v_result;
END;
$$;

-- ─── ADMIN: Lister toutes les questions (avec filtres) ──────────
CREATE OR REPLACE FUNCTION app.app_prep_admin_list_questions(
  p_bank_id UUID DEFAULT NULL,
  p_subject TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(r)) INTO v_result
  FROM (
    SELECT q.id, q.bank_id, q.question_type, q.content, q.options,
           q.correct_index, q.explanation, q.difficulty, q.subject,
           q.tags, q.points, q.is_active, q.created_at,
           qb.title AS bank_title
    FROM app.td_questions q
    LEFT JOIN app.td_question_banks qb ON qb.id = q.bank_id
    WHERE (p_bank_id IS NULL OR q.bank_id = p_bank_id)
      AND (p_subject IS NULL OR q.subject = p_subject)
    ORDER BY q.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── ADMIN: Supprimer/désactiver une question ───────────────────
CREATE OR REPLACE FUNCTION app.app_prep_admin_toggle_question(
  p_question_id UUID,
  p_is_active BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE app.td_questions SET is_active = p_is_active, updated_at = now()
  WHERE id = p_question_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── ADMIN: Lister les conversations IA (modération) ────────────
CREATE OR REPLACE FUNCTION app.app_prep_admin_list_ai_conversations(
  p_limit INTEGER DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(r)) INTO v_result
  FROM (
    SELECT c.id, c.student_id, c.title, c.subject, c.message_count,
           c.total_tokens_used, c.created_at, c.updated_at,
           u.raw_user_meta_data->>'full_name' AS student_name
    FROM app.td_ai_conversations c
    LEFT JOIN auth.users u ON u.id = c.student_id
    ORDER BY c.updated_at DESC
    LIMIT p_limit
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── ADMIN: Créer/modifier un badge ─────────────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_admin_upsert_badge(
  p_code TEXT,
  p_title TEXT,
  p_description TEXT DEFAULT NULL,
  p_emoji TEXT DEFAULT NULL,
  p_xp_reward INTEGER DEFAULT 0,
  p_condition_type TEXT DEFAULT NULL,
  p_condition_value INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_badge_id UUID;
BEGIN
  INSERT INTO app.td_badges (code, title, description, emoji, xp_reward, condition_type, condition_value)
  VALUES (p_code, p_title, p_description, p_emoji, p_xp_reward, p_condition_type, p_condition_value)
  ON CONFLICT (code) DO UPDATE SET
    title = p_title,
    description = p_description,
    emoji = p_emoji,
    xp_reward = p_xp_reward,
    condition_type = p_condition_type,
    condition_value = p_condition_value;

  SELECT id INTO v_badge_id FROM app.td_badges WHERE code = p_code;
  RETURN jsonb_build_object('success', true, 'badge_id', v_badge_id);
END;
$$;

-- ─── QUIZ TEMPLATES: Créer un template (enseignant/admin) ───────
CREATE OR REPLACE FUNCTION app.app_prep_create_quiz_template(
  p_title TEXT,
  p_bank_id UUID DEFAULT NULL,
  p_concours_type TEXT DEFAULT NULL,
  p_subject TEXT DEFAULT NULL,
  p_question_count INTEGER DEFAULT 10,
  p_time_limit_minutes INTEGER DEFAULT NULL,
  p_shuffle BOOLEAN DEFAULT TRUE,
  p_is_exam_mode BOOLEAN DEFAULT FALSE,
  p_passing_score INTEGER DEFAULT 60,
  p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_template_id UUID;
BEGIN
  INSERT INTO app.td_quiz_templates (
    title, description, bank_id, concours_type, subject,
    question_count, time_limit_minutes, shuffle_questions,
    is_exam_mode, passing_score, created_by
  ) VALUES (
    p_title, p_description, p_bank_id, p_concours_type, p_subject,
    p_question_count, p_time_limit_minutes, p_shuffle,
    p_is_exam_mode, p_passing_score, auth.uid()
  )
  RETURNING id INTO v_template_id;

  RETURN jsonb_build_object('success', true, 'template_id', v_template_id);
END;
$$;

-- ─── QUIZ TEMPLATES: Lister ─────────────────────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_list_quiz_templates(
  p_concours_type TEXT DEFAULT NULL,
  p_subject TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(r)) INTO v_result
  FROM (
    SELECT qt.id, qt.title, qt.description, qt.concours_type, qt.subject,
           qt.question_count, qt.time_limit_minutes, qt.shuffle_questions,
           qt.is_exam_mode, qt.passing_score, qt.created_at,
           qb.title AS bank_title
    FROM app.td_quiz_templates qt
    LEFT JOIN app.td_question_banks qb ON qb.id = qt.bank_id
    WHERE qt.is_active = TRUE
      AND (p_concours_type IS NULL OR qt.concours_type = p_concours_type)
      AND (p_subject IS NULL OR qt.subject = p_subject)
    ORDER BY qt.created_at DESC
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─── FLASHCARDS: Créer un deck (enseignant/admin) ───────────────
CREATE OR REPLACE FUNCTION app.app_prep_create_flashcard_deck(
  p_title TEXT,
  p_description TEXT DEFAULT NULL,
  p_subject TEXT DEFAULT NULL,
  p_concours_type TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_deck_id UUID;
BEGIN
  INSERT INTO app.td_flashcard_decks (title, description, subject, concours_type, created_by)
  VALUES (p_title, p_description, p_subject, p_concours_type, auth.uid())
  RETURNING id INTO v_deck_id;

  RETURN jsonb_build_object('success', true, 'deck_id', v_deck_id);
END;
$$;

-- ─── FLASHCARDS: Créer une carte (enseignant/admin) ─────────────
CREATE OR REPLACE FUNCTION app.app_prep_create_flashcard(
  p_deck_id UUID,
  p_front_text TEXT,
  p_back_text TEXT,
  p_subject TEXT DEFAULT NULL,
  p_tags TEXT[] DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_card_id UUID;
BEGIN
  INSERT INTO app.td_flashcards (deck_id, front_text, back_text, subject, tags, created_by)
  VALUES (p_deck_id, p_front_text, p_back_text, p_subject, p_tags, auth.uid())
  RETURNING id INTO v_card_id;

  -- Update card count
  UPDATE app.td_flashcard_decks SET card_count = card_count + 1 WHERE id = p_deck_id;

  RETURN jsonb_build_object('success', true, 'card_id', v_card_id);
END;
$$;

-- ─── LEADERBOARD ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION app.app_prep_get_leaderboard(
  p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(r)) INTO v_result
  FROM (
    SELECT sp.student_id, sp.total_xp, sp.level, sp.current_streak,
           sp.total_questions_answered, sp.correct_count,
           u.raw_user_meta_data->>'full_name' AS student_name,
           ROW_NUMBER() OVER (ORDER BY sp.total_xp DESC) AS rank
    FROM app.td_student_progress sp
    JOIN auth.users u ON u.id = sp.student_id
    WHERE sp.subject = 'global'
    ORDER BY sp.total_xp DESC
    LIMIT p_limit
  ) r;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$
