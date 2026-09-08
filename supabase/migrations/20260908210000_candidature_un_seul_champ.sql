-- ============================================================================
-- CANDIDATER NE DEMANDE PLUS QU'UN CHAMP.
--
-- Appliqué en production le 08/09/2026. Ce fichier consigne dans le dépôt ce
-- qui tournait déjà en base : quatre actes, dont un correctif de défaut.
--
-- ── LE DÉFAUT, ET POURQUOI IL ÉTAIT INVISIBLE ───────────────────────────────
--
-- `app_is_student_dossier_complete()` construisait la liste des champs
-- manquants ainsi :
--     v_missing_fields := v_missing_fields || 'date_of_birth';
-- Un TEXT[] concaténé à un littéral NON TYPÉ : PostgreSQL choisit la surcharge
-- array||array et tente de convertir 'date_of_birth' EN TABLEAU. Reproduit
-- hors contexte :
--     select (ARRAY[]::TEXT[]) || 'date_of_birth';
--     ERROR: 22P02 malformed array literal: "date_of_birth"
--
-- `full_name` ne plantait pas — il est renseigné chez tous, sa branche n'était
-- jamais exécutée. La PREMIÈRE branche réellement atteinte levait l'exception.
-- Le défaut ne frappait donc QUE les dossiers incomplets, c'est-à-dire
-- exactement ceux que la fonction devait servir.
--
-- LA CHAÎNE COMPLÈTE, mesurée le 08/09 :
--   1. la RPC lève au lieu de rendre les champs manquants ;
--   2. `checkDossier()` tombe dans son catch, journalise en debugPrint
--      (invisible en production) et renvoie `verified: false` ;
--   3. `apply_to_program.dart:101` exige `status.verified` :
--      LE FORMULAIRE DE DOSSIER NE S'OUVRE JAMAIS ;
--   4. le filet de l'étape 4 attend le code `dossier_incomplete` ; il reçoit
--      « malformed array literal » : IL NE SE DÉCLENCHE PAS NON PLUS.
--
-- Une ligne SQL neutralisait les deux filets. Preuve dans les traces du tunnel
-- (instrumenté le 04/09) : `dossier_requis` = 0 personne. Le formulaire ne
-- s'est ouvert POUR PERSONNE. Aucune candidature entre le 05/08 et le 08/09.
--
-- ── LA DÉCISION DE JOCELYN ──────────────────────────────────────────────────
--
-- Le dossier exigeait DOUZE champs avant de pouvoir postuler : identité (2),
-- BEPC (4), BAC (5), projet d'études rédigé. Mesure du 08/09 : 290 étudiants,
-- 10 dossiers complets, 278 à qui il manquait onze champs ou plus.
--
-- Le courtage n'a pas besoin de ces douze champs POUR RECEVOIR une
-- candidature. Il en a besoin pour monter le dossier envoyé à l'école — et
-- c'est le travail de l'administrateur, qui parle de toute façon au candidat
-- pendant la négociation. Exiger tout d'avance revenait à fermer la porte
-- d'entrée pour garantir la propreté d'un dossier qui n'existe pas encore.
--
-- NE RESTENT EXIGÉS QUE :
--   · full_name    — déjà NOT NULL, recueilli à la création du compte
--   · last_diploma — le dernier diplôme obtenu, NOUVEAU
--
-- POURQUOI LE DERNIER DIPLÔME PLUTÔT QUE LA SÉRIE DU BAC : un candidat au
-- master a une licence ; demander sa série de bac ne dit rien de son parcours.
-- Un seul champ couvre les deux cas. `last_diploma_detail` (facultatif) porte
-- la précision — la série pour un bac, l'intitulé pour une licence.
--
-- Les colonnes BEPC/BAC/projet ne sont NI supprimées NI vidées : elles restent
-- saisissables, et les dix dossiers déjà complets gardent leur contenu. Seule
-- l'EXIGENCE tombe.
--
-- Effet mesuré : 290 étudiants sur 290 n'ont plus qu'UN champ à choisir dans
-- une liste, contre onze ou plus pour 278 d'entre eux.
-- ============================================================================

-- ── 1. Le champ du dernier diplôme ──────────────────────────────────────────
ALTER TABLE app.students
  ADD COLUMN IF NOT EXISTS last_diploma TEXT,
  ADD COLUMN IF NOT EXISTS last_diploma_detail TEXT;

COMMENT ON COLUMN app.students.last_diploma IS
  'Dernier diplome obtenu (BEPC, BAC, Licence, Master, BTS/DUT, Doctorat, '
  'Autre, Aucun). SEUL champ academique exige pour candidater depuis le 08/09/2026.';
COMMENT ON COLUMN app.students.last_diploma_detail IS
  'Precision facultative : serie pour un bac, intitule pour une licence.';

-- ── 2. La complétude : deux champs au lieu de douze ─────────────────────────
CREATE OR REPLACE FUNCTION public.app_is_student_dossier_complete()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile RECORD;
    v_missing_fields TEXT[] := ARRAY[]::TEXT[];
    v_missing_documents TEXT[] := ARRAY[]::TEXT[];
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT s.full_name, s.last_diploma
    INTO v_profile
    FROM app.students s
    WHERE s.id = v_user_id;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'student_profile_not_found');
    END IF;

    -- `array_append`, JAMAIS `||` : voir l'en-tête. C'est ce détail qui a
    -- bloqué 97 % des étudiants pendant un mois.
    IF COALESCE(v_profile.full_name, '') = '' THEN
        v_missing_fields := array_append(v_missing_fields, 'full_name');
    END IF;
    IF COALESCE(v_profile.last_diploma, '') = '' THEN
        v_missing_fields := array_append(v_missing_fields, 'last_diploma');
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'is_complete', COALESCE(array_length(v_missing_fields, 1), 0) = 0,
        'missing_fields', TO_JSONB(v_missing_fields),
        'missing_documents', TO_JSONB(v_missing_documents)
    );
END;
$function$;

-- ── 3. L'enregistrement du profil accepte le dernier diplôme ────────────────
--
-- ATTENTION AU PIÈGE, DÉJÀ PAYÉ DEUX FOIS SUR CE DÉPÔT. Ajouter des paramètres
-- avec DEFAULT ne remplace pas la fonction : cela en CRÉE une seconde, et tout
-- appel compatible avec les deux devient ambigu —
--     ERROR: 42725 function ... is not unique
-- C'est arrivé à `app_append_bobodo_message` le 05/09, et c'était l'état de
-- `app_create_application` (cf. acte 4). L'ancienne signature est donc
-- SUPPRIMÉE explicitement, avant la nouvelle.
DROP FUNCTION IF EXISTS public.app_student_update_full_profile(
  text, text, text, text, date, text, integer, text, text, text,
  integer, text, text, text, text, text, text, numeric, numeric, text, text);

CREATE OR REPLACE FUNCTION public.app_student_update_full_profile(
  p_full_name text DEFAULT NULL, p_phone text DEFAULT NULL,
  p_country text DEFAULT NULL, p_city text DEFAULT NULL,
  p_date_of_birth date DEFAULT NULL, p_avatar_url text DEFAULT NULL,
  p_bepc_year integer DEFAULT NULL, p_bepc_institution text DEFAULT NULL,
  p_bepc_country text DEFAULT NULL, p_bepc_mention text DEFAULT NULL,
  p_bac_year integer DEFAULT NULL, p_bac_series text DEFAULT NULL,
  p_bac_mention text DEFAULT NULL, p_bac_institution text DEFAULT NULL,
  p_bac_country text DEFAULT NULL, p_study_project_text text DEFAULT NULL,
  p_timezone text DEFAULT NULL, p_geo_latitude numeric DEFAULT NULL,
  p_geo_longitude numeric DEFAULT NULL, p_bio text DEFAULT NULL,
  p_website_url text DEFAULT NULL,
  p_last_diploma text DEFAULT NULL,
  p_last_diploma_detail text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    -- COALESCE partout : un champ non transmis n'efface pas ce qui existe.
    -- L'écran de candidature n'envoie que le dernier diplôme ; il ne doit pas
    -- effacer le dossier des dix étudiants qui l'avaient déjà rempli.
    UPDATE app.students SET
        full_name          = COALESCE(NULLIF(p_full_name, ''), full_name),
        phone              = COALESCE(NULLIF(p_phone, ''), phone),
        country            = COALESCE(NULLIF(p_country, ''), country),
        city               = COALESCE(NULLIF(p_city, ''), city),
        date_of_birth      = COALESCE(p_date_of_birth, date_of_birth),
        avatar_url         = COALESCE(NULLIF(p_avatar_url, ''), avatar_url),
        bepc_year          = COALESCE(p_bepc_year, bepc_year),
        bepc_institution   = COALESCE(NULLIF(p_bepc_institution, ''), bepc_institution),
        bepc_country       = COALESCE(NULLIF(p_bepc_country, ''), bepc_country),
        bepc_mention       = COALESCE(NULLIF(p_bepc_mention, ''), bepc_mention),
        bac_year           = COALESCE(p_bac_year, bac_year),
        bac_series         = COALESCE(NULLIF(p_bac_series, ''), bac_series),
        bac_mention        = COALESCE(NULLIF(p_bac_mention, ''), bac_mention),
        bac_institution    = COALESCE(NULLIF(p_bac_institution, ''), bac_institution),
        bac_country        = COALESCE(NULLIF(p_bac_country, ''), bac_country),
        study_project_text = COALESCE(NULLIF(p_study_project_text, ''), study_project_text),
        timezone           = COALESCE(NULLIF(p_timezone, ''), timezone),
        geo_latitude       = COALESCE(p_geo_latitude, geo_latitude),
        geo_longitude      = COALESCE(p_geo_longitude, geo_longitude),
        bio                = COALESCE(NULLIF(p_bio, ''), bio),
        website_url        = COALESCE(NULLIF(p_website_url, ''), website_url),
        last_diploma        = COALESCE(NULLIF(p_last_diploma, ''), last_diploma),
        last_diploma_detail = COALESCE(NULLIF(p_last_diploma_detail, ''), last_diploma_detail),
        updated_at         = NOW()
    WHERE id = v_user_id;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'student_profile_not_found');
    END IF;

    SELECT TO_JSONB(s) INTO v_profile FROM app.students s WHERE s.id = v_user_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE, 'student_id', v_user_id, 'profile', v_profile);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.app_student_update_full_profile(
  text, text, text, text, date, text, integer, text, text, text,
  integer, text, text, text, text, text, text, numeric, numeric, text, text,
  text, text) TO authenticated, service_role;

-- ── 4. Le doublon de `app_create_application` ───────────────────────────────
--
-- VÉRIFIÉ AVANT SUPPRESSION, sur demande expresse de Jocelyn :
--   1. la version à 2 arguments est un SOUS-ENSEMBLE STRICT de celle à 8 :
--      mêmes contrôles, même contrat de retour, insère simplement moins de
--      colonnes (ni niveau demandé, ni mode, ni rythme, ni remise, ni
--      commentaire) ;
--   2. AUCUN appelant de production — recherche sur tout le dépôt (.dart, .ts,
--      .js, .sql, .py) : seul `student_applications_provider.dart:117` appelle
--      la RPC, et il envoie les HUIT paramètres (confirmé dans le bundle
--      compilé). Le seul appel à 2 paramètres est `.devin/
--      audit_academia_supabase.py`, un script de diagnostic ;
--   3. le SQL source ne la définit PAS : `.devin/
--      supabase_student_applications.sql:1875` crée la version à 8 arguments,
--      et ses GRANT (l. 1964-1965) ne portent que sur cette signature.
--
-- C'est un vestige resté en base après un CREATE OR REPLACE qui a ajouté des
-- paramètres au lieu de remplacer. Il rendait AMBIGU tout appel à deux
-- arguments — `function public.app_create_application(uuid, unknown) is not
-- unique` — pour un appelant futur qui n'utiliserait pas les préférences.
DROP FUNCTION IF EXISTS public.app_create_application(uuid, text);
