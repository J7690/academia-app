-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (PHASE 3)
-- Admin: RLS + RPC pour imports & pipeline IA
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

-- ========================================
-- 1) RLS admin sur tables pipeline
-- ========================================

ALTER TABLE app.prep_source_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_doc_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_ai_generations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_prep_source_documents ON app.prep_source_documents;
CREATE POLICY admin_all_prep_source_documents
ON app.prep_source_documents
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

DROP POLICY IF EXISTS admin_all_prep_doc_chunks ON app.prep_doc_chunks;
CREATE POLICY admin_all_prep_doc_chunks
ON app.prep_doc_chunks
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

DROP POLICY IF EXISTS admin_all_prep_ai_generations ON app.prep_ai_generations;
CREATE POLICY admin_all_prep_ai_generations
ON app.prep_ai_generations
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.prep_source_documents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.prep_doc_chunks TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.prep_ai_generations TO authenticated;

GRANT ALL ON app.prep_source_documents TO service_role;
GRANT ALL ON app.prep_doc_chunks TO service_role;
GRANT ALL ON app.prep_ai_generations TO service_role;

-- ========================================
-- 2) RPC ADMIN - Sources
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_prep_list_source_documents(
  p_subject_id UUID DEFAULT NULL,
  p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
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

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', d.id,
        'created_by', d.created_by,
        'subject_id', d.subject_id,
        'year', d.year,
        'doc_type', d.doc_type,
        'source_type', d.source_type,
        'storage_bucket', d.storage_bucket,
        'storage_path', d.storage_path,
        'status', d.status,
        'created_at', d.created_at,
        'updated_at', d.updated_at
      )
      ORDER BY d.created_at DESC
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.prep_source_documents d
  WHERE (p_subject_id IS NULL OR d.subject_id = p_subject_id)
    AND (p_status IS NULL OR d.status = p_status);

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'documents', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_list_source_documents(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_list_source_documents(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_prep_upsert_source_document(
  p_document_id UUID DEFAULT NULL,
  p_subject_id UUID DEFAULT NULL,
  p_year INTEGER DEFAULT NULL,
  p_doc_type TEXT DEFAULT NULL,
  p_source_type TEXT DEFAULT 'text',
  p_storage_bucket TEXT DEFAULT NULL,
  p_storage_path TEXT DEFAULT NULL,
  p_extracted_text TEXT DEFAULT NULL,
  p_status TEXT DEFAULT 'received'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
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

  IF p_document_id IS NULL THEN
    INSERT INTO app.prep_source_documents(
      created_by,
      subject_id,
      year,
      doc_type,
      source_type,
      storage_bucket,
      storage_path,
      extracted_text,
      status,
      created_at,
      updated_at
    ) VALUES (
      v_user_id,
      p_subject_id,
      p_year,
      p_doc_type,
      COALESCE(p_source_type, 'text'),
      p_storage_bucket,
      p_storage_path,
      p_extracted_text,
      COALESCE(p_status, 'received'),
      NOW(),
      NOW()
    ) RETURNING id INTO v_id;
  ELSE
    UPDATE app.prep_source_documents
    SET subject_id = COALESCE(p_subject_id, subject_id),
        year = COALESCE(p_year, year),
        doc_type = COALESCE(p_doc_type, doc_type),
        source_type = COALESCE(p_source_type, source_type),
        storage_bucket = COALESCE(p_storage_bucket, storage_bucket),
        storage_path = COALESCE(p_storage_path, storage_path),
        extracted_text = COALESCE(p_extracted_text, extracted_text),
        status = COALESCE(p_status, status),
        updated_at = NOW()
    WHERE id = p_document_id
    RETURNING id INTO v_id;
  END IF;

  IF v_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_found');
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'document_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_upsert_source_document(UUID, UUID, INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_upsert_source_document(UUID, UUID, INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_prep_update_source_document_text(
  p_document_id UUID,
  p_extracted_text TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
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

  UPDATE app.prep_source_documents
  SET extracted_text = p_extracted_text,
      updated_at = NOW()
  WHERE id = p_document_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_found');
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'document_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_update_source_document_text(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_update_source_document_text(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_prep_set_source_document_status(
  p_document_id UUID,
  p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
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

  UPDATE app.prep_source_documents
  SET status = p_status,
      updated_at = NOW()
  WHERE id = p_document_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_found');
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'document_id', v_id, 'status', p_status);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_set_source_document_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_set_source_document_status(UUID, TEXT) TO service_role;

-- ========================================
-- 3) RPC ADMIN - Chunks
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_prep_list_doc_chunks(
  p_source_document_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
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

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', c.id,
        'source_document_id', c.source_document_id,
        'chunk_index', c.chunk_index,
        'content', c.content,
        'metadata', c.metadata,
        'created_at', c.created_at
      )
      ORDER BY c.chunk_index ASC
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.prep_doc_chunks c
  WHERE c.source_document_id = p_source_document_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'chunks', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_list_doc_chunks(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_list_doc_chunks(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_prep_upsert_doc_chunk(
  p_chunk_id UUID DEFAULT NULL,
  p_source_document_id UUID,
  p_chunk_index INTEGER,
  p_content TEXT,
  p_metadata JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
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

  IF p_chunk_id IS NULL THEN
    INSERT INTO app.prep_doc_chunks(
      source_document_id,
      chunk_index,
      content,
      metadata,
      created_at
    ) VALUES (
      p_source_document_id,
      p_chunk_index,
      p_content,
      p_metadata,
      NOW()
    ) RETURNING id INTO v_id;
  ELSE
    UPDATE app.prep_doc_chunks
    SET chunk_index = p_chunk_index,
        content = p_content,
        metadata = COALESCE(p_metadata, metadata)
    WHERE id = p_chunk_id
    RETURNING id INTO v_id;
  END IF;

  IF v_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_found');
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'chunk_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_upsert_doc_chunk(UUID, UUID, INTEGER, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_upsert_doc_chunk(UUID, UUID, INTEGER, TEXT, JSONB) TO service_role;

-- ========================================
-- 4) RPC ADMIN - IA generations
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_prep_list_ai_generations(
  p_subject_id UUID DEFAULT NULL,
  p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
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

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', g.id,
        'created_by', g.created_by,
        'subject_id', g.subject_id,
        'generation_type', g.generation_type,
        'input_params', g.input_params,
        'output_json', g.output_json,
        'status', g.status,
        'error_message', g.error_message,
        'created_at', g.created_at,
        'updated_at', g.updated_at
      )
      ORDER BY g.created_at DESC
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.prep_ai_generations g
  WHERE (p_subject_id IS NULL OR g.subject_id = p_subject_id)
    AND (p_status IS NULL OR g.status = p_status);

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generations', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_list_ai_generations(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_list_ai_generations(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_prep_create_ai_generation(
  p_subject_id UUID,
  p_generation_type TEXT,
  p_input_params JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
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

  INSERT INTO app.prep_ai_generations(
    created_by,
    subject_id,
    generation_type,
    input_params,
    status,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    p_subject_id,
    COALESCE(p_generation_type, 'mcq'),
    p_input_params,
    'proposed',
    NOW(),
    NOW()
  ) RETURNING id INTO v_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generation_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_create_ai_generation(UUID, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_create_ai_generation(UUID, TEXT, JSONB) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_prep_set_ai_generation_status(
  p_generation_id UUID,
  p_status TEXT,
  p_output_json JSONB DEFAULT NULL,
  p_error_message TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_id UUID;
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

  UPDATE app.prep_ai_generations
  SET status = COALESCE(p_status, status),
      output_json = COALESCE(p_output_json, output_json),
      error_message = COALESCE(p_error_message, error_message),
      updated_at = NOW()
  WHERE id = p_generation_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_found');
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'generation_id', v_id, 'status', p_status);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_set_ai_generation_status(UUID, TEXT, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_set_ai_generation_status(UUID, TEXT, JSONB, TEXT) TO service_role;
