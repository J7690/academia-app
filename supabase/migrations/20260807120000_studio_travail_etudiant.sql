-- Studio visuel — permettre a un ETUDIANT de commander une capsule 3D.
--
-- CE QUI MANQUAIT, ET POURQUOI.
-- Le Smart Whiteboard et le Studio visuel produisent tous deux une video
-- verticale a partir d'un cours, mais seul le premier etait accessible depuis
-- l'application : `studio_mettre_en_file` s'appelle avec la cle de service,
-- jamais avec le jeton d'un etudiant. L'etudiant ne pouvait donc pas choisir
-- son type de visuel -- alors que les deux chaines fonctionnent.
--
-- LE PIEGE QUI COMMANDE TOUTE LA CONCEPTION.
-- `statut = 'queued'` ne veut pas dire « en attente » : il veut dire « pret
-- pour une machine ». `studio_etat_file` le compte, et l'orchestrateur LOUE UN
-- GPU des qu'il est superieur a zero. Or une commande d'etudiant arrive sous
-- forme de storyboard : il faut d'abord la convertir en capsule, puis
-- synthetiser la voix pour MESURER la duree de chaque scene -- deux operations
-- qui ne demandent aucune carte graphique et couteraient 0,44 $/h sur un pod.
--
-- D'ou un etat intermediaire. Le travail nait `a_preparer`, le serveur du
-- projet (LWS) le convertit et le narre, et c'est seulement alors qu'il passe
-- `queued` et qu'une machine peut etre louee.
--
--     a_preparer  ->  preparation  ->  queued  ->  rendering  ->  preview_ready
--     (etudiant)      (LWS)            (pret)      (pod GPU)      (a valider)

-- ── 1. L'etudiant commande ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.studio_creer_travail_etudiant(p_project_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app'
AS $function$
DECLARE
  v_projet app.whiteboard_projects;
  v_id     uuid;
  v_scenes integer;
BEGIN
  -- Meme controle que `whiteboard_create_render_job` : on ne rend que le
  -- cours de celui qui le demande.
  SELECT * INTO v_projet
  FROM app.whiteboard_projects
  WHERE id = p_project_id AND student_id = auth.uid();

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', false, 'error', 'Projet introuvable ou non autorise');
  END IF;

  v_scenes := JSONB_ARRAY_LENGTH(COALESCE(v_projet.storyboard_json -> 'scenes', '[]'::jsonb));
  IF v_scenes = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', false, 'error', 'storyboard_sans_scenes');
  END IF;

  -- Un seul travail 3D en cours par projet : sans ce garde, un double appui
  -- sur le bouton ferait louer DEUX machines pour le meme cours.
  IF EXISTS (
    SELECT 1 FROM app.studio_jobs
    WHERE manifeste ->> 'project_id' = p_project_id::text
      AND statut IN ('a_preparer', 'preparation', 'queued', 'rendering', 'uploading')
  ) THEN
    RETURN JSONB_BUILD_OBJECT('success', false, 'error', 'travail_deja_en_cours');
  END IF;

  INSERT INTO app.studio_jobs (titre, type_capsule, manifeste, statut, cree_par)
  VALUES (
    COALESCE(NULLIF(TRIM(v_projet.subject), ''), 'Capsule Academia'),
    'storyboard',
    -- On stocke le storyboard TEL QUEL. La conversion est faite par LWS, ou
    -- vit deja `depuis_storyboard.py` : dupliquer cette logique en SQL
    -- garantirait qu'un jour les deux divergent.
    JSONB_BUILD_OBJECT(
      'project_id', p_project_id,
      'storyboard', v_projet.storyboard_json,
      'discipline', COALESCE(v_projet.renderer_id, '')
    ),
    'a_preparer',
    auth.uid()
  )
  RETURNING id INTO v_id;

  RETURN JSONB_BUILD_OBJECT('success', true, 'job_id', v_id, 'scenes', v_scenes);
END;
$function$;

-- ── 2. L'etudiant suit son travail ────────────────────────────────────────
-- Sans cette fonction, l'ecran d'attente n'aurait rien a afficher -- c'est
-- exactement le defaut releve le 07/08 sur la chaine whiteboard, ou un rendu
-- en echec laissait une roue tourner indefiniment.

CREATE OR REPLACE FUNCTION public.studio_etat_travail(p_job_id uuid)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'app'
AS $function$
  SELECT JSONB_BUILD_OBJECT(
    'success', true,
    'statut', j.statut,
    'progression', COALESCE(j.progression, 0),
    'images_faites', COALESCE(j.images_faites, 0),
    'images_total', j.images_total,
    'chemin_video', j.chemin_video,
    'erreur', j.erreur,
    -- Ce que l'etudiant doit LIRE, pas un code technique.
    'etape', CASE j.statut
      WHEN 'a_preparer'    THEN 'Preparation du cours'
      WHEN 'preparation'   THEN 'Enregistrement de la voix'
      WHEN 'queued'        THEN 'En attente d''une machine'
      WHEN 'rendering'     THEN 'Fabrication des images'
      WHEN 'uploading'     THEN 'Finalisation'
      WHEN 'preview_ready' THEN 'Pret'
      WHEN 'failed'        THEN 'Echec'
      ELSE j.statut END
  )
  FROM app.studio_jobs j
  WHERE j.id = p_job_id AND j.cree_par = auth.uid();
$function$;

-- ── 3. LWS prend un travail a preparer ────────────────────────────────────

CREATE OR REPLACE FUNCTION public.studio_prendre_a_preparer(
  p_worker_key text DEFAULT NULL, p_host text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app'
AS $function$
DECLARE
  v_job     app.studio_jobs;
  v_strict  boolean;
  v_allowed boolean;
BEGIN
  -- Meme regime d'autorisation que `whiteboard_fetch_queued_jobs` : une seule
  -- table de workers a gerer, un seul endroit ou couper l'acces.
  SELECT w.enabled INTO v_strict
    FROM app.whiteboard_workers w WHERE w.worker_key = '__strict_mode__';
  v_strict := COALESCE(v_strict, false);

  SELECT w.enabled INTO v_allowed
    FROM app.whiteboard_workers w
   WHERE w.worker_key = p_worker_key AND w.worker_key <> '__strict_mode__';
  v_allowed := COALESCE(v_allowed, false);

  IF v_strict AND NOT v_allowed THEN
    RETURN JSONB_BUILD_OBJECT('success', true, 'job', NULL);
  END IF;

  IF p_worker_key IS NOT NULL THEN
    UPDATE app.whiteboard_workers
       SET last_seen_at = NOW(), last_host = COALESCE(p_host, last_host)
     WHERE worker_key = p_worker_key;
  END IF;

  SELECT * INTO v_job FROM app.studio_jobs
  WHERE statut = 'a_preparer'
  ORDER BY created_at
  FOR UPDATE SKIP LOCKED
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', true, 'job', NULL);
  END IF;

  UPDATE app.studio_jobs SET statut = 'preparation', started_at = NOW()
  WHERE id = v_job.id;

  RETURN JSONB_BUILD_OBJECT('success', true, 'job', JSONB_BUILD_OBJECT(
    'id', v_job.id, 'titre', v_job.titre, 'manifeste', v_job.manifeste));
END;
$function$;

-- ── 4. LWS rend la capsule calee sur la voix ──────────────────────────────

CREATE OR REPLACE FUNCTION public.studio_capsule_prete(
  p_job_id uuid, p_manifeste jsonb, p_worker_key text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app'
AS $function$
DECLARE
  v_scenes integer := JSONB_ARRAY_LENGTH(COALESCE(p_manifeste -> 'scenes', '[]'::jsonb));
BEGIN
  -- Une capsule sans scene louerait une machine pour ne rien produire.
  IF v_scenes = 0 THEN
    UPDATE app.studio_jobs
       SET statut = 'failed', erreur = 'capsule_sans_scenes', completed_at = NOW()
     WHERE id = p_job_id AND statut = 'preparation';
    RETURN JSONB_BUILD_OBJECT('success', false, 'error', 'capsule_sans_scenes');
  END IF;

  UPDATE app.studio_jobs
     SET manifeste = p_manifeste,
         images_total = NULLIF((p_manifeste ->> 'images_total')::int, 0),
         statut = 'queued'
   WHERE id = p_job_id AND statut = 'preparation';

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', false, 'error', 'job_non_en_preparation');
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', true, 'scenes', v_scenes);
END;
$function$;

CREATE OR REPLACE FUNCTION public.studio_preparation_echouee(
  p_job_id uuid, p_erreur text, p_worker_key text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app'
AS $function$
BEGIN
  UPDATE app.studio_jobs
     SET statut = 'failed', erreur = LEFT(COALESCE(p_erreur, 'preparation_echouee'), 500),
         completed_at = NOW()
   WHERE id = p_job_id AND statut = 'preparation';
  RETURN JSONB_BUILD_OBJECT('success', FOUND);
END;
$function$;

-- ── 5. L'etat de la file distingue les deux attentes ──────────────────────
-- `en_attente` doit rester le nombre de travaux PRETS POUR UNE MACHINE :
-- c'est lui qui declenche une location. Un travail encore a preparer y serait
-- compte a tort, et ferait louer un GPU pendant que LWS synthetise la voix.

CREATE OR REPLACE FUNCTION public.studio_etat_file()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
AS $function$
  SELECT JSONB_BUILD_OBJECT(
    'en_attente',  (SELECT COUNT(*) FROM app.studio_jobs WHERE statut = 'queued'),
    'a_preparer',  (SELECT COUNT(*) FROM app.studio_jobs WHERE statut IN ('a_preparer','preparation')),
    'en_cours',    (SELECT COUNT(*) FROM app.studio_jobs WHERE statut IN ('rendering','uploading')),
    'machines',    (SELECT COUNT(*) FROM app.gpu_pods WHERE status = 'running'),
    'depense_24h', COALESCE((
      SELECT ROUND(SUM(EXTRACT(EPOCH FROM (COALESCE(terminated_at, NOW()) - created_at))
                       / 3600 * COALESCE(cost_per_hour, 0.44))::NUMERIC, 3)
      FROM app.gpu_pods WHERE created_at > NOW() - INTERVAL '24 hours'
    ), 0)
  );
$function$;

GRANT EXECUTE ON FUNCTION public.studio_creer_travail_etudiant(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.studio_etat_travail(uuid) TO authenticated;
