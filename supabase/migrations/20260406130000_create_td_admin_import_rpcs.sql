-- Create missing RPCs for TD admin import (referenced in guide_admin_fournir_contenu.md)
-- app_td_admin_import_questions_json: Import JSON array of QCM questions into td_questions
-- app_td_admin_import_text_bulk: Import raw text, chunk it, store in td_doc_chunks

-- ═══════════════════════════════════════════════════════════════════
-- RPC 1: app_td_admin_import_questions_json
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION app.app_td_admin_import_questions_json(
  p_questions jsonb,
  p_subject text DEFAULT NULL,
  p_source text DEFAULT 'admin_json_import'
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_imported integer := 0;
  v_skipped integer := 0;
  v_errors jsonb := '[]'::jsonb;
  v_q jsonb;
  v_content text;
  v_options jsonb;
  v_correct integer;
  v_explanation text;
  v_difficulty integer;
  v_subject text;
  v_idx integer := 0;
BEGIN
  -- Verify caller is admin
  IF app.app_td_get_current_role() <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  IF p_questions IS NULL OR jsonb_typeof(p_questions) <> 'array' THEN
    RETURN jsonb_build_object('success', false, 'error', 'p_questions must be a JSON array');
  END IF;

  FOR v_q IN SELECT * FROM jsonb_array_elements(p_questions)
  LOOP
    v_idx := v_idx + 1;
    BEGIN
      v_content := COALESCE(v_q->>'question', v_q->>'content', v_q->>'enonce', '');
      IF length(v_content) < 5 THEN
        v_skipped := v_skipped + 1;
        v_errors := v_errors || jsonb_build_array('Q' || v_idx || ': question trop courte ou manquante');
        CONTINUE;
      END IF;

      v_options := v_q->'options';
      IF v_options IS NULL OR jsonb_typeof(v_options) <> 'array' OR jsonb_array_length(v_options) < 2 THEN
        v_skipped := v_skipped + 1;
        v_errors := v_errors || jsonb_build_array('Q' || v_idx || ': options manquantes ou < 2');
        CONTINUE;
      END IF;

      v_correct := COALESCE((v_q->>'correct_index')::integer, 0);
      v_explanation := COALESCE(v_q->>'explanation', '');
      v_difficulty := COALESCE((v_q->>'difficulty')::integer, 2);
      IF v_difficulty < 1 THEN v_difficulty := 1; END IF;
      IF v_difficulty > 5 THEN v_difficulty := 5; END IF;
      v_subject := COALESCE(v_q->>'subject', p_subject);

      INSERT INTO app.td_questions (
        question_type, content, options, correct_index,
        explanation, difficulty, subject, is_active,
        generation_mode
      ) VALUES (
        'mcq', v_content, v_options, v_correct,
        v_explanation, v_difficulty, v_subject, true,
        p_source
      );

      v_imported := v_imported + 1;

    EXCEPTION WHEN OTHERS THEN
      v_skipped := v_skipped + 1;
      v_errors := v_errors || jsonb_build_array('Q' || v_idx || ': ' || SQLERRM);
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'imported_count', v_imported,
    'skipped_count', v_skipped,
    'errors', v_errors
  );
END;
$$;

ALTER FUNCTION app.app_td_admin_import_questions_json(jsonb, text, text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION app.app_td_admin_import_questions_json(jsonb, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION app.app_td_admin_import_questions_json(jsonb, text, text) TO service_role;

-- ═══════════════════════════════════════════════════════════════════
-- RPC 2: app_td_admin_import_text_bulk
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION app.app_td_admin_import_text_bulk(
  p_text text,
  p_subject text DEFAULT NULL,
  p_university text DEFAULT NULL,
  p_study_year text DEFAULT NULL,
  p_doc_type text DEFAULT 'cours'
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_doc_id uuid;
  v_chunks text[];
  v_current text := '';
  v_para text;
  v_paragraphs text[];
  v_chunk_count integer := 0;
  v_max_chars integer := 1500;
  v_i integer;
BEGIN
  -- Verify caller is admin
  IF app.app_td_get_current_role() <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  IF p_text IS NULL OR length(trim(p_text)) < 50 THEN
    RETURN jsonb_build_object('success', false, 'error', 'text_too_short');
  END IF;

  -- Create source document
  INSERT INTO app.td_source_documents (
    subject, university, study_year, doc_type,
    storage_bucket, storage_path, original_filename,
    status, extracted_text
  ) VALUES (
    p_subject, p_university, p_study_year, p_doc_type,
    'manual', 'manual/text_import_' || to_char(now(), 'YYYYMMDD_HH24MISS') || '.txt',
    'Import texte brut - ' || COALESCE(p_subject, 'sans matière'),
    'indexed',
    left(p_text, 100000)
  )
  RETURNING id INTO v_doc_id;

  -- Split into paragraphs and chunk
  v_paragraphs := string_to_array(p_text, E'\n\n');

  FOR v_i IN 1..array_length(v_paragraphs, 1) LOOP
    v_para := trim(v_paragraphs[v_i]);
    IF length(v_para) < 10 THEN
      CONTINUE;
    END IF;

    IF length(v_current) + length(v_para) + 2 > v_max_chars THEN
      IF length(v_current) > 30 THEN
        INSERT INTO app.td_doc_chunks (
          source_document_id, chunk_index, content, metadata,
          chunk_type, subject, university, study_year, token_count
        ) VALUES (
          v_doc_id, v_chunk_count, trim(v_current),
          jsonb_build_object('source', 'text_import', 'doc_type', p_doc_type),
          'content', p_subject, p_university, p_study_year,
          ceil(length(trim(v_current))::numeric / 4)
        );
        v_chunk_count := v_chunk_count + 1;
      END IF;
      v_current := v_para;
    ELSE
      IF v_current = '' THEN
        v_current := v_para;
      ELSE
        v_current := v_current || E'\n\n' || v_para;
      END IF;
    END IF;
  END LOOP;

  -- Last chunk
  IF length(v_current) > 30 THEN
    INSERT INTO app.td_doc_chunks (
      source_document_id, chunk_index, content, metadata,
      chunk_type, subject, university, study_year, token_count
    ) VALUES (
      v_doc_id, v_chunk_count, trim(v_current),
      jsonb_build_object('source', 'text_import', 'doc_type', p_doc_type),
      'content', p_subject, p_university, p_study_year,
      ceil(length(trim(v_current))::numeric / 4)
    );
    v_chunk_count := v_chunk_count + 1;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', v_chunk_count || ' chunk(s) indexé(s) pour "' || COALESCE(p_subject, 'N/A') || '"',
    'document_id', v_doc_id,
    'chunks_count', v_chunk_count
  );
END;
$$;

ALTER FUNCTION app.app_td_admin_import_text_bulk(text, text, text, text, text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION app.app_td_admin_import_text_bulk(text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION app.app_td_admin_import_text_bulk(text, text, text, text, text) TO service_role;
