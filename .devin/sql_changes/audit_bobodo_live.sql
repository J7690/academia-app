-- ============================================================
-- AUDIT LIVE BOBODO — État réel de la base Supabase
-- Exécuter via: python apply_one_sql_via_admin_rpc.py sql_changes/audit_bobodo_live.sql
-- ============================================================

-- 1) Existence et nombre de lignes de chaque table Bobodo
SELECT
  'TABLES' AS section,
  t.table_name,
  CASE WHEN t.table_name = 'bobodo_sessions'
    THEN (SELECT COUNT(*)::TEXT FROM app.bobodo_sessions)
  WHEN t.table_name = 'bobodo_messages'
    THEN (SELECT COUNT(*)::TEXT FROM app.bobodo_messages)
  WHEN t.table_name = 'bobodo_knowledge'
    THEN (SELECT COUNT(*)::TEXT FROM app.bobodo_knowledge)
  WHEN t.table_name = 'bobodo_unanswered_questions'
    THEN (SELECT COUNT(*)::TEXT FROM app.bobodo_unanswered_questions)
  WHEN t.table_name = 'bobodo_detected_needs'
    THEN (SELECT COUNT(*)::TEXT FROM app.bobodo_detected_needs)
  WHEN t.table_name = 'bobodo_feedback'
    THEN (SELECT COUNT(*)::TEXT FROM app.bobodo_feedback)
  ELSE 'N/A'
  END AS row_count
FROM information_schema.tables t
WHERE t.table_schema = 'app'
  AND t.table_name LIKE 'bobodo%'
ORDER BY t.table_name;

-- 2) Vérifier si la colonne embedding existe sur bobodo_knowledge
SELECT
  'EMBEDDING_COLUMN' AS section,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_schema = 'app'
  AND table_name = 'bobodo_knowledge'
ORDER BY ordinal_position;

-- 3) RPCs Bobodo existantes dans Supabase
SELECT
  'RPCS' AS section,
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%bobodo%'
ORDER BY routine_name;

-- 4) Statistiques messages: répartition par sender
SELECT
  'MSG_SENDER_STATS' AS section,
  sender,
  COUNT(*) AS nb_messages,
  MAX(created_at) AS last_message_at
FROM app.bobodo_messages
GROUP BY sender
ORDER BY nb_messages DESC;

-- 5) Nombre de sessions actives (avec au moins 1 échange)
SELECT
  'SESSION_STATS' AS section,
  COUNT(DISTINCT s.id) AS total_sessions,
  COUNT(DISTINCT CASE WHEN m.sender = 'assistant' THEN s.id END) AS sessions_with_ai_reply,
  COUNT(DISTINCT CASE WHEN m.sender = 'student' THEN s.id END) AS sessions_with_student_msg,
  MAX(m.created_at) AS last_activity
FROM app.bobodo_sessions s
LEFT JOIN app.bobodo_messages m ON m.session_id = s.id;

-- 6) Base de connaissances: catégories et entrées
SELECT
  'KNOWLEDGE_BY_CATEGORY' AS section,
  category,
  COUNT(*) AS nb_entries,
  COUNT(CASE WHEN embedding IS NOT NULL THEN 1 END) AS with_embedding,
  COUNT(CASE WHEN embedding IS NULL THEN 1 END) AS without_embedding
FROM app.bobodo_knowledge
WHERE is_active = TRUE
GROUP BY category
ORDER BY nb_entries DESC;

-- 7) Questions non répondues (HORS_SCOPE détectées)
SELECT
  'UNANSWERED_STATS' AS section,
  category,
  status,
  COUNT(*) AS nb
FROM app.bobodo_unanswered_questions
GROUP BY category, status
ORDER BY nb DESC;

-- 8) Besoins détectés par catégorie (logs de classification)
SELECT
  'DETECTED_NEEDS_STATS' AS section,
  category,
  COUNT(*) AS nb,
  MAX(created_at) AS last_detected
FROM app.bobodo_detected_needs
GROUP BY category
ORDER BY nb DESC;

-- 9) Feedback distribution (up/down)
SELECT
  'FEEDBACK_STATS' AS section,
  rating,
  COUNT(*) AS nb
FROM app.bobodo_feedback
GROUP BY rating;

-- 10) Vérifier la RPC app_list_bobodo_messages: retourne-t-elle bien un JSONB array?
SELECT
  'RPC_RETURN_TYPE' AS section,
  routine_name,
  data_type AS return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'app_list_bobodo_messages',
    'app_append_bobodo_message',
    'app_search_bobodo_knowledge',
    'app_search_bobodo_knowledge_vector',
    'app_get_or_create_bobodo_session',
    'app_has_bobodo_assistant_message',
    'app_get_bobodo_student_first_name'
  )
ORDER BY routine_name;
