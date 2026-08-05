-- ============================================================================
-- Contrôle d'accès aux salles du Studio Live — 02/08/2026
-- ============================================================================
--
-- ÉTAT AVANT
--
-- `app_learning_join_session` n'effectuait AUCUNE vérification : elle
-- constatait l'existence de la séance, puis inscrivait l'appelant. Ni statut,
-- ni capacité, ni appartenance. Quiconque disposait d'un identifiant de séance
-- entrait — y compris dans une séance terminée, annulée, ou déjà pleine.
--
-- `max_participants` était écrit en base par le formulaire enseignant, lu par
-- l'application pour choisir un profil simulcast, et n'était appliqué nulle
-- part comme plafond.
--
-- PRINCIPES RETENUS
--
-- 1. On ne verrouille pas ce qui casserait un usage légitime. Un participant
--    DÉJÀ inscrit qui revient après une coupure repasse toujours, même si la
--    salle est pleine : sa place lui appartient. Sans cette clause, une micro-
--    coupure réseau expulserait définitivement quelqu'un d'une séance complète.
--
-- 2. L'hôte n'est jamais compté dans la capacité et n'est jamais refusé : la
--    place de l'animateur n'est pas une place d'élève.
--
-- 3. L'administrateur entre partout et n'est PAS inscrit comme participant —
--    même règle que l'Edge Function `livekit-token`, pour que la supervision
--    ne fausse pas les statistiques de fréquentation.
--
-- 4. Les motifs de refus sont écrits pour être AFFICHÉS. L'application les
--    remonte tels quels ; un message technique y serait lu par un élève.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS
--
-- Elle ne vérifie ni l'inscription pédagogique ni le paiement. Ces règles
-- diffèrent par type de séance (TD adossé à `td_enrollments`, prépa à un
-- abonnement, orientation à une réservation) et méritent d'être traitées
-- séparément, avec les données de chaque parcours sous les yeux. Poser ici une
-- règle unique reviendrait à en inventer une.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_learning_join_session(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app, pg_temp
AS $$
DECLARE
  v_user       uuid := auth.uid();
  v_seance     app.academia_sessions%ROWTYPE;
  v_name       text;
  v_deja       boolean;
  v_occupees   integer;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentification requise.');
  END IF;

  SELECT * INTO v_seance FROM app.academia_sessions WHERE id = p_session_id;
  IF v_seance.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session introuvable.');
  END IF;

  -- ── L'hôte : chez lui, toujours ────────────────────────────────────────
  IF v_seance.host_id = v_user THEN
    RETURN jsonb_build_object('success', true, 'role', 'host');
  END IF;

  -- ── L'administrateur : partout, sans laisser de trace de présence ──────
  IF public.app_is_admin_user() THEN
    RETURN jsonb_build_object('success', true, 'role', 'supervision');
  END IF;

  -- ── Statut : une séance close ou non publiée ne se rejoint pas ─────────
  IF v_seance.status NOT IN ('scheduled', 'approved', 'running', 'paused') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE v_seance.status
        WHEN 'ended'     THEN 'Cette séance est terminée.'
        WHEN 'cancelled' THEN 'Cette séance a été annulée.'
        WHEN 'rejected'  THEN 'Cette séance a été refusée.'
        WHEN 'draft'     THEN 'Cette séance n''est pas encore ouverte.'
        ELSE 'Cette séance n''est pas accessible pour le moment.'
      END
    );
  END IF;

  -- ── Déjà inscrit ? Sa place lui reste acquise ──────────────────────────
  SELECT EXISTS (
    SELECT 1 FROM app.academia_session_participants
     WHERE session_id = p_session_id AND user_id = v_user
  ) INTO v_deja;

  -- ── Capacité — seulement pour une PREMIÈRE entrée ──────────────────────
  IF NOT v_deja AND v_seance.max_participants IS NOT NULL THEN
    SELECT count(*) INTO v_occupees
      FROM app.academia_session_participants
     WHERE session_id = p_session_id
       AND left_at IS NULL
       -- L'hôte a pu être inscrit comme participant par le code d'avant :
       -- il ne doit pas consommer une place d'élève pour autant.
       AND user_id IS DISTINCT FROM v_seance.host_id;

    IF v_occupees >= v_seance.max_participants THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Séance complète : toutes les places sont prises.'
      );
    END IF;
  END IF;

  SELECT public.livekit_get_user_display_name(v_user) INTO v_name;

  INSERT INTO app.academia_session_participants
    (session_id, user_id, display_name, role, joined_at, last_seen_at, left_at)
  VALUES (p_session_id, v_user, v_name, 'participant', now(), now(), NULL)
  ON CONFLICT (session_id, user_id) DO UPDATE
    SET last_seen_at = now(), left_at = NULL;

  UPDATE app.academia_sessions SET current_participants = (
    SELECT count(*) FROM app.academia_session_participants
     WHERE session_id = p_session_id AND left_at IS NULL
  ) WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true, 'role', 'participant');
END;
$$;

COMMENT ON FUNCTION public.app_learning_join_session(uuid) IS
  'Inscrit l''appelant à une séance après contrôle du statut et de la capacité. '
  'L''hôte et l''administrateur entrent sans être comptés ; un participant déjà '
  'inscrit repasse même si la salle est pleine.';

-- L'audit de sécurité Supabase signalait une fonction SECURITY DEFINER
-- appelable sans authentification. Elle renvoyait déjà « Authentification
-- requise. » à un appelant anonyme : le refus était correct, mais la porte
-- restait ouverte. Rejoindre une séance suppose d'être connecté.
REVOKE EXECUTE ON FUNCTION public.app_learning_join_session(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.app_learning_join_session(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.app_learning_join_session(uuid) TO authenticated;
GRANT  EXECUTE ON FUNCTION public.app_learning_join_session(uuid) TO service_role;
