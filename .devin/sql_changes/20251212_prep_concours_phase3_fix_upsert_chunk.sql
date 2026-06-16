-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (PHASE 3) - FIX
-- Corrige la signature de app_admin_prep_upsert_doc_chunk
-- (paramètre avec default avant paramètres non-default)
-- ========================================

CREATE OR REPLACE FUNCTION app_admin_prep_upsert_doc_chunk(
  p_source_document_id UUID,
  p_chunk_index INTEGER,
  p_content TEXT,
  p_metadata JSONB DEFAULT NULL,
  p_chunk_id UUID DEFAULT NULL
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

GRANT EXECUTE ON FUNCTION app_admin_prep_upsert_doc_chunk(UUID, INTEGER, TEXT, JSONB, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_upsert_doc_chunk(UUID, INTEGER, TEXT, JSONB, UUID) TO service_role;
