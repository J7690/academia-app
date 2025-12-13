-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS
-- Publication: convertir une génération IA validée -> questions publiées
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

-- ========================================
-- RPC ADMIN: publier une génération IA (validated) en questions
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_prep_publish_ai_generation(
  p_generation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_gen RECORD;
  v_questions JSONB;
  v_q JSONB;
  v_choices JSONB;
  v_choice TEXT;
  v_choice_idx INTEGER;
  v_correct_index INTEGER;
  v_question_id UUID;
  v_inserted_count INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  SELECT id, subject_id, generation_type, input_params, output_json, status
  INTO v_gen
  FROM app.prep_ai_generations
  WHERE id = p_generation_id;

  IF v_gen.id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_found');
  END IF;

  IF v_gen.status <> 'validated' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status', 'status', v_gen.status);
  END IF;

  v_questions := v_gen.output_json->'questions';
  IF v_questions IS NULL OR jsonb_typeof(v_questions) <> 'array' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_output_json');
  END IF;

  FOR v_q IN SELECT * FROM jsonb_array_elements(v_questions)
  LOOP
    IF jsonb_typeof(v_q) <> 'object' THEN
      CONTINUE;
    END IF;

    v_choices := v_q->'choices';
    v_correct_index := NULL;
    BEGIN
      v_correct_index := (v_q->>'correct_index')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
      v_correct_index := NULL;
    END;

    INSERT INTO app.prep_questions(
      subject_id,
      chapter_id,
      source,
      question_type,
      level,
      mechanism,
      prompt_context,
      question,
      explanation,
      correct_answer,
      estimated_time_sec,
      is_published,
      created_by,
      created_at,
      updated_at
    ) VALUES (
      v_gen.subject_id,
      NULL,
      'ai',
      COALESCE(v_gen.generation_type, 'mcq'),
      'beginner',
      NULL,
      NULL,
      COALESCE(v_q->>'question', ''),
      NULLIF(COALESCE(v_q->>'explanation', ''), ''),
      NULL,
      NULL,
      TRUE,
      v_user_id,
      NOW(),
      NOW()
    ) RETURNING id INTO v_question_id;

    IF v_question_id IS NULL THEN
      CONTINUE;
    END IF;

    -- Insert choices
    IF v_choices IS NOT NULL AND jsonb_typeof(v_choices) = 'array' THEN
      v_choice_idx := 0;
      FOR v_choice IN SELECT jsonb_array_elements_text(v_choices)
      LOOP
        INSERT INTO app.prep_question_choices(
          question_id,
          choice_label,
          choice_text,
          is_correct,
          sort_order,
          created_at
        ) VALUES (
          v_question_id,
          NULL,
          v_choice,
          (v_correct_index IS NOT NULL AND v_choice_idx = v_correct_index),
          v_choice_idx,
          NOW()
        );

        IF v_correct_index IS NOT NULL AND v_choice_idx = v_correct_index THEN
          UPDATE app.prep_questions
          SET correct_answer = v_choice
          WHERE id = v_question_id;
        END IF;

        v_choice_idx := v_choice_idx + 1;
      END LOOP;
    END IF;

    v_inserted_count := v_inserted_count + 1;
  END LOOP;

  UPDATE app.prep_ai_generations
  SET status = 'published',
      updated_at = NOW()
  WHERE id = p_generation_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'inserted_questions', v_inserted_count,
    'generation_id', p_generation_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_publish_ai_generation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_publish_ai_generation(UUID) TO service_role;
