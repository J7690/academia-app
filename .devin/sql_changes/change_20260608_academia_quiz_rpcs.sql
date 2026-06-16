-- Phase 9 : RPCs pour le quiz live dans AcademiaSession
-- Tables cibles : app.academia_session_quiz_questions, app.academia_session_quiz_answers (Phase 2)

-- 1. Créer une question de quiz (host)
CREATE OR REPLACE FUNCTION public.app_learning_quiz_create_question(
  p_session_id UUID,
  p_question TEXT,
  p_options JSONB,
  p_correct_index INT,
  p_duration_seconds INT DEFAULT 30
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_question_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  INSERT INTO app.academia_session_quiz_questions (
    session_id, question, options, correct_index, duration_seconds, created_by
  ) VALUES (
    p_session_id, p_question, p_options, p_correct_index, p_duration_seconds, v_user_id
  )
  RETURNING id INTO v_question_id;

  RETURN v_question_id;
END;
$$;

-- 2. Soumettre une réponse (étudiant)
CREATE OR REPLACE FUNCTION public.app_learning_quiz_submit_answer(
  p_question_id UUID,
  p_selected_index INT
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_correct_index INT;
  v_is_correct BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  -- Récupérer la bonne réponse
  SELECT correct_index INTO v_correct_index
  FROM app.academia_session_quiz_questions
  WHERE id = p_question_id;

  IF v_correct_index IS NULL THEN
    RAISE EXCEPTION 'Question introuvable';
  END IF;

  v_is_correct := (p_selected_index = v_correct_index);

  INSERT INTO app.academia_session_quiz_answers (
    question_id, user_id, selected_index, is_correct, answered_at
  ) VALUES (
    p_question_id, v_user_id, p_selected_index, v_is_correct, NOW()
  )
  ON CONFLICT (question_id, user_id) DO NOTHING;

  RETURN v_is_correct;
END;
$$;

-- 3. Résultats d'une question (host)
CREATE OR REPLACE FUNCTION public.app_learning_quiz_results(
  p_question_id UUID
)
RETURNS TABLE(
  total_answers INT,
  correct_count INT,
  answer_distribution JSONB
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::INT AS total_answers,
    COUNT(*) FILTER (WHERE a.is_correct)::INT AS correct_count,
    jsonb_agg(
      jsonb_build_object(
        'user_id', a.user_id,
        'selected_index', a.selected_index,
        'is_correct', a.is_correct
      )
    ) AS answer_distribution
  FROM app.academia_session_quiz_answers a
  WHERE a.question_id = p_question_id;
END;
$$;

-- 4. Lister les questions d'une session
CREATE OR REPLACE FUNCTION public.app_learning_quiz_list_questions(
  p_session_id UUID
)
RETURNS TABLE(
  id UUID,
  question TEXT,
  options JSONB,
  correct_index INT,
  duration_seconds INT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, app
AS $$
BEGIN
  RETURN QUERY
  SELECT
    q.id,
    q.question,
    q.options,
    q.correct_index,
    q.duration_seconds,
    q.created_at
  FROM app.academia_session_quiz_questions q
  WHERE q.session_id = p_session_id
  ORDER BY q.created_at ASC;
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION public.app_learning_quiz_create_question(UUID, TEXT, JSONB, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_quiz_submit_answer(UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_quiz_results(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_quiz_list_questions(UUID) TO authenticated;
