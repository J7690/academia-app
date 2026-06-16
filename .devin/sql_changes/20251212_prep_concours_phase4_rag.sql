-- ========================================
-- ACADEMIA - MODULE PRÉPARATION CONCOURS (RAG IA)
-- Récupération de contexte depuis prep_doc_chunks pour /ai/prep/generate
-- Indépendant des autres modules (Bobodo, etc.)
-- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

CREATE OR REPLACE FUNCTION app_prep_get_rag_chunks(
  p_subject_id UUID,
  p_limit INTEGER DEFAULT 12,
  p_max_chars INTEGER DEFAULT 6000
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_limit INTEGER := GREATEST(1, LEAST(COALESCE(p_limit, 12), 30));
  v_max_chars INTEGER := GREATEST(200, LEAST(COALESCE(p_max_chars, 6000), 20000));
  v_chunks JSONB;
  v_chunks_text TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Paywall / entitlement
  IF NOT app_has_feature_access('prep_concours') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'no_feature_access');
  END IF;

  IF p_subject_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_subject_id');
  END IF;

  -- On récupère des chunks liés à des documents "utilisables".
  -- Statuts acceptés: indexed / validated / published.
  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'title', CONCAT('Doc ', LEFT(x.doc_id::TEXT, 8), ' • chunk ', x.chunk_index::TEXT),
        'content', x.content
      )
    ),
    '[]'::JSONB
  )
  INTO v_chunks
  FROM (
    SELECT d.id AS doc_id,
           d.updated_at AS doc_updated_at,
           c.chunk_index,
           c.content
    FROM app.prep_doc_chunks c
    JOIN app.prep_source_documents d
      ON d.id = c.source_document_id
    WHERE d.subject_id = p_subject_id
      AND d.status IN ('indexed', 'validated', 'published')
    ORDER BY d.updated_at DESC, c.chunk_index ASC
    LIMIT v_limit
  ) x;

  v_chunks_text := COALESCE(v_chunks::TEXT, '[]');

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'chunks', COALESCE(v_chunks, '[]'::JSONB),
    'truncated', (LENGTH(v_chunks_text) > v_max_chars)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_prep_get_rag_chunks(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION app_prep_get_rag_chunks(UUID, INTEGER, INTEGER) TO service_role;
