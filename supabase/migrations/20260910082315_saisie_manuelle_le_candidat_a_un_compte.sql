-- Saisie manuelle, deuxième version : LE CANDIDAT A UN COMPTE, ET C'EST LA
-- SEULE FAÇON. Corrige la migration 20260910081554, dont la fonction ne
-- pouvait PAS fonctionner.
--
-- CE QUE J'AVAIS ÉCRIT, ET QUI ÉTAIT FAUX. La migration précédente affirme,
-- en commentaire : « `app.students` n'a AUCUNE clé étrangère vers
-- `auth.users` ». C'est faux, et la faute est une faute de méthode : j'avais
-- interrogé `pg_constraint` sur cinq tables NOMMÉES, et `app.students` n'en
-- faisait pas partie. Une absence de résultat sur une table qu'on n'a pas
-- interrogée n'est pas une absence de contrainte. La mesure juste :
--
--     students_id_fkey  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE
--
-- L'essai transactionnel du 10/09 l'a montré en une seconde, avant tout
-- déploiement :
--     ERROR 23503: insert or update on table "students" violates foreign key
--     constraint "students_id_fkey"
--
-- CE QUE ÇA CHANGE. Une fiche `app.students` EST un compte : l'identité des
-- deux tables est l'invariant sur lequel repose tout l'applicatif -- chaque
-- écran « mon dossier » compare `students.id` à `auth.uid()`. Une personne
-- sans compte ne peut donc pas avoir de fiche, et il n'était pas question de
-- desserrer cette clé pour un cas d'usage de comptoir.
--
-- LA PLATEFORME AVAIT DÉJÀ TRANCHÉ, IL SUFFISAIT DE REGARDER. L'Edge Function
-- `admin-create-student-account` (09/09) crée le compte d'un étudiant depuis
-- le tableau de bord, avec la clé de service ; le déclencheur
-- `on_auth_user_created` (`app_handle_new_auth_user`) pose la fiche
-- `app.students` dans la foulée -- pour TOUT compte, quel que soit le rôle.
-- « Une personne qui ne peut pas créer de compte » veut dire qu'elle ne peut
-- pas le faire ELLE-MÊME ; l'administrateur le fait pour elle, et c'est déjà
-- un geste existant de l'écran Comptes.
--
-- L'ENCHAÎNEMENT DEVIENT DONC, SANS RIEN INVENTER :
--   1. l'écran appelle `admin-create-student-account` -> un compte, une fiche
--   2. l'écran appelle CETTE fonction avec l'identifiant obtenu
--   3. elle complète la fiche, ouvre la candidature au taux fixé, enregistre
--      l'encaissement, puis appelle `app.emettre_recu` et `app.emettre_bon` --
--      les mêmes que le parcours normal.
--
-- CE QUE ÇA COÛTE, ET IL FAUT LE DIRE : une adresse de courriel devient
-- OBLIGATOIRE au comptoir, puisque Auth en exige une. Si Jocelyn juge cette
-- exigence intenable pour son public, l'autre voie est de remplacer
-- `students_id_fkey` par un déclencheur conditionnel -- décision de modèle de
-- données, pas de détail d'écran, et elle lui revient.

-- ── 1. La vue dit la vérité de la SOURCE, pas d'un drapeau recopié ────────
-- Première version : elle listait les fiches marquées `manual_entry_by`. Mais
-- un étudiant inscrit lui-même peut recevoir un dossier saisi au comptoir : le
-- drapeau serait alors posé sur la personne, alors qu'il qualifie l'ACTE.
-- `brokerage_vouchers.origin` le dit exactement, et c'est lui qui fait foi
-- lors d'une vérification au guichet.
DROP VIEW IF EXISTS app.saisies_manuelles;

CREATE VIEW app.saisies_manuelles AS
SELECT b.id                AS voucher_id,
       b.voucher_number    AS bon,
       b.issued_at         AS saisi_le,
       b.issued_by         AS saisi_par,
       s.id                AS student_id,
       s.full_name         AS candidat,
       (au.last_sign_in_at IS NOT NULL) AS compte_deja_utilise,
       a.id                AS application_id,
       a.discount_rate     AS taux,
       pr.title            AS formation,
       u.name              AS universite,
       p.id                AS payment_id,
       p.amount_paid       AS montant,
       r.receipt_number    AS recu,
       b.transferred_at    AS transmis_le,
       b.consumed_at       AS consomme_le
FROM app.brokerage_vouchers b
JOIN app.applications a              ON a.id = b.application_id
JOIN app.programs pr                 ON pr.id = a.program_id
LEFT JOIN app.universities u         ON u.id = pr.university_id
LEFT JOIN app.application_payments p ON p.id = b.payment_id
LEFT JOIN app.students s             ON s.id = a.student_id
LEFT JOIN auth.users au              ON au.id = s.id
LEFT JOIN app.payment_receipts r     ON r.payment_id = p.id
WHERE b.origin = 'saisie_manuelle';

COMMENT ON VIEW app.saisies_manuelles IS
  'Dossiers ouverts au comptoir par un administrateur. La source est '
  'app.brokerage_vouchers.origin, qui qualifie l''acte -- pas un drapeau posé '
  'sur la personne. `compte_deja_utilise` distingue le candidat qui n''a '
  'jamais ouvert l''application de celui qui s''en sert déjà.';

-- ── 2. La saisie au comptoir, sur un compte existant ──────────────────────
-- L'ancienne signature créait la fiche elle-même : elle ne peut plus exister,
-- sans quoi deux surcharges cohabiteraient et l'appelant tomberait sur celle
-- qui échoue.
DROP FUNCTION IF EXISTS public.app_admin_emettre_documents_manuels(
  TEXT, UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, DATE, NUMERIC, TEXT, TEXT, TEXT, TEXT, UUID);

CREATE OR REPLACE FUNCTION public.app_admin_emettre_documents_manuels(
  p_student_id     UUID,
  p_program_id     UUID,
  p_taux           NUMERIC,
  p_nom            TEXT    DEFAULT NULL,
  p_telephone      TEXT    DEFAULT NULL,
  p_email          TEXT    DEFAULT NULL,
  p_ville          TEXT    DEFAULT NULL,
  p_pays           TEXT    DEFAULT NULL,
  p_date_naissance DATE    DEFAULT NULL,
  p_montant        NUMERIC DEFAULT NULL,
  p_canal          TEXT    DEFAULT 'cash',
  p_reference      TEXT    DEFAULT NULL,
  p_note           TEXT    DEFAULT NULL,
  p_mode_etude     TEXT    DEFAULT NULL,
  p_forcer         BOOLEAN DEFAULT FALSE
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_admin      UUID := auth.uid();
  v_prog       RECORD;
  v_fiche      RECORD;
  v_canal      public.payment_channel;
  v_montant    NUMERIC;
  v_jamais_vu  BOOLEAN;
  v_doublon    TEXT;
  v_app_id     UUID;
  v_pay_id     UUID;
  v_reference  TEXT;
  v_recu       JSONB;
  v_bon        JSONB;
BEGIN
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Le rôle se lit dans `raw_app_meta_data`, que l'utilisateur ne peut pas
  -- écrire -- contrairement à `raw_user_meta_data`. Garde posée le 03/09.
  IF COALESCE((SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = v_admin), '')
     <> 'admin' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_admin');
  END IF;

  SELECT s.*, (au.last_sign_in_at IS NULL) AS jamais_connecte
    INTO v_fiche
  FROM app.students s
  LEFT JOIN auth.users au ON au.id = s.id
  WHERE s.id = p_student_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'candidat_sans_compte',
      'message', 'Ce candidat n''a pas encore de compte. Créez-le d''abord '
              || 'depuis l''écran Comptes : la fiche suit automatiquement.');
  END IF;
  v_jamais_vu := COALESCE(v_fiche.jamais_connecte, TRUE);

  IF p_taux IS NULL OR p_taux < 0 OR p_taux > 100 THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'taux_invalide',
      'message', 'Le pourcentage négocié est obligatoire, et compris entre 0 et 100.');
  END IF;

  SELECT pr.id, pr.title, pr.university_id, pr.brokerage_fee
    INTO v_prog
  FROM app.programs pr WHERE pr.id = p_program_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'formation_introuvable');
  END IF;
  IF v_prog.university_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'programme_sans_etablissement');
  END IF;

  -- Le montant par défaut est CELUI DU PROGRAMME, comme dans le parcours
  -- normal où l'appelant ne choisit rien. Une valeur explicite reste possible
  -- -- au comptoir, un règlement négocié existe -- mais elle est alors tracée
  -- dans le journal d'audit ci-dessous.
  v_montant := COALESCE(NULLIF(p_montant, 0), v_prog.brokerage_fee);
  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'montant_indeterminable',
      'message', 'Cette formation n''a pas de frais de courtage défini : '
              || 'saisir le montant encaissé.');
  END IF;

  BEGIN
    v_canal := COALESCE(NULLIF(TRIM(p_canal), ''), 'cash')::public.payment_channel;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'canal_invalide');
  END;

  -- UN COMPTOIR, ÇA DOUBLE-CLIQUE. Deux bons vivants pour la même personne et
  -- la même formation, c'est deux papiers présentables au même guichet. On
  -- refuse, en NOMMANT le bon existant -- et `p_forcer` reste ouvert pour le
  -- cas légitime du deuxième dossier.
  IF NOT COALESCE(p_forcer, FALSE) THEN
    SELECT b.voucher_number INTO v_doublon
    FROM app.brokerage_vouchers b
    JOIN app.applications a ON a.id = b.application_id
    WHERE a.student_id = p_student_id
      AND a.program_id = p_program_id
      AND b.consumed_at IS NULL
      AND b.expires_at > NOW()
    LIMIT 1;
    IF v_doublon IS NOT NULL THEN
      RETURN jsonb_build_object('success', FALSE, 'error', 'bon_deja_vivant',
        'bon', v_doublon,
        'message', 'Un bon en cours de validité existe déjà pour ce candidat '
                || 'et cette formation (' || v_doublon || ').');
    END IF;
  END IF;

  -- ── La fiche, complétée par ce que l'administrateur a sous les yeux ─────
  -- Chaque champ ne s'écrit que s'il a été saisi : une saisie partielle ne
  -- doit pas effacer ce que la personne avait déjà renseigné.
  UPDATE app.students SET
    full_name       = COALESCE(NULLIF(TRIM(p_nom), ''), full_name),
    phone           = COALESCE(NULLIF(TRIM(p_telephone), ''), phone),
    city            = COALESCE(NULLIF(TRIM(p_ville), ''), city),
    country         = COALESCE(NULLIF(TRIM(p_pays), ''), country),
    date_of_birth   = COALESCE(p_date_naissance, date_of_birth),
    -- Le marquage ne vaut que pour un compte JAMAIS OUVERT par son titulaire.
    -- Marquer la fiche d'un étudiant actif dirait une contre-vérité sur lui.
    manual_entry_by = CASE WHEN v_jamais_vu THEN COALESCE(manual_entry_by, v_admin)
                           ELSE manual_entry_by END,
    manual_entry_at = CASE WHEN v_jamais_vu THEN COALESCE(manual_entry_at, NOW())
                           ELSE manual_entry_at END,
    updated_at      = NOW()
  WHERE id = p_student_id;

  -- ── La candidature, acceptée et TAUX POSÉ ───────────────────────────────
  -- L'ordre n'est pas décoratif : le verrou du 09/09 refuse d'encaisser un
  -- courtage tant que `discount_rate` est NULL, et `app.emettre_bon` refuse
  -- d'émettre pour la même raison. Poser le taux AVANT le paiement, c'est
  -- respecter le verrou au lieu de le contourner.
  INSERT INTO app.applications (
    student_id, program_id, status, submitted_at,
    requested_study_mode, discount_requested, discount_rate,
    discount_validated_at, discount_validated_by, discount_details,
    sent_to_university, sent_to_university_at)
  VALUES (
    p_student_id, v_prog.id, 'accepted', NOW(),
    NULLIF(TRIM(p_mode_etude), ''), TRUE, p_taux,
    NOW(), v_admin, NULLIF(TRIM(p_note), ''),
    TRUE, NOW())
  RETURNING id INTO v_app_id;

  -- ── Le paiement, déjà encaissé HORS PLATEFORME ──────────────────────────
  -- Même forme de référence que le parcours normal : au guichet, personne ne
  -- doit avoir à savoir par où le dossier est passé.
  v_reference := 'AP-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                 SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

  INSERT INTO app.application_payments (
    application_id, student_id, university_id, amount_due, amount_paid,
    currency, payment_reason, channel, status, reference_code,
    external_reference, payment_method, phone_number,
    declared_at, confirmed_at, confirmed_by, created_by)
  VALUES (
    v_app_id, p_student_id, v_prog.university_id, v_montant, v_montant,
    'XOF', 'application_fee'::public.payment_reason, v_canal,
    'confirmed'::public.payment_status, v_reference,
    NULLIF(TRIM(p_reference), ''), 'manual', NULLIF(TRIM(p_telephone), ''),
    NOW(), NOW(), v_admin, v_admin)
  RETURNING id INTO v_pay_id;

  -- ── Les deux documents, par les fonctions du parcours normal ────────────
  v_recu := app.emettre_recu(v_pay_id, v_admin, NULL, p_email);
  IF COALESCE((v_recu->>'success')::boolean, FALSE) IS NOT TRUE THEN
    RAISE EXCEPTION 'emission_recu_refusee: %', COALESCE(v_recu->>'error', 'inconnu');
  END IF;

  v_bon := app.emettre_bon(v_pay_id, v_admin, 'saisie_manuelle');
  IF COALESCE((v_bon->>'success')::boolean, FALSE) IS NOT TRUE THEN
    RAISE EXCEPTION 'emission_bon_refusee: %', COALESCE(v_bon->>'error', 'inconnu');
  END IF;

  INSERT INTO app.admin_audit_log (admin_id, action_type, target_type, target_id,
                                   target_user_id, details)
  VALUES (v_admin, 'emettre_documents_manuels', 'application', v_app_id::text,
          p_student_id,
          jsonb_build_object(
            'candidat', COALESCE(NULLIF(TRIM(p_nom), ''), v_fiche.full_name),
            'compte_jamais_ouvert', v_jamais_vu,
            'formation', v_prog.title, 'universite_id', v_prog.university_id,
            'taux', p_taux,
            'montant', v_montant,
            'montant_impose_par_le_programme', v_prog.brokerage_fee,
            'montant_saisi', p_montant,
            'canal', v_canal::text,
            'force', COALESCE(p_forcer, FALSE),
            'reference_externe', NULLIF(TRIM(p_reference), ''),
            'recu', v_recu->>'receipt_number',
            'bon', v_bon->>'voucher_number'));

  RETURN jsonb_build_object(
    'success', TRUE,
    'student_id', p_student_id,
    'application_id', v_app_id,
    'payment_id', v_pay_id,
    'montant', v_montant,
    'taux', p_taux,
    'receipt_id', v_recu->>'receipt_id',
    'receipt_number', v_recu->>'receipt_number',
    'voucher_id', v_bon->>'voucher_id',
    'voucher_number', v_bon->>'voucher_number',
    'verification_code', v_bon->>'verification_code',
    'expire_le', v_bon->>'expire_le');
END;
$function$;

REVOKE ALL ON FUNCTION public.app_admin_emettre_documents_manuels(
  UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT, DATE, NUMERIC, TEXT, TEXT, TEXT, TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_admin_emettre_documents_manuels(
  UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT, DATE, NUMERIC, TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;

COMMENT ON FUNCTION public.app_admin_emettre_documents_manuels(
  UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT, DATE, NUMERIC, TEXT, TEXT, TEXT, TEXT, BOOLEAN) IS
  'Saisie au comptoir. Le candidat doit déjà avoir un compte (écran Comptes ou '
  'Edge Function admin-create-student-account) : app.students.id référence '
  'auth.users.id. Fabrique ensuite les mêmes lignes que le parcours étudiant, '
  'puis appelle app.emettre_recu et app.emettre_bon. Le bon produit se '
  'vérifie, se consomme et se transfère exactement comme un bon du parcours '
  'normal ; seul brokerage_vouchers.origin le distingue.';
