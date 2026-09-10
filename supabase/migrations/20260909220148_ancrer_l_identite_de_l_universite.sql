-- L'identité d'une université cesse d'être déclarative.
--
-- POURQUOI MAINTENANT. Jocelyn, 09/09 : « si un étudiant prend un bon de
-- courtage d'une université A et l'amène dans une université B, au scan
-- l'université B doit voir qu'elle n'est pas la destinataire ». Toute cette
-- garantie repose sur UNE question : de qui l'application tient-elle que le
-- compte qui scanne appartient à l'université B ?
--
-- MESURE DU 09/09, ET ELLE EST MAUVAISE :
--
--     comptes université ......................... 30
--     identifiant dans `raw_user_meta_data` ...... 29
--     identifiant dans `raw_app_meta_data` ....... 0
--     fonctions qui le lisent dans user_meta ..... 31
--
-- Or `raw_user_meta_data` est écrit par l'utilisateur lui-même : un simple
-- `auth.updateUser({data: {...}})` suffit. Un compte université peut donc
-- aujourd'hui s'attribuer l'identifiant d'une autre école -- et lire ses
-- dossiers, et demain vérifier ses bons de courtage. `raw_app_meta_data`, lui,
-- n'est modifiable que par la clé de service. C'est la distinction déjà
-- retenue le 03/09 pour le rôle ; elle n'avait pas été étendue à l'université.
--
-- CE QU'ON FAIT, EN TROIS TEMPS :
--   1. on recopie l'identifiant existant dans `raw_app_meta_data` ;
--   2. le déclencheur le REPOSE à chaque modification, si bien qu'une
--      réécriture par l'utilisateur est annulée dans la même transaction ;
--   3. à la création, il est promu de user_meta vers app_meta -- moment de
--      confiance, puisque seule la clé de service crée un compte université.
--
-- PRUDENCE PARTICULIÈRE. Ce déclencheur s'exécute à CHAQUE connexion (GoTrue
-- met `last_sign_in_at` à jour). Une exception ici ferme la porte à tout le
-- monde. Tout ce qui suit n'est que de la manipulation `jsonb`, qui ne peut
-- pas échouer sur une valeur absente ou mal formée.

-- ── 1. Les comptes existants ───────────────────────────────────────────────
UPDATE auth.users u
   SET raw_app_meta_data = COALESCE(u.raw_app_meta_data, '{}'::jsonb)
                           || jsonb_build_object('university_id',
                                                 u.raw_user_meta_data->>'university_id')
 WHERE COALESCE(u.raw_app_meta_data->>'role', u.raw_user_meta_data->>'role') = 'university'
   AND COALESCE(u.raw_user_meta_data->>'university_id', '') <> ''
   AND u.raw_app_meta_data->>'university_id' IS DISTINCT FROM
       u.raw_user_meta_data->>'university_id';

-- ── 2. Le déclencheur : le rôle, ET l'université ───────────────────────────
CREATE OR REPLACE FUNCTION public.sync_role_from_app_metadata()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_app_role  text := NEW.raw_app_meta_data->>'role';
  v_user_role text := NEW.raw_user_meta_data->>'role';
  v_app_univ  text := NEW.raw_app_meta_data->>'university_id';
  v_user_univ text := NEW.raw_user_meta_data->>'university_id';
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF v_app_role IS NULL THEN
      v_app_role := 'student';
      NEW.raw_app_meta_data := COALESCE(NEW.raw_app_meta_data, '{}'::jsonb)
                               || jsonb_build_object('role', v_app_role);
    END IF;
    NEW.raw_user_meta_data := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb)
                              || jsonb_build_object('role', v_app_role);

    -- PROMOTION À LA CRÉATION. Seule la clé de service crée un compte
    -- université ; l'inscription publique ne peut pas se donner ce rôle (le
    -- bloc ci-dessus force 'student' quand app_metadata est muet). Recopier
    -- l'identifiant ici est donc sûr, et évite de toucher les fonctions Edge.
    IF v_app_univ IS NULL AND COALESCE(v_user_univ, '') <> '' THEN
      NEW.raw_app_meta_data := COALESCE(NEW.raw_app_meta_data, '{}'::jsonb)
                               || jsonb_build_object('university_id', v_user_univ);
    END IF;

    RETURN NEW;
  END IF;

  -- UPDATE
  IF v_app_role IS NOT NULL AND (v_user_role IS DISTINCT FROM v_app_role) THEN
    NEW.raw_user_meta_data := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb)
                              || jsonb_build_object('role', v_app_role);
  END IF;

  -- L'IDENTIFIANT D'ÉCOLE EST REPOSÉ, PAS SEULEMENT COMPARÉ. Si le titulaire
  -- du compte réécrit `university_id` dans ses propres métadonnées, la valeur
  -- de confiance l'écrase dans la même transaction. Sa tentative ne laisse
  -- donc aucune trace exploitable.
  IF COALESCE(v_app_univ, '') <> '' AND (v_user_univ IS DISTINCT FROM v_app_univ) THEN
    NEW.raw_user_meta_data := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb)
                              || jsonb_build_object('university_id', v_app_univ);
  END IF;

  RETURN NEW;
END
$function$;

-- ── 3. De quoi lire l'université SANS se répéter, et sans se tromper ───────
-- Les 31 fonctions existantes lisent encore user_meta. On ne les réécrit pas
-- -- elles sont désormais couvertes, puisque le déclencheur y repose la bonne
-- valeur. Mais toute garde NOUVELLE passe par ici, qui préfère la source de
-- confiance et ne retombe sur l'autre que si la première est vide.
CREATE OR REPLACE FUNCTION app.universite_de_l_utilisateur(p_user_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'app', 'public', 'pg_temp'
AS $function$
  SELECT NULLIF(COALESCE(u.raw_app_meta_data->>'university_id',
                         u.raw_user_meta_data->>'university_id'), '')::uuid
  FROM auth.users u
  WHERE u.id = p_user_id;
$function$;

COMMENT ON FUNCTION app.universite_de_l_utilisateur(UUID) IS
  'Identifiant de l''établissement d''un compte, lu d''abord dans '
  '`raw_app_meta_data` (non modifiable par l''utilisateur). À utiliser pour '
  'toute décision d''accès ; ne jamais lire `raw_user_meta_data` seul.';
