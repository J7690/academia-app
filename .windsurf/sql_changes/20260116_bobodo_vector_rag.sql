-- 20260116_bobodo_vector_rag.sql
-- Dispositif RAG vectoriel pour Bobodo (sans modifier les fonctions existantes)
--
-- Étapes :
-- 1) Activer l’extension pgvector (si supportée sur le projet Supabase)
-- 2) Ajouter une colonne embedding à app.bobodo_knowledge
-- 3) Créer une nouvelle RPC app_search_bobodo_knowledge_vector(p_embedding TEXT, p_limit INT)
--    qui utilise l’opérateur <-> sur la colonne embedding.
--
-- IMPORTANT :
-- - Ce script suppose que la table app.bobodo_knowledge existe déjà.
-- - Si ce n’est pas le cas, appliquer d’abord supabase_bobodo.sql via
--   .windsurf/apply_one_sql_via_admin_rpc.py supabase_bobodo.sql

-- 1) Extension vector (pgvector)
CREATE EXTENSION IF NOT EXISTS vector;

-- 2) Colonne embedding sur la table de connaissances Bobodo
ALTER TABLE app.bobodo_knowledge
ADD COLUMN IF NOT EXISTS embedding vector(1536);

-- 3) RPC de recherche vectorielle
-- On accepte un embedding sous forme de texte '[0.1,0.2,...]' pour simplifier
-- l’appel depuis les Edge Functions / clients, et on le caste en vector côté SQL.

CREATE OR REPLACE FUNCTION app_search_bobodo_knowledge_vector(
  p_embedding TEXT,
  p_limit INT DEFAULT 5
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  IF p_embedding IS NULL OR LENGTH(TRIM(p_embedding)) = 0 THEN
    RETURN '[]'::JSONB;
  END IF;

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', k.id,
        'category', k.category,
        'title', k.title,
        'content', k.content,
        'tags', k.tags,
        'language', k.language
      )
      ORDER BY k.embedding <-> (p_embedding::vector)
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.bobodo_knowledge k
  WHERE k.is_active = TRUE
  LIMIT p_limit;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_search_bobodo_knowledge_vector(TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_search_bobodo_knowledge_vector(TEXT, INT) TO service_role;
