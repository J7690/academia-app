-- ============================================================================
-- La clé service_role quitte les commandes cron — 02/08/2026
-- ============================================================================
--
-- ÉTAT AVANT
--
-- Cinq tâches planifiées (jobid 6, 8, 9, 13, 15) portaient la clé `service_role`
-- EN CLAIR dans leur commande SQL. Les tâches 6 et 9 la portaient deux fois :
-- en-tête `Authorization` ET en-tête `apikey`.
--
-- Une clé écrite dans `cron.job` n'y reste pas seule : elle se retrouve dans
-- `cron.job_run_details`, dans les plans d'exécution, et dans chaque sauvegarde
-- de la base. `cron.job` n'est lisible que par `postgres` — ce n'est donc pas
-- une fuite publique — mais toute copie de la base emporte la clé avec elle.
--
-- CE QUE FAIT CETTE MIGRATION
--
-- Elle déplace la clé dans Vault et fait lire les tâches depuis Vault. La clé
-- elle-même n'est PAS changée : c'est un choix délibéré. Une rotation casserait
-- d'un coup toute intégration qui utilise encore cette clé, et il faut d'abord
-- les recenser. La migration réduit la surface ; elle ne referme pas le sujet.
--
-- ⚠️ RESTE À FAIRE — la clé actuelle demeure valide et demeure présente dans
--    les sauvegardes antérieures à ce jour. Tant qu'elle n'a pas été
--    RÉGÉNÉRÉE depuis le tableau de bord Supabase, quiconque a mis la main sur
--    une de ces sauvegardes la détient encore.
--
-- POURQUOI PAS DE `SECURITY DEFINER`
--
-- La tentation était d'exposer un appelant `SECURITY DEFINER` pour que
-- n'importe quel rôle puisse déclencher une fonction Edge. Ce serait remplacer
-- une clé mal rangée par une porte dérobée : tout titulaire du rôle
-- `authenticated` obtiendrait un appel authentifié en `service_role` vers la
-- fonction de son choix. La fonction reste donc en `SECURITY INVOKER` et n'est
-- exécutable que par `postgres` — le compte sous lequel tournent les tâches.
-- ============================================================================

-- ── 1. Le secret entre dans Vault ───────────────────────────────────────────
-- Extrait des commandes existantes PAR LA BASE ELLE-MÊME : la clé ne transite
-- ni par un presse-papier, ni par un fichier, ni par un journal d'outil.
DO $$
DECLARE
  v_cle text;
BEGIN
  IF EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'service_role_key') THEN
    RAISE NOTICE 'Secret deja present dans Vault — rien a faire.';
    RETURN;
  END IF;

  SELECT (regexp_match(command, 'Bearer\s+(ey[A-Za-z0-9._-]+)'))[1]
    INTO v_cle
    FROM cron.job
   WHERE jobid = 8;

  IF v_cle IS NULL THEN
    RAISE EXCEPTION 'Cle introuvable dans la tache 8 : migration interrompue '
                    'plutot que de creer un secret vide.';
  END IF;

  PERFORM vault.create_secret(
    v_cle,
    'service_role_key',
    'Cle service_role des taches planifiees. Migree depuis les commandes cron '
    'le 02/08/2026. NON REGENEREE : voir l''avertissement de la migration.'
  );
END $$;

-- ── 2. Un seul appelant, qui lit le secret au moment de s'en servir ─────────
CREATE OR REPLACE FUNCTION app.appeler_fonction_edge(
  p_slug  text,
  p_corps jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE plpgsql
-- SECURITY INVOKER (defaut) : voir l'en-tete de cette migration.
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cle text;
  v_id  bigint;
BEGIN
  SELECT decrypted_secret INTO v_cle
    FROM vault.decrypted_secrets
   WHERE name = 'service_role_key';

  IF v_cle IS NULL THEN
    -- plpgsql utilise « % » comme substitution, pas « %s ».
    RAISE EXCEPTION 'Secret « service_role_key » absent du Vault : appel a % '
                    'non effectue.', p_slug;
  END IF;

  SELECT net.http_post(
    url     := 'https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/' || p_slug,
    headers := jsonb_build_object(
                 'Authorization', 'Bearer ' || v_cle,
                 'apikey',        v_cle,
                 'Content-Type',  'application/json'
               ),
    body    := coalesce(p_corps, '{}'::jsonb)
  ) INTO v_id;

  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION app.appeler_fonction_edge(text, jsonb) IS
  'Appelle une fonction Edge avec la cle service_role lue dans Vault. Reservee '
  'aux taches planifiees (role postgres) : ne JAMAIS accorder EXECUTE a anon ou '
  'authenticated, cela reviendrait a offrir la cle de service.';

-- Une fonction est exécutable par PUBLIC par défaut. Ici ce serait une faille.
REVOKE ALL ON FUNCTION app.appeler_fonction_edge(text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION app.appeler_fonction_edge(text, jsonb) FROM anon;
REVOKE ALL ON FUNCTION app.appeler_fonction_edge(text, jsonb) FROM authenticated;
GRANT EXECUTE ON FUNCTION app.appeler_fonction_edge(text, jsonb) TO postgres;

-- ── 3. Les cinq tâches lisent désormais Vault ──────────────────────────────
-- Corps préservés à l'identique : `all_pending` pour les versements,
-- `target_year` pour l'analyse de tendances.
SELECT cron.alter_job(6,  command => $cmd$SELECT app.appeler_fonction_edge('prep-feed-actuality')$cmd$);
SELECT cron.alter_job(8,  command => $cmd$SELECT app.appeler_fonction_edge('ligdicash-payout', '{"all_pending": true}'::jsonb)$cmd$);
SELECT cron.alter_job(9,  command => $cmd$SELECT app.appeler_fonction_edge('prep-analyze-trends', '{"target_year": "2027", "concours_type": ""}'::jsonb)$cmd$);
SELECT cron.alter_job(13, command => $cmd$SELECT app.appeler_fonction_edge('runpod-watchdog')$cmd$);
SELECT cron.alter_job(15, command => $cmd$SELECT app.appeler_fonction_edge('studio-orchestrateur')$cmd$);

-- ── 4. Caviardage de l'historique d'exécution ──────────────────────────────
-- `cron.job_run_details` conserve la commande de chaque exécution passée — donc
-- la clé, 13 417 fois au moment de la migration (la tâche 15 tourne toutes les
-- trois minutes). Réécrire les tâches ne nettoie pas ce qui est déjà écrit.
--
-- On CAVIARDE plutôt qu'on ne supprime : effacer 13 417 lignes retirerait aussi
-- l'historique d'exécution — durées, échecs, dérives — qui est précisément ce
-- qu'on regarde quand une tâche se met à mal tourner. Le secret s'en va, la
-- traçabilité reste.
UPDATE cron.job_run_details
   SET command = regexp_replace(
         command,
         'ey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
         '<CLE_RETIREE_02_08_2026>',
         'g')
 WHERE command ~ 'ey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+';
