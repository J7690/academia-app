-- Cycle de vie de la machine : l'activite se calcule depuis le TRAVAIL,
-- plus jamais depuis la machine.
--
-- ── LA CAUSE RACINE, MESUREE LE 11/08/2026 ────────────────────────────────
--
-- `agent_pod.sh` declarait la machine occupee sur cinq signaux MACHINE : GPU,
-- processus de rendu, installation, ecritures disque (/proc/diskstats), et
-- session SSH ouverte (`who`). Journal reel d'un pod SANS AUCUNE TACHE :
--
--     16:01:54  activite=rien       occupe=false   -> idle_since = NOW()
--     16:02:57  activite=ecriture   occupe=true    -> idle_since = NULL
--     16:04:01  activite=ecriture   occupe=true    -> idle_since = NULL
--     16:07:13  activite=rien       occupe=false   -> idle_since = NOW()
--
-- Aucun des cinq signaux ne regarde s'il existe une TACHE. Une machine sans
-- travail qui ecrit une ligne de journal se declare occupee, `gpu_pod_heartbeat`
-- remet `idle_since` a NULL, et `gpu_pods_a_eteindre` -- qui exige `idle_since`
-- non nul pendant 10 minutes CONSECUTIVES -- ne se declenche jamais. Il ne
-- reste que `max_lifetime_minutes = 240`.
--
-- Consequence facturee : quatre pods termines entre 183 et 242 minutes, de
-- 1,35 a 1,77 $ chacun, a ne rien faire.
--
-- Le plus instructif est que ce comportement etait DELIBERE : il corrigeait un
-- defaut reel -- « l'agent declarait rien, le veilleur supprimait une machine
-- en plein travail ». On a repare un bug en en creant un autre, parce qu'on
-- mesurait la machine au lieu de mesurer le travail.
--
-- ── CE QUE CETTE MIGRATION POSE ───────────────────────────────────────────
--
--   1. des BAUX sur les taches, pour distinguer une tache longue d'un worker mort
--   2. un ETAT DE CONTROLE sur les machines, avec une generation qui invalide
--      les ordres perimes
--   3. `studio_machine_sollicitee()` : la seule definition de l'activite
--   4. `gpu_pods_a_eteindre` reecrite pour s'en servir
--   5. `gpu_pod_readiness` : une machine n'est disponible qu'apres avoir PROUVE
--      qu'elle sait rendre
--
-- CETTE MIGRATION NE DEPLOIE PAS L'ARRET AUTOMATIQUE. Elle prepare l'etat.
-- L'arret et le reveil doivent partir ENSEMBLE, sinon la premiere tache apres
-- un arret resterait bloquee en `queued` faute de savoir redemarrer.

BEGIN;

-- ══ 1. LES BAUX SUR LES TACHES ═══════════════════════════════════════════
-- `tentatives` existe deja et joue le role de `attempt`.
ALTER TABLE app.studio_jobs
  ADD COLUMN IF NOT EXISTS lease_token       UUID,
  ADD COLUMN IF NOT EXISTS lease_expires_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_heartbeat_at TIMESTAMPTZ;

COMMENT ON COLUMN app.studio_jobs.lease_token IS
  'Jeton unique par reclamation. Un worker perime ne peut plus modifier une '
  'tache reattribuee : toute ecriture exige le jeton courant.';
COMMENT ON COLUMN app.studio_jobs.lease_expires_at IS
  'Fin de validite du bail. Renouvele toutes les 30 s pendant le travail. '
  'Expire = le worker est mort, la tache est reprenable.';

-- Index partiel : on n'interroge que les baux vivants.
CREATE INDEX IF NOT EXISTS studio_jobs_bail_vivant
  ON app.studio_jobs (lease_expires_at)
  WHERE lease_expires_at IS NOT NULL;

-- ══ 2. L'ETAT DE CONTROLE DES MACHINES ═══════════════════════════════════
ALTER TABLE app.gpu_pods
  ADD COLUMN IF NOT EXISTS desired_state       TEXT NOT NULL DEFAULT 'RUNNING',
  ADD COLUMN IF NOT EXISTS observed_state      TEXT,
  ADD COLUMN IF NOT EXISTS control_generation  BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stop_after          TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS pret                BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS rapport_readiness   JSONB;

COMMENT ON COLUMN app.gpu_pods.desired_state IS
  'Ce que Supabase VEUT : RUNNING, DRAINING, STOPPED. Autorite = la file.';
COMMENT ON COLUMN app.gpu_pods.observed_state IS
  'Ce que RunPod DIT : PROVISIONING, STARTING, RUNNING, EXITED, ERROR. '
  'Ne jamais confondre avec desired_state.';
COMMENT ON COLUMN app.gpu_pods.control_generation IS
  'Incremente a CHAQUE changement d''etat souhaite. Le controleur relit la '
  'generation avant d''appeler RunPod : un ordre d''arret emis avant l''arrivee '
  'd''une tache devient automatiquement caduc. C''est la protection contre la '
  'course « file vide -> tache arrive -> stop parti quand meme ».';
COMMENT ON COLUMN app.gpu_pods.stop_after IS
  'Instant a partir duquel l''arret est permis. Pose une seule fois a la fin '
  'de la derniere tache (grace evenementielle), pas a chaque tour d''horloge.';
COMMENT ON COLUMN app.gpu_pods.pret IS
  'FAUX tant que la sonde de readiness n''a pas prouve : au moins un GPU, EGL '
  'declare, bonne version du moteur, renderer NVIDIA, et une image de test NON '
  'VIDE. « RUNNING » chez RunPod ne suffit pas -- un pod peut demarrer avec '
  'zero GPU, ou avec Chromium retombe sur SwiftShader, en silence.';

ALTER TABLE app.gpu_pods
  DROP CONSTRAINT IF EXISTS gpu_pods_desired_state_check;
ALTER TABLE app.gpu_pods
  ADD CONSTRAINT gpu_pods_desired_state_check
  CHECK (desired_state IN ('RUNNING', 'DRAINING', 'STOPPED'));

-- ══ 3. LA SEULE DEFINITION DE L'ACTIVITE ═════════════════════════════════
CREATE OR REPLACE FUNCTION public.studio_machine_sollicitee()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, app
AS $$
  -- « Sollicitee » = il y a du travail, ou quelqu'un tient un bail valide.
  -- Ni le GPU, ni le disque, ni une session SSH n'entrent dans cette definition :
  -- ce sont eux qui ont empeche toute extinction pendant deux semaines.
  -- Les valeurs sont RELUES dans les contraintes CHECK des deux tables, pas
  -- supposees. Premiere ecriture de cette fonction : `uploading` etait absent
  -- et `rendering` invente pour le tableau -- soit une machine tuee en plein
  -- televersement, et une condition qui ne pouvait jamais etre vraie.
  SELECT EXISTS (
    SELECT 1 FROM app.studio_jobs
     WHERE statut IN ('a_preparer', 'preparation', 'queued', 'rendering', 'uploading')
  ) OR EXISTS (
    SELECT 1 FROM app.studio_jobs
     WHERE lease_expires_at IS NOT NULL AND lease_expires_at > NOW()
  ) OR EXISTS (
    -- Le tableau manuscrit partage les machines : l'ignorer couperait un rendu
    -- en cours. Statuts reels : queued, processing, done, failed.
    SELECT 1 FROM app.whiteboard_renders
     WHERE status IN ('queued', 'processing')
  );
$$;

COMMENT ON FUNCTION public.studio_machine_sollicitee() IS
  'Y a-t-il du travail ? Unique autorite sur l''activite. Remplace les cinq '
  'signaux machine d''agent_pod.sh, dont les ecritures disque et la presence '
  'd''une session SSH -- qui declaraient occupee une machine sans aucune tache.';

-- ══ 4. QUELLES MACHINES ETEINDRE ═════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.gpu_pods_a_eteindre()
RETURNS TABLE(pod_id TEXT, raison TEXT, age_minutes INTEGER)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, app
AS $$
  SELECT p.pod_id,
         CASE
           WHEN p.created_at < NOW() - (p.max_lifetime_minutes || ' minutes')::INTERVAL
             THEN 'duree_maximale_depassee'
           WHEN p.mode = 'auto'
                AND p.last_seen_at < NOW() - (p.silence_timeout_minutes || ' minutes')::INTERVAL
             THEN 'agent_muet'
           WHEN p.desired_state = 'STOPPED'
             THEN 'arret_demande'
           ELSE 'sans_travail'
         END,
         (EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 60)::INTEGER
  FROM app.gpu_pods p
  WHERE p.status = 'running'
    AND (
      -- Filet absolu : une boucle folle ne peut pas facturer indefiniment.
      -- S'applique a TOUTES les machines, y compris manuelles.
      p.created_at < NOW() - (p.max_lifetime_minutes || ' minutes')::INTERVAL

      -- Arret decide par le controleur, apres sa periode de grace. Explicite,
      -- donc valable pour toutes les machines.
      OR (p.desired_state = 'STOPPED'
          AND (p.stop_after IS NULL OR p.stop_after <= NOW()))

      -- LE GARDE `mode = 'auto'` PROTEGE LES MACHINES MANUELLES, et il avait
      -- disparu de la premiere ecriture de cette fonction. Une machine creee a
      -- la main pour du debogage n'a pas d'agent : son `last_seen_at` reste
      -- vieux, et sans ce garde elle aurait ete tuee des le passage suivant du
      -- veilleur -- en pleine session, sans prevenir. `mode` passe a 'auto' au
      -- premier battement de l'agent (voir `gpu_pod_heartbeat`), donc une
      -- machine de production est couverte des sa premiere seconde utile.
      OR (p.mode = 'auto' AND (
            -- L'agent s'est tu : la machine facture sans repondre.
            p.last_seen_at < NOW() - (p.silence_timeout_minutes || ' minutes')::INTERVAL
            -- SANS TRAVAIL, mesure sur la file et non sur la machine. C'est la
            -- branche qui ne se declenchait jamais.
         OR (NOT public.studio_machine_sollicitee()
             AND p.created_at < NOW() - (p.idle_timeout_minutes || ' minutes')::INTERVAL
             AND (p.stop_after IS NULL OR p.stop_after <= NOW()))
      ))
    );
$$;

-- ══ 5. LA PORTE DE READINESS ═════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.gpu_pod_readiness(
  p_pod_id TEXT, p_jeton TEXT, p_rapport JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $$
DECLARE
  v_pod  app.gpu_pods;
  v_pret BOOLEAN;
BEGIN
  SELECT * INTO v_pod FROM app.gpu_pods WHERE pod_id = p_pod_id;
  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'pod_inconnu');
  END IF;
  IF v_pod.jeton IS DISTINCT FROM p_jeton THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'jeton_invalide');
  END IF;

  -- On ne fait PAS confiance au champ `pret` du rapport : on le recalcule
  -- depuis les faits. Un agent qui se declare pret sans GPU serait cru.
  v_pret := COALESCE((p_rapport->>'gpu_count')::INT, 0) >= 1
        AND COALESCE((p_rapport->>'egl_declare')::BOOLEAN, FALSE)
        AND COALESCE((p_rapport->>'image_octets')::INT, 0) >= 400
        AND COALESCE(p_rapport->>'renderer', '') ~* '(NVIDIA|GeForce|RTX)'
        AND JSONB_ARRAY_LENGTH(COALESCE(p_rapport->'echecs', '[]'::JSONB)) = 0;

  UPDATE app.gpu_pods SET
    pret = v_pret,
    rapport_readiness = p_rapport,
    last_seen_at = NOW()
  WHERE pod_id = p_pod_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'pret', v_pret);
END;
$$;

-- ══ 6. CE QUE RUNPOD DIT, SEPARE DE CE QU'ON VEUT ════════════════════════
CREATE OR REPLACE FUNCTION public.gpu_pod_observer(
  p_pod_id TEXT, p_observed TEXT, p_gpu_count INTEGER DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $$
DECLARE
  v_touche INTEGER;
BEGIN
  -- N'ECRIT QUE `observed_state`. L'etat souhaite appartient a Supabase, l'etat
  -- reel a RunPod : les melanger, c'est laisser la machine decider de sa propre
  -- vie -- precisement ce qui a laisse quatre pods facturer jusqu'a 240 minutes.
  UPDATE app.gpu_pods SET
    observed_state = p_observed,
    -- Une machine sans carte n'est PAS prete, quoi qu'ait dit sa sonde.
    pret = CASE WHEN COALESCE(p_gpu_count, 1) < 1 THEN FALSE ELSE pret END
  WHERE pod_id = p_pod_id;
  GET DIAGNOSTICS v_touche = ROW_COUNT;

  RETURN JSONB_BUILD_OBJECT('success', v_touche > 0, 'observed', p_observed);
END;
$$;

COMMENT ON FUNCTION public.gpu_pod_observer(TEXT, TEXT, INTEGER) IS
  'Consigne l''etat REEL vu chez RunPod. Ne touche jamais desired_state.';

COMMENT ON FUNCTION public.gpu_pod_readiness(TEXT, TEXT, JSONB) IS
  'Recalcule la readiness depuis les FAITS du rapport, jamais depuis le champ '
  '`pret` que l''agent s''attribue. Mesure du 11/08 : Chromium annoncait 1245 '
  'images/seconde sur des captures de 10 Ko -- du vide compte tres vite.';

COMMIT;
