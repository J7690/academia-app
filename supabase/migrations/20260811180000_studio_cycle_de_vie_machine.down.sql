-- RETOUR ARRIERE de 20260811180000_studio_cycle_de_vie_machine.sql
--
-- Releve fait sur la base de production le 11/08/2026 AVANT application.
-- Ce n'est pas une reconstitution de memoire : la definition de
-- `gpu_pods_a_eteindre` ci-dessous est celle que `pg_get_functiondef` a rendue.
--
-- CE QUE LA MIGRATION FAIT, ET DONC CE QUE CE FICHIER DEFAIT :
--
--   REMPLACE (1 seul objet)   gpu_pods_a_eteindre
--   AJOUTE   (12 objets)      9 colonnes, 3 fonctions, 1 index, 1 contrainte
--
-- La migration est donc presque entierement ADDITIVE. Le seul risque de
-- regression porte sur `gpu_pods_a_eteindre` -- restaure a l'identique ici.
--
-- ORDRE : on rend d'abord au veilleur son ancien comportement, PUIS on retire
-- les ajouts. L'inverse laisserait une fonction qui reference des colonnes
-- disparues, et le veilleur cesserait d'eteindre quoi que ce soit.

BEGIN;

-- ══ 1. L'ANCIENNE FONCTION, A L'IDENTIQUE ════════════════════════════════
-- Rappel de son defaut, pour que personne ne la restaure en croyant reparer :
-- elle exige `idle_since IS NOT NULL`, or l'agent remettait ce champ a NULL des
-- qu'une ecriture disque ou une session SSH survenait. La branche d'inactivite
-- ne se declenchait donc JAMAIS, et seul le plafond de 240 minutes agissait.
CREATE OR REPLACE FUNCTION public.gpu_pods_a_eteindre()
 RETURNS TABLE(pod_id text, raison text, age_minutes integer)
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  SELECT p.pod_id,
         CASE
           WHEN p.created_at < NOW() - (p.max_lifetime_minutes || ' minutes')::INTERVAL
             THEN 'duree_maximale_depassee'
           WHEN p.mode = 'auto'
                AND p.last_seen_at < NOW() - (p.silence_timeout_minutes || ' minutes')::INTERVAL
             THEN 'agent_muet'
           ELSE 'inactif'
         END,
         EXTRACT(EPOCH FROM (NOW() - p.created_at))::INTEGER / 60
  FROM app.gpu_pods p
  WHERE p.status = 'running'
    AND (
      p.created_at < NOW() - (p.max_lifetime_minutes || ' minutes')::INTERVAL
      OR (p.mode = 'auto' AND (
            p.last_seen_at < NOW() - (p.silence_timeout_minutes || ' minutes')::INTERVAL
         OR (p.idle_since IS NOT NULL
             AND p.idle_since < NOW() - (p.idle_timeout_minutes || ' minutes')::INTERVAL)
      ))
    );
$function$;

-- ══ 2. LES FONCTIONS AJOUTEES ════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.gpu_pod_observer(TEXT, TEXT, INTEGER);
DROP FUNCTION IF EXISTS public.gpu_pod_readiness(TEXT, TEXT, JSONB);
DROP FUNCTION IF EXISTS public.studio_machine_sollicitee();

-- ══ 3. L'INDEX ET LA CONTRAINTE ══════════════════════════════════════════
DROP INDEX IF EXISTS app.studio_jobs_bail_vivant;
ALTER TABLE app.gpu_pods DROP CONSTRAINT IF EXISTS gpu_pods_desired_state_check;

-- ══ 4. LES COLONNES ══════════════════════════════════════════════════════
-- ATTENTION : ceci DETRUIT les baux et l'etat de controle accumules depuis
-- l'application. A ne jouer que si l'on revient vraiment en arriere, pas pour
-- « nettoyer ». Aucune de ces colonnes n'existait avant le 11/08/2026.
ALTER TABLE app.studio_jobs
  DROP COLUMN IF EXISTS lease_token,
  DROP COLUMN IF EXISTS lease_expires_at,
  DROP COLUMN IF EXISTS last_heartbeat_at;

ALTER TABLE app.gpu_pods
  DROP COLUMN IF EXISTS desired_state,
  DROP COLUMN IF EXISTS observed_state,
  DROP COLUMN IF EXISTS control_generation,
  DROP COLUMN IF EXISTS stop_after,
  DROP COLUMN IF EXISTS pret,
  DROP COLUMN IF EXISTS rapport_readiness;

COMMIT;
