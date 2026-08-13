-- Rapatriement : fiche de séance (Learning Engine) — état de PRODUCTION au 12/08/2026.
--
-- POURQUOI CE FICHIER. Les tables `app.academia_session_summaries` /
-- `app.academia_session_events` et les RPC `app_learning_get_summary`,
-- `app_learning_publish_summary`, `app_learning_log_event`,
-- `app_learning_list_replays` tournaient en production SANS source dans git
-- (livrées aux lots L3/L4, appliquées via MCP). C'est exactement la dérive
-- qui a coûté l'audit du 02/08 (cf. CORRECTIFS_STUDIO_LIVE_2026-08-02.md) :
-- un déploiement de bonne foi depuis le dépôt aurait écrasé la production.
--
-- CE FICHIER EST UNE COPIE FIDÈLE de la production, relevée le 12/08/2026 via
-- `admin_execute_sql` (script `.windsurf/audit_fiche_seance_etape0*.py`).
-- Il est idempotent : le rejouer sur la production ne change rien.
-- Il ne corrige AUCUN défaut — les anomalies relevées sont consignées dans
-- docs/AUDIT_FICHE_SEANCE_ETAPE0_2026-08-12.md et se traiteront à part.

-- ── Tables ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS app.academia_session_summaries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES app.academia_sessions(id) ON DELETE CASCADE,
  audience text NOT NULL DEFAULT 'student' CHECK (audience = ANY (ARRAY['student'::text, 'host'::text])),
  status text NOT NULL DEFAULT 'pending' CHECK (status = ANY (ARRAY['pending'::text, 'ready'::text, 'failed'::text])),
  content jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_published boolean NOT NULL DEFAULT false,
  edited_by uuid,
  edited_at timestamptz,
  model_used text,
  error_detail text,
  -- Posée dès l'origine en prévision d'un PDF rendu côté serveur ; jamais
  -- alimentée à ce jour (le PDF est construit côté client, à la demande).
  pdf_url text,
  generated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, audience)
);

CREATE INDEX IF NOT EXISTS idx_ass_session
  ON app.academia_session_summaries (session_id);

CREATE TABLE IF NOT EXISTS app.academia_session_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES app.academia_sessions(id) ON DELETE CASCADE,
  kind text NOT NULL,
  actor_id uuid,
  actor_name text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  offset_ms integer,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ase_session_time
  ON app.academia_session_events (session_id, created_at);

-- RLS actif, AUCUNE politique : refus par défaut pour anon/authenticated.
-- Tout accès client passe par les RPC SECURITY DEFINER ci-dessous ; l'Edge
-- Function `learning-session-summary` écrit avec la clé service_role.
ALTER TABLE app.academia_session_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.academia_session_events ENABLE ROW LEVEL SECURITY;

-- ── RPC (définitions de production, à l'octet près) ──────────────────────

CREATE OR REPLACE FUNCTION public.app_learning_get_summary(p_session_id uuid, p_audience text DEFAULT 'student'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_host uuid;
  v_is_host boolean;
  v_row app.academia_session_summaries%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentification requise.');
  END IF;
  IF NOT app.academia_session_is_member(p_session_id, v_user) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Vous n''avez pas participé à cette séance.');
  END IF;

  SELECT host_id INTO v_host FROM app.academia_sessions WHERE id = p_session_id;
  v_is_host := v_host IS NOT DISTINCT FROM v_user;

  -- La version « host » contient des statistiques de participation : elle
  -- n'est jamais servie à un étudiant, même s'il la demande explicitement.
  IF p_audience = 'host' AND NOT v_is_host THEN
    RETURN jsonb_build_object('success', false, 'error', 'Réservé à l''enseignant.');
  END IF;

  SELECT * INTO v_row FROM app.academia_session_summaries
   WHERE session_id = p_session_id AND audience = p_audience;

  IF v_row.id IS NULL THEN
    RETURN jsonb_build_object('success', true, 'summary', null, 'status', 'none');
  END IF;

  -- Tant que l'enseignant n'a pas relu et publié, l'étudiant ne voit rien.
  IF p_audience = 'student' AND NOT v_row.is_published AND NOT v_is_host THEN
    RETURN jsonb_build_object('success', true, 'summary', null, 'status', 'unpublished');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'status', v_row.status,
    'summary', jsonb_build_object(
      'id', v_row.id,
      'audience', v_row.audience,
      'content', v_row.content,
      'is_published', v_row.is_published,
      'pdf_url', v_row.pdf_url,
      'model_used', v_row.model_used,
      'generated_at', v_row.generated_at,
      'edited_at', v_row.edited_at
    ),
    'is_host', v_is_host
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_learning_publish_summary(p_session_id uuid, p_content jsonb DEFAULT NULL::jsonb, p_publish boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_host uuid;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentification requise.');
  END IF;

  SELECT host_id INTO v_host FROM app.academia_sessions WHERE id = p_session_id;
  IF v_host IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Séance introuvable.');
  END IF;
  IF v_host IS DISTINCT FROM v_user THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seul l''enseignant peut publier la fiche.');
  END IF;

  UPDATE app.academia_session_summaries
     SET content = coalesce(p_content, content),
         is_published = p_publish,
         edited_by = CASE WHEN p_content IS NULL THEN edited_by ELSE v_user END,
         edited_at = CASE WHEN p_content IS NULL THEN edited_at ELSE now() END,
         updated_at = now()
   WHERE session_id = p_session_id AND audience = 'student';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aucune fiche à publier pour cette séance.');
  END IF;

  RETURN jsonb_build_object('success', true, 'published', p_publish);
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_learning_log_event(p_session_id uuid, p_kind text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_start timestamptz;
BEGIN
  IF v_user IS NULL THEN RETURN false; END IF;
  IF NOT app.academia_session_is_member(p_session_id, v_user) THEN
    RETURN false;
  END IF;

  SELECT coalesce(actual_start, scheduled_start, created_at)
    INTO v_start FROM app.academia_sessions WHERE id = p_session_id;

  INSERT INTO app.academia_session_events
    (session_id, kind, actor_id, actor_name, payload, offset_ms)
  VALUES (
    p_session_id, p_kind, v_user,
    public.livekit_get_user_display_name(v_user),
    coalesce(p_payload, '{}'::jsonb),
    CASE WHEN v_start IS NULL THEN NULL
         ELSE greatest(0, (extract(epoch FROM (now() - v_start)) * 1000)::integer) END
  );
  RETURN true;
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_learning_list_replays(p_session_type text DEFAULT NULL::text, p_limit integer DEFAULT 12, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app'
AS $function$
DECLARE
  v_limit  integer := LEAST(GREATEST(COALESCE(p_limit, 12), 1), 50);
  v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
  v_rows   jsonb;
  v_count  integer;
BEGIN
  WITH visible AS (
    SELECT s.*
    FROM app.academia_sessions s
    WHERE s.status = 'ended'
      AND (s.replay_url IS NOT NULL OR s.replay_video_asset_id IS NOT NULL)
      AND (p_session_type IS NULL OR s.session_type = p_session_type)
      AND (
        s.session_type <> 'td'
        OR EXISTS (
          SELECT 1
          FROM app.td_enrollments e
          WHERE e.program_id = s.program_id
            AND e.student_id = auth.uid()
            AND e.access_status::text = 'active'
        )
        OR s.host_id = auth.uid()
      )
    ORDER BY COALESCE(s.actual_end, s.scheduled_end, s.created_at) DESC
    LIMIT v_limit OFFSET v_offset
  ),
  resolved AS (
    SELECT
      v.*,
      (
        SELECT r.public_url_hint
        FROM app.video_renditions r
        WHERE r.video_asset_id = v.replay_video_asset_id
          AND r.status = 'ready'
          AND r.kind IN ('hls', 'mp4')
        ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
        LIMIT 1
      ) AS best_url,
      (
        SELECT r.public_url_hint
        FROM app.video_renditions r
        WHERE r.video_asset_id = v.replay_video_asset_id
          AND r.status = 'ready'
          AND r.kind IN ('poster', 'thumbnail')
        ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
        LIMIT 1
      ) AS poster_url
    FROM visible v
  )
  SELECT
    COALESCE(
      JSONB_AGG(
        ROW_TO_JSON(x)::jsonb
        - 'best_url' - 'poster_url'
        || JSONB_BUILD_OBJECT(
             'replay_url',        COALESCE(x.best_url, x.replay_url),
             'replay_poster_url', x.poster_url,
             'thumbnail_url',     COALESCE(x.thumbnail_url, x.poster_url)
           )
        ORDER BY COALESCE(x.actual_end, x.scheduled_end, x.created_at) DESC
      ),
      '[]'::jsonb
    ),
    COUNT(*)
  INTO v_rows, v_count
  FROM resolved x;

  RETURN JSONB_BUILD_OBJECT(
    'success',  TRUE,
    'sessions', v_rows,
    'has_more', v_count = v_limit
  );
END;
$function$;

-- ── Droits (état de production relevé le 12/08/2026) ─────────────────────
-- `anon` n'exécute AUCUNE de ces quatre fonctions ; `authenticated` les
-- exécute toutes. (Anomalie relevée par ailleurs : `app_learning_leave_session`
-- reste exécutable par `anon` — consignée dans le rapport, non traitée ici.)
REVOKE EXECUTE ON FUNCTION public.app_learning_get_summary(uuid, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.app_learning_publish_summary(uuid, jsonb, boolean) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.app_learning_log_event(uuid, text, jsonb) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.app_learning_list_replays(text, integer, integer) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_learning_get_summary(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_publish_summary(uuid, jsonb, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_log_event(uuid, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_learning_list_replays(text, integer, integer) TO authenticated;
