-- ============================================================
-- CACHE SÉMANTIQUE BOBODO — bobodo_answer_cache
-- Objectif : éviter de consommer des crédits OpenRouter
-- pour des questions déjà répondues ou très similaires.
-- Similarité cosinus >= 0.92 → réponse cache renvoyée directement.
-- ============================================================

-- 1. Table de cache
CREATE TABLE IF NOT EXISTS app.bobodo_answer_cache (
  id                 uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  question_text      text         NOT NULL,
  question_embedding vector(1536) NULL,
  answer_text        text         NOT NULL,
  category           text         NULL,
  hit_count          integer      NOT NULL DEFAULT 1,
  created_at         timestamptz  NOT NULL DEFAULT now(),
  last_hit_at        timestamptz  NOT NULL DEFAULT now(),
  expires_at         timestamptz  NOT NULL DEFAULT (now() + interval '60 days')
);

-- Index IVFFLAT pour la recherche vectorielle rapide
CREATE INDEX IF NOT EXISTS idx_bobodo_answer_cache_embedding
  ON app.bobodo_answer_cache
  USING ivfflat (question_embedding vector_cosine_ops)
  WITH (lists = 10);

-- Index sur expiration pour le nettoyage
CREATE INDEX IF NOT EXISTS idx_bobodo_answer_cache_expires
  ON app.bobodo_answer_cache (expires_at);

-- RLS : les étudiants authentifiés peuvent lire, le service_role peut tout faire
ALTER TABLE app.bobodo_answer_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cache_select_authenticated" ON app.bobodo_answer_cache;
CREATE POLICY "cache_select_authenticated"
  ON app.bobodo_answer_cache FOR SELECT
  TO authenticated USING (true);

-- 2. RPC : chercher une réponse en cache par similarité vectorielle
CREATE OR REPLACE FUNCTION app.app_search_bobodo_answer_cache(
  p_query_embedding vector(1536),
  p_threshold       float DEFAULT 0.92
)
RETURNS TABLE (
  cache_id   uuid,
  answer     text,
  category   text,
  hit_count  integer,
  similarity float
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    c.id                                              AS cache_id,
    c.answer_text                                     AS answer,
    c.category                                        AS category,
    c.hit_count                                       AS hit_count,
    (1 - (c.question_embedding <=> p_query_embedding))::float AS similarity
  FROM app.bobodo_answer_cache c
  WHERE
    c.expires_at > now()
    AND c.question_embedding IS NOT NULL
    AND (1 - (c.question_embedding <=> p_query_embedding)) >= p_threshold
  ORDER BY c.question_embedding <=> p_query_embedding
  LIMIT 1;
$$;

-- 3. RPC : enregistrer un hit de cache (incrémente le compteur)
CREATE OR REPLACE FUNCTION app.app_bobodo_cache_hit(p_cache_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE app.bobodo_answer_cache
  SET hit_count   = hit_count + 1,
      last_hit_at = now(),
      expires_at  = GREATEST(expires_at, now() + interval '30 days')
  WHERE id = p_cache_id;
$$;

-- 4. RPC : insérer une nouvelle entrée dans le cache
CREATE OR REPLACE FUNCTION app.app_insert_bobodo_answer_cache(
  p_question_text      text,
  p_question_embedding vector(1536),
  p_answer_text        text,
  p_category           text DEFAULT NULL
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  INSERT INTO app.bobodo_answer_cache
    (question_text, question_embedding, answer_text, category)
  VALUES
    (p_question_text, p_question_embedding, p_answer_text, p_category)
  ON CONFLICT DO NOTHING;
$$;

-- 5. RPC admin : statistiques du cache (pour monitoring)
CREATE OR REPLACE FUNCTION app.app_admin_bobodo_cache_stats()
RETURNS TABLE (
  total_entries   bigint,
  total_hits      bigint,
  active_entries  bigint,
  expired_entries bigint,
  top_questions   jsonb
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    COUNT(*)                                                   AS total_entries,
    COALESCE(SUM(hit_count), 0)                               AS total_hits,
    COUNT(*) FILTER (WHERE expires_at > now())                AS active_entries,
    COUNT(*) FILTER (WHERE expires_at <= now())               AS expired_entries,
    (
      SELECT jsonb_agg(row_to_json(top))
      FROM (
        SELECT question_text, hit_count, category
        FROM app.bobodo_answer_cache
        ORDER BY hit_count DESC
        LIMIT 10
      ) AS top
    )                                                          AS top_questions
  FROM app.bobodo_answer_cache;
$$;

-- 6. Nettoyage automatique des entrées expirées (optionnel, à activer via pg_cron)
-- SELECT cron.schedule('bobodo-cache-cleanup', '0 3 * * *',
--   $$DELETE FROM app.bobodo_answer_cache WHERE expires_at < now()$$);
